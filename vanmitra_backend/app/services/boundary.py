"""
PostGIS work for the boundary: validity, areas in UTM 43N, GeoJSON out, and overlap
detection against neighbouring villages' claims, which opens disputes [Rule 12(3)].
"""

import json
import uuid
from datetime import date
from decimal import Decimal
from typing import Any

from geoalchemy2 import WKTElement
from sqlalchemy import ColumnElement, and_, func, or_, select
from sqlalchemy.orm import Session, aliased

from ..geo import GeoError
from ..models import (
    BoundaryLandmark,
    BoundarySegment,
    BoundaryStatus,
    CaseState,
    CfrBoundary,
    ClaimCase,
    ClaimType,
    Dispute,
    DisputeOutcome,
    GramSabha,
    UseZone,
    Village,
)
from ..models.boundary import AREA_SRID, SRID
from ..schemas.boundary import (
    BoundaryOut,
    DisputeOut,
    LandmarkOut,
    SegmentOut,
    UseZoneOut,
)

GPS_LIMIT_M = 15.0  # B-14
MIN_OVERLAP_HA = Decimal("0.0001")  # 1 m²: below this it is GPS noise along a shared edge
EMPTY = WKTElement("GEOMETRYCOLLECTION EMPTY", srid=SRID)


def element(wkt: str) -> WKTElement:
    return WKTElement(wkt, srid=SRID)


def _from_wkt(wkt: str) -> ColumnElement[Any]:
    return func.ST_GeomFromText(wkt, SRID)


def ensure_valid(db: Session, wkt: str) -> None:
    reason = db.scalar(select(func.ST_IsValidReason(_from_wkt(wkt))))
    if reason != "Valid Geometry":
        raise GeoError("geo.invalid_polygon", str(reason))


def area_ha(db: Session, wkt: str) -> Decimal:
    m2 = db.scalar(select(func.ST_Area(func.ST_Transform(_from_wkt(wkt), AREA_SRID))))
    return (Decimal(str(m2 or 0)) / 10000).quantize(Decimal("0.0001"))


def length_m(db: Session, wkt: str) -> float:
    m = db.scalar(select(func.ST_Length(func.ST_Transform(_from_wkt(wkt), AREA_SRID))))
    return round(float(m or 0), 2)


def as_json(text: str | None) -> dict[str, Any]:
    return dict(json.loads(text)) if text else {}


def current_boundary(db: Session, case_id: uuid.UUID) -> CfrBoundary | None:
    return db.scalar(
        select(CfrBoundary).where(CfrBoundary.case_id == case_id, CfrBoundary.is_current.is_(True))
    )


# ── Output ────────────────────────────────────────────────────────────────────


def _segments(db: Session, b: CfrBoundary) -> list[SegmentOut]:
    counts: dict[int, int] = {}
    for lm in b.landmarks:
        counts[lm.segment_seq] = counts.get(lm.segment_seq, 0) + 1
    rows = db.execute(
        select(
            BoundarySegment.seq,
            func.ST_AsGeoJSON(BoundarySegment.geom, 7),
            BoundarySegment.length_m,
        )
        .where(BoundarySegment.boundary_id == b.id)
        .order_by(BoundarySegment.seq)
    ).all()
    return [
        SegmentOut(seq=seq, geometry=as_json(g), length_m=length, landmark_count=counts.get(seq, 0))
        for seq, g, length in rows
    ]


def landmarks_out(db: Session, boundary_id: uuid.UUID) -> list[LandmarkOut]:
    seg = aliased(BoundarySegment)
    distance = func.ST_Distance(func.Geography(BoundaryLandmark.point), func.Geography(seg.geom))
    rows = db.execute(
        select(
            BoundaryLandmark,
            func.ST_X(BoundaryLandmark.point),
            func.ST_Y(BoundaryLandmark.point),
            distance,
        )
        .outerjoin(
            seg,
            and_(
                seg.boundary_id == BoundaryLandmark.boundary_id,
                seg.seq == BoundaryLandmark.segment_seq,
            ),
        )
        .where(BoundaryLandmark.boundary_id == boundary_id)
        .order_by(BoundaryLandmark.segment_seq, BoundaryLandmark.created_at)
    ).all()
    return [
        LandmarkOut(
            id=lm.id,
            segment_seq=lm.segment_seq,
            name=lm.name,
            kind=lm.kind,
            lon=lon,
            lat=lat,
            distance_to_segment_m=round(float(d or 0), 1),
            photo_media_id=lm.photo_media_id,
            evidence_id=lm.evidence_id,
        )
        for lm, lon, lat, d in rows
    ]


