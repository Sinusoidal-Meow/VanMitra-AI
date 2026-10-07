"""
The CFR boundary (Stage 3): versions with segments, landmarks per segment, customary
use zones, the boundary walk with the elders (G9), and disputes where the claim
overlaps a neighbouring village's claim [Rule 12(1)(f)(g), 12(3)].

The Gram Sabha / FRC maps while drafting the case and while reviewing it. The
Gram Sabha-approved version is frozen (approval comes with the resolution).
"""

import uuid
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, status

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession
from ...errors import ApiError, RuleViolation
from ...geo import (
    GeoError,
    accuracy_stats,
    position,
    ring,
    split_ring,
)
from ...models import (
    AppUser,
    BoundaryLandmark,
    BoundarySegment,
    BoundaryStatus,
    BoundaryWalk,
    CaseState,
    CfrBoundary,
    ClaimType,
    Dispute,
    DisputeOutcome,
    GsMember,
    Role,
    UseZone,
)
from ...models.procedure import Evidence, Media
from ...schemas.boundary import (
    BoundaryIn,
    BoundaryOut,
    BoundaryVersionOut,
    DisputeOut,
    JointMeetingIn,
    LandmarkIn,
    LandmarkOut,
    Participant,
    PolygonIn,
    SdlcReferralIn,
    UseZoneIn,
    UseZoneOut,
    WalkIn,
    WalkOut,
)
from ...services import boundary as geo
from ...services.cases import CaseContext, ensure_claim_type, load_case

router = APIRouter(tags=["boundary"])

JOINT_SOLUTION_DAYS = 30  # time for a mutual solution before the SDLC [Rule 14(7)]


def _geo_error(e: GeoError) -> ApiError:
    return ApiError(422, "INVALID_GEOMETRY", e.key, {"reason": e.detail})


def _ensure_can_map(ctx: CaseContext) -> None:
    """Claimant (the Gram Sabha) while drafting; the Gram Sabha while it reviews."""
    ensure_claim_type(ctx, ClaimType.CFR, "NOT_A_FORM_C_CASE")
    state = ctx.case.state
    if state is CaseState.DRAFT and ctx.is_creator:
        return
    if state is CaseState.GS_REVIEW and Role.GRAM_SABHA in ctx.roles:
        return
    raise ApiError(403, "CANNOT_MAP_NOW", "boundary.cannot_map_now", {"state": state})


def _current_or_404(db: DbSession, ctx: CaseContext) -> CfrBoundary:
    b = geo.current_boundary(db, ctx.case.id)
    if b is None:
        raise ApiError(404, "NO_BOUNDARY", "boundary.none")
    return b


def _editable(db: DbSession, ctx: CaseContext) -> CfrBoundary:
    _ensure_can_map(ctx)
    b = _current_or_404(db, ctx)
    if b.status is not BoundaryStatus.DRAFT:
        raise ApiError(409, "BOUNDARY_FROZEN", "boundary.frozen", {"status": b.status})
    return b


def _polygon(body: PolygonIn) -> tuple[dict[str, Any], list[list[tuple[float, float]]]]:
    try:
        rings = [ring(r) for r in body.coordinates]
        geojson: dict[str, Any] = {"type": "Polygon", "coordinates": rings}
        geo.ensure_valid(geojson)
    except GeoError as e:
        raise _geo_error(e) from e
    return geojson, rings


def _own_media(db: DbSession, user: AppUser, media_id: uuid.UUID | None) -> None:
    if media_id is None:
        return
    media = db.get(Media, media_id)
    if media is None or media.uploaded_by_user_id != user.id:
        raise ApiError(422, "MEDIA_NOT_YOURS", "evidence.media_not_yours", {"media_id": media_id})


# ── Boundary versions ─────────────────────────────────────────────────────────


