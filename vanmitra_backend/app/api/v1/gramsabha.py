"""
Field verification, Gram Sabha meetings with attendance and the three-test quorum, and
resolutions on claims (Stage 4) [Rule 4(2), 12(1), 12A(1)(2); Sec 6(1)].

The Gram Sabha login records all of it. Verification proceedings and resolutions are
append-only and hash-chained. A CFR resolution approves, and freezes, the boundary.
"""

import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy import func, select

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession, require_village_role, village_ref
from ...auth.principal import Principal
from ...domain.quorum import quorum
from ...errors import ApiError, RuleViolation
from ...models import (
    BoundaryStatus,
    CaseState,
    ClaimCase,
    ClaimType,
    GramSabha,
    GsMember,
    LetterTemplate,
    Role,
    Village,
)
from ...models.procedure import (
    Attendance,
    CaseClaimant,
    Correspondence,
    GsMeeting,
    Media,
    Recusal,
    Resolution,
    VerificationProceeding,
)
from ...schemas.gramsabha import (
    ApprovalCheckOut,
    AttendanceIn,
    MeetingIn,
    MeetingOut,
    Presence,
    QuorumOut,
    ResolutionIn,
    ResolutionOut,
    VerificationIn,
    VerificationOut,
)
from ...services import boundary as geo
from ...services import gramsabha as gs_facts
from ...services import ledger
from ...services.cases import CaseContext, load_case

router = APIRouter(tags=["gram-sabha"])

GramSabhaOnly = Annotated[tuple[Principal, Village], Depends(require_village_role(Role.GRAM_SABHA))]
AnyRole = Annotated[tuple[Principal, Village], Depends(require_village_role())]


def _gs(db: DbSession, village_id: uuid.UUID) -> GramSabha:
    gs = db.scalar(select(GramSabha).where(GramSabha.village_id == village_id))
    if gs is None:
        raise ApiError(409, "GRAM_SABHA_MISSING", "village.gram_sabha_missing")
    return gs


def _gs_case(db: DbSession, principal: CurrentPrincipal, case_id: uuid.UUID) -> CaseContext:
    ctx = load_case(db, principal, case_id)
    if Role.GRAM_SABHA not in ctx.roles:
        raise ApiError(403, "NOT_YOUR_LEVEL", "workflow.not_your_level")
    return ctx


def _recuse_if_claimant(db: DbSession, user: CurrentUser, case_id: uuid.UUID) -> None:
    """A Gram Sabha member who is a claimant takes no part in deciding the claim (BR-02)."""
    if user.gs_member_id is None:
        return
    is_claimant = db.scalar(
        select(CaseClaimant.id).where(
            CaseClaimant.case_id == case_id, CaseClaimant.gs_member_id == user.gs_member_id
        )
    )
    if not is_claimant:
        return
    if not db.scalar(
        select(Recusal.id).where(
            Recusal.case_id == case_id, Recusal.gs_member_id == user.gs_member_id
        )
    ):
        db.add(
            Recusal(
                case_id=case_id,
                gs_member_id=user.gs_member_id,
                reason="Claimant in this case; may not decide it [Rule 3(3)]",
            )
        )
        db.commit()
    raise RuleViolation("CLAIMANT_RECUSED", "Rule 3(3)", "case.claimant_recused")


def _own_media(db: DbSession, user: CurrentUser, media_id: uuid.UUID | None) -> None:
    if media_id is None:
        return
    media = db.get(Media, media_id)
    if media is None or media.uploaded_by_user_id != user.id:
        raise ApiError(422, "MEDIA_NOT_YOURS", "evidence.media_not_yours", {"media_id": media_id})


# ── Field verification ────────────────────────────────────────────────────────


def _verification_out(v: VerificationProceeding) -> VerificationOut:
    return VerificationOut(
        id=v.id,
        attempt_no=v.attempt_no,
        visit_on=v.visit_on,
        intimation_id=v.intimation_id,
        observations=v.observations,
        presence=[Presence.model_validate(p) for p in v.presence],
        forest_signed=v.forest_signed,
        forest_absence_recorded=v.forest_absence_recorded,
        revenue_signed=v.revenue_signed,
        revenue_absence_recorded=v.revenue_absence_recorded,
        signed_scan_media_id=v.signed_scan_media_id,
        complete=gs_facts.verification_complete(v),
        finality_note=gs_facts.finality_note(v),
        created_at=v.created_at,
    )