def use_zones_out(db: Session, boundary_id: uuid.UUID) -> list[UseZoneOut]:
    rows = db.execute(
        select(
            UseZone,
            func.ST_AsGeoJSON(UseZone.geom, 7),
            func.ST_CoveredBy(UseZone.geom, CfrBoundary.geom),
        )
        .join(CfrBoundary, CfrBoundary.id == UseZone.boundary_id)
        .where(UseZone.boundary_id == boundary_id)
        .order_by(UseZone.created_at)
    ).all()
    return [
        UseZoneOut(
            id=z.id,
            use_type=z.use_type,
            name=z.name,
            geometry=as_json(g),
            area_ha=z.area_ha,
            season=z.season,
            user_hamlets=list(z.user_hamlets),
            within_boundary=bool(inside),
        )
        for z, g, inside in rows
    ]


def segments_without_landmark(b: CfrBoundary) -> int:
    marked = {lm.segment_seq for lm in b.landmarks}
    return sum(1 for s in b.segments if s.seq not in marked)


def boundary_out(db: Session, b: CfrBoundary) -> BoundaryOut:
    geometry = db.scalar(
        select(func.ST_AsGeoJSON(CfrBoundary.geom, 7)).where(CfrBoundary.id == b.id)
    )
    return BoundaryOut(
        id=b.id,
        case_id=b.case_id,
        version=b.version,
        status=b.status,
        source=b.source,
        geometry=as_json(geometry),
        area_ha=b.area_ha,
        accuracy_stats=b.accuracy_stats,
        sealed_hash=b.sealed_hash,
        approved_on=b.approved_on,
        segments=_segments(db, b),
        landmarks=landmarks_out(db, b.id),
        use_zones=use_zones_out(db, b.id),
        segments_without_landmark=segments_without_landmark(b),
        open_disputes=open_disputes(db, b.case_id),
        created_at=b.created_at,
    )


# ── Disputes ──────────────────────────────────────────────────────────────────


def _involving(case_id: uuid.UUID) -> ColumnElement[bool]:
    return or_(Dispute.case_id == case_id, Dispute.neighbour_case_id == case_id)


def _open_clause() -> ColumnElement[bool]:
    return and_(
        Dispute.sdlc_referral_on.is_(None),
        Dispute.overlap_ha > 0,
        or_(Dispute.outcome.is_(None), Dispute.outcome == DisputeOutcome.NOT_RESOLVED),
    )


def open_disputes(db: Session, case_id: uuid.UUID) -> int:
    return (
        db.scalar(
            select(func.count()).select_from(Dispute).where(_involving(case_id), _open_clause())
        )
        or 0
    )