@router.post(
    "/cases/{case_id}/boundary", response_model=BoundaryOut, status_code=status.HTTP_201_CREATED
)
def save_boundary(
    case_id: uuid.UUID,
    body: BoundaryIn,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> BoundaryOut:
    """
    Save the mapped boundary as a new version (previous versions are kept). Landmarks
    and use zones of the previous draft carry over where their segment still exists.
    Overlaps with neighbouring claims are checked at once and open disputes.
    """
    ctx = load_case(db, principal, case_id)
    _ensure_can_map(ctx)
    polygon_geojson, rings = _polygon(body.polygon)
    outer = rings[0]
    if body.vertex_accuracy_m is not None and len(body.vertex_accuracy_m) != len(outer) - 1:
        raise ApiError(
            422, "ACCURACY_LENGTH", "boundary.accuracy_length", {"vertices": len(outer) - 1}
        )
    try:
        pieces = split_ring(outer, body.segment_breaks)
    except GeoError as e:
        raise _geo_error(e) from e

    previous = geo.current_boundary(db, case_id)
    latest = db.find(CfrBoundary, {"case_id": case_id}, sort=[("version", -1)], limit=1)
    version = (latest[0].version if latest else 0) + 1

    segments: list[BoundarySegment] = []
    for seq, piece in enumerate(pieces):
        seg_geom = {"type": "LineString", "coordinates": piece}
        segments.append(BoundarySegment(seq=seq, geom=seg_geom, length_m=geo.length_m(seg_geom)))

    b = CfrBoundary(
        case_id=case_id,
        version=version,
        geom=polygon_geojson,
        source=body.source,
        status=BoundaryStatus.DRAFT,
        area_ha=geo.area_ha(polygon_geojson),
        accuracy_stats=accuracy_stats(body.vertex_accuracy_m, len(outer) - 1, geo.GPS_LIMIT_M),
        is_current=True,
        created_by_user_id=user.id,
        segments=segments,
    )
    if previous is not None:
        previous.is_current = False
        if previous.status is BoundaryStatus.DRAFT:
            _carry_over(previous, b, len(segments))
    db.add(b)
    geo.detect_overlaps(db, ctx.case, b)
    db.commit()
    return geo.boundary_out(db, b)


def _carry_over(old: CfrBoundary, new: CfrBoundary, segments: int) -> None:
    for lm in old.landmarks:
        if lm.segment_seq < segments:
            new.landmarks.append(
                BoundaryLandmark(
                    segment_seq=lm.segment_seq,
                    name=lm.name,
                    kind=lm.kind,
                    point=lm.point,
                    photo_media_id=lm.photo_media_id,
                    evidence_id=lm.evidence_id,
                )
            )
    for z in old.use_zones:
        new.use_zones.append(
            UseZone(
                use_type=z.use_type,
                name=z.name,
                geom=z.geom,
                area_ha=z.area_ha,
                season=z.season,
                user_hamlets=list(z.user_hamlets),
            )
        )


@router.get("/cases/{case_id}/boundary", response_model=BoundaryOut)
def get_boundary(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> BoundaryOut:
    ctx = load_case(db, principal, case_id)
    ensure_claim_type(ctx, ClaimType.CFR, "NOT_A_FORM_C_CASE")
    return geo.boundary_out(db, _current_or_404(db, ctx))


@router.get("/cases/{case_id}/boundary/versions", response_model=list[BoundaryVersionOut])
def boundary_versions(
    case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> list[BoundaryVersionOut]:
    load_case(db, principal, case_id)
    rows = db.find(CfrBoundary, {"case_id": case_id}, sort=[("version", 1)])
    return [
        BoundaryVersionOut(
            id=b.id,
            version=b.version,
            status=b.status,
            source=b.source,
            area_ha=b.area_ha,
            is_current=b.is_current,
            created_at=b.created_at,
        )
        for b in rows
    ]


# ── Landmarks and use zones ───────────────────────────────────────────────────


@router.post(
    "/cases/{case_id}/boundary/landmarks",
    response_model=LandmarkOut,
    status_code=status.HTTP_201_CREATED,
)
def add_landmark(
    case_id: uuid.UUID,
    body: LandmarkIn,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> LandmarkOut:
    """A landmark fixing a segment on the ground; every segment needs one (BR-08)."""
    ctx = load_case(db, principal, case_id)
    b = _editable(db, ctx)
    if body.segment_seq >= len(b.segments):
        raise ApiError(
            422, "NO_SUCH_SEGMENT", "boundary.no_such_segment", {"segments": len(b.segments)}
        )
    _own_media(db, user, body.photo_media_id)
    if body.evidence_id is not None:
        ev = db.get(Evidence, body.evidence_id)
        if ev is None or ev.case_id != case_id:
            raise ApiError(422, "EVIDENCE_NOT_IN_CASE", "boundary.evidence_not_in_case")
    lm = BoundaryLandmark(
        segment_seq=body.segment_seq,
        name=body.name,
        kind=body.kind,
        point={"type": "Point", "coordinates": [body.lon, body.lat]},
        photo_media_id=body.photo_media_id,
        evidence_id=body.evidence_id,
    )
    b.landmarks.append(lm)
    db.commit()
    return next(x for x in geo.landmarks_out(b) if x.id == lm.id)


@router.delete("/cases/{case_id}/boundary/landmarks/{landmark_id}", status_code=204)
def delete_landmark(
    case_id: uuid.UUID, landmark_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> None:
    ctx = load_case(db, principal, case_id)
    b = _editable(db, ctx)
    original_len = len(b.landmarks)
    b.landmarks = [lm for lm in b.landmarks if lm.id != landmark_id]
    if len(b.landmarks) == original_len:
        raise ApiError(404, "LANDMARK_NOT_FOUND", "boundary.landmark_not_found")
    db.commit()


@router.post(
    "/cases/{case_id}/boundary/use-zones",
    response_model=UseZoneOut,
    status_code=status.HTTP_201_CREATED,
)
def add_use_zone(
    case_id: uuid.UUID, body: UseZoneIn, db: DbSession, principal: CurrentPrincipal
) -> UseZoneOut:
    """An area of customary use [Rule 13(2)(b)]. Never clipped; `within_boundary` tells."""
    ctx = load_case(db, principal, case_id)
    b = _editable(db, ctx)
    polygon_geojson, _ = _polygon(body.polygon)
    zone = UseZone(
        use_type=body.use_type,
        name=body.name,
        geom=polygon_geojson,
        area_ha=geo.area_ha(polygon_geojson),
        season=body.season,
        user_hamlets=list(body.user_hamlets),
    )
    b.use_zones.append(zone)
    db.commit()
    return next(z for z in geo.use_zones_out(b) if z.id == zone.id)


@router.delete("/cases/{case_id}/boundary/use-zones/{zone_id}", status_code=204)
def delete_use_zone(
    case_id: uuid.UUID, zone_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> None:
    ctx = load_case(db, principal, case_id)
    b = _editable(db, ctx)
    original_len = len(b.use_zones)
    b.use_zones = [z for z in b.use_zones if z.id != zone_id]
    if len(b.use_zones) == original_len:
        raise ApiError(404, "USE_ZONE_NOT_FOUND", "boundary.use_zone_not_found")
    db.commit()


# ── Boundary walk (G9) ────────────────────────────────────────────────────────


def _walk_out(w: BoundaryWalk) -> WalkOut:
    trace_length = geo.length_m(w.trace) if w.trace else None
    return WalkOut(
        id=w.id,
        walked_on=w.walked_on,
        participants=[Participant.model_validate(p) for p in w.participants],
        trace=w.trace,
        trace_length_m=trace_length,
        notes=w.notes,
        created_at=w.created_at,
    )


@router.post(
    "/cases/{case_id}/boundary/walks", response_model=WalkOut, status_code=status.HTTP_201_CREATED
)
def record_walk(
    case_id: uuid.UUID, body: WalkIn, db: DbSession, user: CurrentUser, principal: CurrentPrincipal
) -> WalkOut:
    """Who walked the customary boundary, and when, with the GPS trace [Rule 12(1)(f)]."""
    ctx = load_case(db, principal, case_id)
    _ensure_can_map(ctx)
    member_ids = [p.gs_member_id for p in body.participants if p.gs_member_id]
    if member_ids:
        found = db.count(
            GsMember,
            {"_id": {"$in": member_ids}, "gram_sabha_id": ctx.case.gram_sabha_id},
        )
        if found != len(member_ids):
            raise ApiError(422, "PARTICIPANT_NOT_IN_ROSTER", "boundary.participant_not_in_roster")
    trace = None
    if body.trace is not None:
        try:
            pts = [position(p) for p in body.trace.coordinates]
            trace = {"type": "LineString", "coordinates": pts}
        except GeoError as e:
            raise _geo_error(e) from e
    walk = BoundaryWalk(
        case_id=case_id,
        walked_on=body.walked_on,
        participants=[p.model_dump(mode="json") for p in body.participants],
        trace=trace,
        trace_length_m=geo.length_m(trace) if trace else None,
        notes=body.notes,
        created_by_user_id=user.id,
    )
    db.add(walk)
    db.commit()
    return _walk_out(walk)


@router.get("/cases/{case_id}/boundary/walks", response_model=list[WalkOut])
def list_walks(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> list[WalkOut]:
    load_case(db, principal, case_id)
    walks = db.find(
        BoundaryWalk,
        {"case_id": case_id},
        sort=[("walked_on", 1), ("created_at", 1)],
    )
    return [_walk_out(w) for w in walks]


# ── Overlaps and disputes [Rule 12(3)] ────────────────────────────────────────


@router.post("/cases/{case_id}/boundary/conflicts/check", response_model=list[DisputeOut])
def check_conflicts(
    case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> list[DisputeOut]:
    """Re-run the overlap test against neighbours' current boundaries (BR-09)."""
    ctx = load_case(db, principal, case_id)
    ensure_claim_type(ctx, ClaimType.CFR, "NOT_A_FORM_C_CASE")
    if Role.GRAM_SABHA not in ctx.roles:
        raise ApiError(403, "NOT_YOUR_LEVEL", "workflow.not_your_level")
    geo.detect_overlaps(db, ctx.case, _current_or_404(db, ctx))
    db.commit()
    return geo.disputes_out(db, case_id)


@router.get("/cases/{case_id}/disputes", response_model=list[DisputeOut])
def list_disputes(
    case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> list[DisputeOut]:
    load_case(db, principal, case_id)
    return geo.disputes_out(db, case_id)


def _dispute_for_gs(db: DbSession, ctx: CaseContext, dispute_id: uuid.UUID) -> Dispute:
    if Role.GRAM_SABHA not in ctx.roles:
        raise ApiError(403, "NOT_YOUR_LEVEL", "workflow.not_your_level")
    d = db.get(Dispute, dispute_id)
    if d is None or ctx.case.id not in (d.case_id, d.neighbour_case_id):
        raise ApiError(404, "DISPUTE_NOT_FOUND", "dispute.not_found")
    if d.sdlc_referral_on is not None:
        raise ApiError(409, "DISPUTE_REFERRED", "dispute.already_referred")
    return d


def _one(db: DbSession, case_id: uuid.UUID, dispute_id: uuid.UUID) -> DisputeOut:
    return next(x for x in geo.disputes_out(db, case_id) if x.id == dispute_id)


@router.post("/cases/{case_id}/disputes/{dispute_id}/joint-meeting", response_model=DisputeOut)
def joint_meeting(
    case_id: uuid.UUID,
    dispute_id: uuid.UUID,
    body: JointMeetingIn,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> DisputeOut:
    """G17: the joint meeting of the Gram Sabhas / FRCs concerned and its outcome."""
    ctx = load_case(db, principal, case_id)
    d = _dispute_for_gs(db, ctx, dispute_id)
    if d.outcome is not None and d.outcome is not DisputeOutcome.NOT_RESOLVED:
        raise ApiError(409, "DISPUTE_SETTLED", "dispute.already_settled")
    _own_media(db, user, body.record_media_id)
    d.joint_meeting_on = body.held_on
    d.joint_meeting_findings = body.findings
    d.joint_meeting_media_id = body.record_media_id
    d.outcome = body.outcome
    db.commit()
    return _one(db, case_id, dispute_id)


@router.post("/cases/{case_id}/disputes/{dispute_id}/sdlc-referral", response_model=DisputeOut)
def sdlc_referral(
    case_id: uuid.UUID,
    dispute_id: uuid.UUID,
    body: SdlcReferralIn,
    db: DbSession,
    principal: CurrentPrincipal,
) -> DisputeOut:
    """
    Refer an unresolved overlap to the SDLC: after a joint meeting that did not resolve
    it, or once the time for a mutual solution has passed [Rule 12(3), 14(7)].
    """
    ctx = load_case(db, principal, case_id)
    d = _dispute_for_gs(db, ctx, dispute_id)
    if d.outcome is not None and d.outcome is not DisputeOutcome.NOT_RESOLVED:
        raise ApiError(409, "DISPUTE_SETTLED", "dispute.already_settled")
    waited = body.referred_on >= d.detected_on + timedelta(days=JOINT_SOLUTION_DAYS)
    if d.outcome is not DisputeOutcome.NOT_RESOLVED and not waited:
        raise RuleViolation(
            "JOINT_MEETING_FIRST",
            "Rule 12(3)",
            "dispute.joint_meeting_first",
            {"earliest_without_meeting": d.detected_on + timedelta(days=JOINT_SOLUTION_DAYS)},
        )
    d.sdlc_referral_on = body.referred_on
    d.sdlc_referral_ref = body.ref
    db.commit()
    return _one(db, case_id, dispute_id)