@router.post(
    "/cases/{case_id}/verification",
    response_model=VerificationOut,
    status_code=status.HTTP_201_CREATED,
)
def record_verification(
    case_id: uuid.UUID,
    body: VerificationIn,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> VerificationOut:
    """
    The site visit with the Forest and Revenue officials (BR-07). Each department must
    have signed, or its absence is recorded against the intimation that was sent. A
    second visit with an absence adds the note that the Gram Sabha decision is final
    [Rule 12A(2)]. Every visit is kept: this adds a row, never edits one.
    """
    ctx = _gs_case(db, principal, case_id)
    if ctx.case.state is not CaseState.GS_REVIEW:
        raise ApiError(409, "NOT_UNDER_GS_REVIEW", "evidence.not_under_gs_review")
    _recuse_if_claimant(db, user, case_id)
    _own_media(db, user, body.signed_scan_media_id)
    for dept, signed, absent in (
        ("forest", body.forest_signed, body.forest_absence_recorded),
        ("revenue", body.revenue_signed, body.revenue_absence_recorded),
    ):
        if signed and absent:
            raise ApiError(
                422, "SIGNED_AND_ABSENT", "verification.signed_and_absent", {"dept": dept}
            )
    absence = body.forest_absence_recorded or body.revenue_absence_recorded
    signed_any = body.forest_signed or body.revenue_signed
    if signed_any and body.signed_scan_media_id is None:
        raise ApiError(422, "SIGNED_SHEET_MISSING", "verification.signed_sheet_missing")
    if body.intimation_id is not None or absence:
        letter = db.get(Correspondence, body.intimation_id) if body.intimation_id else None
        if (
            letter is None
            or letter.gram_sabha_id != ctx.case.gram_sabha_id
            or letter.template is not LetterTemplate.G7_SITE_VISIT
            or letter.dispatched_on is None
            or letter.dispatched_on > body.visit_on
        ):
            raise RuleViolation(
                "INTIMATION_REQUIRED",
                "Rule 12A(1)(2)",
                "verification.intimation_required",
                {"needs": "a dispatched G7 letter sent before the visit"},
            )
    attempt = (
        db.scalar(
            select(func.max(VerificationProceeding.attempt_no)).where(
                VerificationProceeding.case_id == case_id
            )
        )
        or 0
    ) + 1
    row = VerificationProceeding(
        case_id=case_id,
        attempt_no=attempt,
        visit_on=body.visit_on,
        intimation_id=body.intimation_id,
        observations=body.observations,
        presence=[p.model_dump(mode="json") for p in body.presence],
        forest_signed=body.forest_signed,
        forest_absence_recorded=body.forest_absence_recorded,
        revenue_signed=body.revenue_signed,
        revenue_absence_recorded=body.revenue_absence_recorded,
        signed_scan_media_id=body.signed_scan_media_id,
        recorded_by_user_id=user.id,
    )
    db.add(row)
    ledger.append(db, ctx.case.gram_sabha_id, row)
    db.commit()
    return _verification_out(row)


@router.get("/cases/{case_id}/verification", response_model=list[VerificationOut])
def list_verifications(
    case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> list[VerificationOut]:
    load_case(db, principal, case_id)
    rows = db.scalars(
        select(VerificationProceeding)
        .where(VerificationProceeding.case_id == case_id)
        .order_by(VerificationProceeding.attempt_no)
    )
    return [_verification_out(v) for v in rows]


# ── Meetings and attendance ───────────────────────────────────────────────────


def _meeting_out(db: DbSession, m: GsMeeting) -> MeetingOut:
    present, women = gs_facts.meeting_counts(db, m)
    recorded = db.scalar(
        select(func.count()).select_from(Attendance).where(Attendance.meeting_id == m.id)
    )
    resolutions = db.scalar(
        select(func.count()).select_from(Resolution).where(Resolution.meeting_id == m.id)
    )
    return MeetingOut(
        id=m.id,
        held_on=m.held_on,
        place=m.place,
        notice_on=m.notice_on,
        agenda=m.agenda,
        registered_count=m.registered_count,
        present_count=present,
        women_present=women,
        attendance_recorded=bool(recorded),
        resolutions=resolutions or 0,
    )


def _meeting(
    db: DbSession, principal: CurrentPrincipal, meeting_id: uuid.UUID, *, write: bool
) -> GsMeeting:
    row = db.execute(
        select(GsMeeting, Village)
        .join(GramSabha, GramSabha.id == GsMeeting.gram_sabha_id)
        .join(Village, Village.id == GramSabha.village_id)
        .where(GsMeeting.id == meeting_id)
    ).first()
    if row is None or not principal.has(village_ref(row[1])):
        raise ApiError(404, "MEETING_NOT_FOUND", "meeting.not_found")
    if write and not principal.has(village_ref(row[1]), [Role.GRAM_SABHA]):
        raise ApiError(403, "FORBIDDEN", "auth.forbidden_in_village")
    return row[0]


@router.post(
    "/villages/{village_id}/meetings",
    response_model=MeetingOut,
    status_code=status.HTTP_201_CREATED,
)
def create_meeting(body: MeetingIn, db: DbSession, scope: GramSabhaOnly) -> MeetingOut:
    principal, village = scope
    gs = _gs(db, village.id)
    if body.notice_on and body.notice_on > body.held_on:
        raise ApiError(422, "NOTICE_AFTER_MEETING", "meeting.notice_after_meeting")
    registered = db.scalar(
        select(func.count())
        .select_from(GsMember)
        .where(GsMember.gram_sabha_id == gs.id, GsMember.active.is_(True))
    )
    meeting = GsMeeting(
        gram_sabha_id=gs.id,
        held_on=body.held_on,
        place=body.place,
        notice_on=body.notice_on,
        agenda=body.agenda,
        registered_count=registered or 0,
        created_by_user_id=principal.user_id,
    )
    db.add(meeting)
    db.commit()
    return _meeting_out(db, meeting)


@router.get("/villages/{village_id}/meetings", response_model=list[MeetingOut])
def list_meetings(db: DbSession, scope: AnyRole) -> list[MeetingOut]:
    gs = _gs(db, scope[1].id)
    rows = db.scalars(
        select(GsMeeting).where(GsMeeting.gram_sabha_id == gs.id).order_by(GsMeeting.held_on.desc())
    )
    return [_meeting_out(db, m) for m in rows]


@router.get("/meetings/{meeting_id}", response_model=MeetingOut)
def get_meeting(meeting_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> MeetingOut:
    return _meeting_out(db, _meeting(db, principal, meeting_id, write=False))


@router.put("/meetings/{meeting_id}/attendance", response_model=MeetingOut)
def put_attendance(
    meeting_id: uuid.UUID, body: AttendanceIn, db: DbSession, principal: CurrentPrincipal
) -> MeetingOut:
    """
    The manual attendance register: everyone on the active roster is marked present or
    absent. It can be corrected until a resolution has been recorded at this meeting.
    """
    meeting = _meeting(db, principal, meeting_id, write=True)
    if db.scalar(select(Resolution.id).where(Resolution.meeting_id == meeting.id)):
        raise ApiError(409, "ATTENDANCE_LOCKED", "meeting.attendance_locked")
    roster = {
        m.id
        for m in db.scalars(
            select(GsMember).where(
                GsMember.gram_sabha_id == meeting.gram_sabha_id, GsMember.active.is_(True)
            )
        )
    }
    present = set(body.present_member_ids)
    if not present <= roster:
        raise ApiError(422, "MEMBER_NOT_IN_ROSTER", "meeting.member_not_in_roster")
    meeting.attendance.clear()
    db.flush()
    meeting.attendance.extend(
        Attendance(gs_member_id=mid, present=mid in present, method="manual") for mid in roster
    )
    db.commit()
    return _meeting_out(db, meeting)


def _quorum(db: DbSession, meeting: GsMeeting, case_id: uuid.UUID | None) -> QuorumOut:
    present, women = gs_facts.meeting_counts(db, meeting)
    total, there = gs_facts.claimant_counts(db, meeting, case_id) if case_id else (0, 0)
    q = quorum(
        registered=meeting.registered_count,
        present=present,
        women_present=women,
        claimants_total=total,
        claimants_present=there,
    )
    return QuorumOut(**q.proof())


@router.get("/meetings/{meeting_id}/quorum", response_model=QuorumOut)
def meeting_quorum(
    meeting_id: uuid.UUID,
    db: DbSession,
    principal: CurrentPrincipal,
    case_id: uuid.UUID | None = None,
) -> QuorumOut:
    """Live preview of the three quorum tests [Rule 4(2)]; give `case_id` for a claim."""
    return _quorum(db, _meeting(db, principal, meeting_id, write=False), case_id)


# ── Resolutions ───────────────────────────────────────────────────────────────


def _resolution_out(r: Resolution) -> ResolutionOut:
    return ResolutionOut(
        id=r.id,
        meeting_id=r.meeting_id,
        case_id=r.case_id,
        number=r.number,
        decision_text=r.decision_text,
        votes_for=r.votes_for,
        votes_against=r.votes_against,
        boundary_id=r.boundary_id,
        quorum_proof=r.quorum_proof,
        signed_scan_media_id=r.signed_scan_media_id,
        created_at=r.created_at,
    )


@router.post(
    "/meetings/{meeting_id}/resolutions",
    response_model=ResolutionOut,
    status_code=status.HTTP_201_CREATED,
)
def record_resolution(
    meeting_id: uuid.UUID,
    body: ResolutionIn,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> ResolutionOut:
    """
    Record the resolution on a claim under review. All three quorum tests must pass
    (BR-03) and the motion must carry by a simple majority of those voting. For a CFR
    claim the resolution approves the current boundary: every segment needs a landmark
    (BR-08) and no overlap may be open (BR-09); the boundary is then frozen.
    """
    meeting = _meeting(db, principal, meeting_id, write=True)
    case = db.get(ClaimCase, body.case_id)
    if case is None or case.gram_sabha_id != meeting.gram_sabha_id:
        raise ApiError(404, "CASE_NOT_FOUND", "case.not_found")
    _gs_case(db, principal, case.id)
    if case.state is not CaseState.GS_REVIEW:
        raise ApiError(409, "NOT_UNDER_GS_REVIEW", "evidence.not_under_gs_review")
    _recuse_if_claimant(db, user, case.id)
    _own_media(db, user, body.signed_scan_media_id)

    present, _ = gs_facts.meeting_counts(db, meeting)
    if body.votes_for + body.votes_against > present:
        raise ApiError(422, "MORE_VOTES_THAN_PRESENT", "resolution.more_votes_than_present")
    if body.votes_for <= body.votes_against:
        raise RuleViolation("MOTION_NOT_CARRIED", "Rule 4(2)", "resolution.not_carried")
    q = _quorum(db, meeting, case.id)
    if not q.passed:
        raise RuleViolation(
            "QUORUM_FAILED",
            "Rule 4(2)",
            "resolution.quorum_failed",
            {"failures": q.failures, **q.model_dump()},
        )

    boundary_id = None
    if case.claim_type is ClaimType.CFR:
        b = geo.current_boundary(db, case.id)
        if b is None:
            raise ApiError(409, "NO_BOUNDARY", "boundary.none")
        if geo.segments_without_landmark(b):
            raise RuleViolation(
                "LANDMARK_PER_SEGMENT", "Rule 12(1)(g)", "boundary.landmark_per_segment"
            )
        if geo.open_disputes(db, case.id):
            raise RuleViolation("OPEN_DISPUTE", "Rule 12(3)", "boundary.open_dispute")
        if b.status is BoundaryStatus.DRAFT:
            geo.seal(db, b)
        boundary_id = b.id

    db.execute(select(GramSabha.id).where(GramSabha.id == case.gram_sabha_id).with_for_update())
    year = date.today().year
    used = db.scalar(
        select(func.count())
        .select_from(Resolution)
        .where(Resolution.gram_sabha_id == case.gram_sabha_id, Resolution.number.like(f"%/{year}"))
    )
    previous = gs_facts.current_resolution(db, case.id)
    row = Resolution(
        gram_sabha_id=case.gram_sabha_id,
        meeting_id=meeting.id,
        case_id=case.id,
        number=f"{(used or 0) + 1}/{year}",
        decision_text=body.decision_text,
        votes_for=body.votes_for,
        votes_against=body.votes_against,
        boundary_id=boundary_id,
        quorum_proof=q.model_dump(),
        signed_scan_media_id=body.signed_scan_media_id,
        supersedes_id=previous.id if previous else None,
        created_by_user_id=user.id,
    )
    db.add(row)
    ledger.append(db, case.gram_sabha_id, row)
    db.commit()
    return _resolution_out(row)


@router.get("/cases/{case_id}/resolutions", response_model=list[ResolutionOut])
def list_resolutions(
    case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> list[ResolutionOut]:
    load_case(db, principal, case_id)
    rows = db.scalars(
        select(Resolution).where(Resolution.case_id == case_id).order_by(Resolution.created_at)
    )
    return [_resolution_out(r) for r in rows]


@router.get("/cases/{case_id}/approval-check", response_model=ApprovalCheckOut)
def approval_check(
    case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> ApprovalCheckOut:
    """What stands between the Gram Sabha and forwarding the claim to the SDO (BR-04)."""
    ctx = load_case(db, principal, case_id)
    return gs_facts.approval_check(db, ctx)