def detect_overlaps(
    db: Session, case: ClaimCase, boundary: CfrBoundary, today: date | None = None
) -> None:
    """
    Compare the boundary with every current CFR boundary of another Gram Sabha. Each
    overlap opens (or refreshes) a dispute; open disputes whose overlap has gone are
    emptied. Settled disputes are left as they were.
    """
    today = today or date.today()
    db.flush()
    other = aliased(CfrBoundary)
    other_case = aliased(ClaimCase)
    inter = func.ST_CollectionExtract(func.ST_Intersection(CfrBoundary.geom, other.geom), 3)
    rows = db.execute(
        select(
            other.case_id,
            other_case.gram_sabha_id,
            func.ST_AsEWKT(inter),
            func.ST_Area(func.ST_Transform(inter, AREA_SRID)),
        )
        .select_from(CfrBoundary)
        .join(other, func.ST_Intersects(CfrBoundary.geom, other.geom))
        .join(other_case, other_case.id == other.case_id)
        .where(
            CfrBoundary.id == boundary.id,
            other.is_current.is_(True),
            other_case.claim_type == ClaimType.CFR,
            other_case.state != CaseState.REJECTED,
            other_case.gram_sabha_id != case.gram_sabha_id,
        )
    ).all()

    overlapping: set[uuid.UUID] = set()
    for neighbour_case_id, neighbour_gs_id, ewkt, m2 in rows:
        ha = (Decimal(str(m2 or 0)) / 10000).quantize(Decimal("0.0001"))
        if ha < MIN_OVERLAP_HA:
            continue
        overlapping.add(neighbour_case_id)
        geom = WKTElement(ewkt, extended=True)
        existing = db.scalar(
            select(Dispute).where(
                or_(
                    and_(
                        Dispute.case_id == case.id, Dispute.neighbour_case_id == neighbour_case_id
                    ),
                    and_(
                        Dispute.case_id == neighbour_case_id, Dispute.neighbour_case_id == case.id
                    ),
                )
            )
        )
        if existing is None:
            db.add(
                Dispute(
                    case_id=case.id,
                    neighbour_case_id=neighbour_case_id,
                    neighbour_gram_sabha_id=neighbour_gs_id,
                    overlap_geom=geom,
                    overlap_ha=ha,
                    detected_on=today,
                )
            )
        elif existing.sdlc_referral_on is None and existing.outcome in (
            None,
            DisputeOutcome.NOT_RESOLVED,
        ):
            existing.overlap_geom = geom
            existing.overlap_ha = ha

    for d in db.scalars(select(Dispute).where(_involving(case.id), _open_clause())):
        other_id = d.neighbour_case_id if d.case_id == case.id else d.case_id
        if other_id not in overlapping:
            d.overlap_geom = EMPTY
            d.overlap_ha = Decimal(0)


def disputes_out(db: Session, case_id: uuid.UUID) -> list[DisputeOut]:
    rows = db.execute(
        select(Dispute, func.ST_AsGeoJSON(Dispute.overlap_geom, 7))
        .where(_involving(case_id))
        .order_by(Dispute.created_at)
    ).all()
    out = []
    for d, g in rows:
        neighbour_case = d.neighbour_case_id if d.case_id == case_id else d.case_id
        village = db.scalar(
            select(Village)
            .join(GramSabha, GramSabha.village_id == Village.id)
            .join(ClaimCase, ClaimCase.gram_sabha_id == GramSabha.id)
            .where(ClaimCase.id == neighbour_case)
        )
        out.append(
            DisputeOut(
                id=d.id,
                case_id=case_id,
                neighbour_case_id=neighbour_case,
                neighbour_village=f"{village.name_mr} ({village.name_en})" if village else "",
                overlap=as_json(g),
                overlap_ha=d.overlap_ha,
                detected_on=d.detected_on,
                joint_meeting_on=d.joint_meeting_on,
                joint_meeting_findings=d.joint_meeting_findings,
                joint_meeting_media_id=d.joint_meeting_media_id,
                outcome=d.outcome,
                sdlc_referral_on=d.sdlc_referral_on,
                sdlc_referral_ref=d.sdlc_referral_ref,
                is_open=d.is_open,
            )
        )
    return out


def seal(db: Session, b: CfrBoundary, today: date | None = None) -> None:
    """Freeze the version the Gram Sabha approved: a hash of its geometry and landmarks."""
    import hashlib

    ewkt = db.scalar(select(func.ST_AsEWKT(CfrBoundary.geom)).where(CfrBoundary.id == b.id))
    marks = db.execute(
        select(
            BoundaryLandmark.segment_seq,
            BoundaryLandmark.name,
            func.ST_AsText(BoundaryLandmark.point),
        )
        .where(BoundaryLandmark.boundary_id == b.id)
        .order_by(BoundaryLandmark.segment_seq, BoundaryLandmark.name)
    ).all()
    payload = json.dumps([ewkt, [list(m) for m in marks]], separators=(",", ":"))
    b.sealed_hash = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    b.status = BoundaryStatus.GS_APPROVED
    b.approved_on = today or date.today()
