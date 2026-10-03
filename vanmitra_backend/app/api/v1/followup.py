"""
Legal clocks for a case, and the record after the title is issued (Stage 5): the
certified copy, the survey request and the entry in the record of rights. A case cannot
be closed without the certified copy and the record entry (BR-13) [Rule 8(i), 12A(9)].
"""

import uuid
from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter
from pydantic import BaseModel, StringConstraints
from sqlalchemy import select

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession
from ...domain.clocks import (
    ALERT_DAYS,
    MUTUAL_SOLUTION_DAYS,
    RECORD_UPDATE_MONTHS,
    Clock,
    clock,
    petition_due,
)
from ...domain.dates import add_months
from ...errors import ApiError, RuleViolation
from ...models import DISTRICT_ROLES, CaseState, ClaimCase, Dispute, Role
from ...models.procedure import ClaimCall, Correspondence, Media, TitleFollowup
from ...services import gramsabha as gs_facts
from ...services.cases import CaseContext, load_case

router = APIRouter(tags=["follow-up"])

Ref = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
OFFICIALS = {Role.GRAM_SABHA, Role.SDO, *DISTRICT_ROLES}


class ClockOut(BaseModel):
    kind: str
    rule: str
    starts_on: date
    due_on: date
    status: str
    days_remaining: int
    next_alert_on: date | None


class FollowupIn(BaseModel):
    certified_copy_media_id: uuid.UUID | None = None
    certified_copy_on: date | None = None
    survey_letter_id: uuid.UUID | None = None
    survey_done_on: date | None = None
    record_entry_on: date | None = None
    record_entry_ref: Ref | None = None
    record_entry_media_id: uuid.UUID | None = None


class FollowupOut(FollowupIn):
    case_id: uuid.UUID
    title_issued_on: date | None
    record_update_due_on: date | None
    survey_pending: bool
    can_close: bool
    missing: list[str]
    closed_on: date | None


def _title_issued_on(case: ClaimCase) -> date | None:
    for ev in reversed(case.events):
        if ev.to_state is CaseState.TITLE_ISSUED:
            return ev.created_at.date()
    return None


def _followup(db: DbSession, case_id: uuid.UUID) -> TitleFollowup | None:
    return db.scalar(select(TitleFollowup).where(TitleFollowup.case_id == case_id))


def _out(ctx: CaseContext, f: TitleFollowup | None) -> FollowupOut:
    issued = _title_issued_on(ctx.case)
    missing = []
    if f is None or f.certified_copy_media_id is None:
        missing.append("certified_copy")
    if f is None or f.record_entry_on is None:
        missing.append("record_entry")
    return FollowupOut(
        case_id=ctx.case.id,
        certified_copy_media_id=f.certified_copy_media_id if f else None,
        certified_copy_on=f.certified_copy_on if f else None,
        survey_letter_id=f.survey_letter_id if f else None,
        survey_done_on=f.survey_done_on if f else None,
        record_entry_on=f.record_entry_on if f else None,
        record_entry_ref=f.record_entry_ref if f else None,
        record_entry_media_id=f.record_entry_media_id if f else None,
        title_issued_on=issued,
        record_update_due_on=add_months(issued, RECORD_UPDATE_MONTHS) if issued else None,
        survey_pending=bool(
            ctx.case.state is CaseState.TITLE_ISSUED and not (f and f.survey_done_on)
        ),
        can_close=ctx.case.state is CaseState.TITLE_ISSUED and not missing,
        missing=missing,
        closed_on=f.closed_on if f else None,
    )


def _ensure_official(ctx: CaseContext) -> None:
    if not (ctx.roles & OFFICIALS):
        raise ApiError(403, "NOT_YOUR_LEVEL", "workflow.not_your_level")
    if ctx.case.state is not CaseState.TITLE_ISSUED:
        raise ApiError(409, "TITLE_NOT_ISSUED", "followup.title_not_issued")


@router.get("/cases/{case_id}/post-title", response_model=FollowupOut)
def get_followup(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> FollowupOut:
    ctx = load_case(db, principal, case_id)
    return _out(ctx, _followup(db, case_id))


@router.put("/cases/{case_id}/post-title", response_model=FollowupOut)
def put_followup(
    case_id: uuid.UUID,
    body: FollowupIn,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> FollowupOut:
    """Certified title copy, survey request and record-of-rights entry [Rule 8(i), 12A(9)]."""
    ctx = load_case(db, principal, case_id)
    _ensure_official(ctx)
    f = _followup(db, case_id)
    if f is not None and f.closed_on is not None:
        raise ApiError(409, "CASE_CLOSED", "followup.closed")
    for media_id in (body.certified_copy_media_id, body.record_entry_media_id):
        media = db.get(Media, media_id) if media_id else None
        if media_id and (media is None or media.uploaded_by_user_id != user.id):
            raise ApiError(422, "MEDIA_NOT_YOURS", "evidence.media_not_yours")
    if body.survey_letter_id:
        letter = db.get(Correspondence, body.survey_letter_id)
        if letter is None or letter.gram_sabha_id != ctx.case.gram_sabha_id:
            raise ApiError(422, "LETTER_NOT_IN_VILLAGE", "letter.not_found")
    if f is None:
        f = TitleFollowup(case_id=case_id, updated_by_user_id=user.id)
        db.add(f)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(f, field, value)
    f.updated_by_user_id = user.id
    db.commit()
    return _out(ctx, f)


@router.post("/cases/{case_id}/close", response_model=FollowupOut)
def close_case(
    case_id: uuid.UUID, db: DbSession, user: CurrentUser, principal: CurrentPrincipal
) -> FollowupOut:
    """Close the file. Needs the certified title copy and the record entry (BR-13)."""
    ctx = load_case(db, principal, case_id)
    _ensure_official(ctx)
    f = _followup(db, case_id)
    out = _out(ctx, f)
    if out.missing:
        raise RuleViolation(
            "CANNOT_CLOSE", "Rule 8(i), 12A(9)", "followup.cannot_close", {"missing": out.missing}
        )
    assert f is not None
    if f.closed_on is None:
        f.closed_on = date.today()
        f.updated_by_user_id = user.id
        db.commit()
    return _out(ctx, f)


# ── Clocks ────────────────────────────────────────────────────────────────────


def case_clocks(db: DbSession, ctx: CaseContext, today: date) -> list[Clock]:
    case = ctx.case
    out: list[Clock] = []
    call = db.get(ClaimCall, case.claim_call_id) if case.claim_call_id else None
    if call is not None:
        out.append(
            clock(
                "claim_window",
                "Rule 11(1)(a)",
                call.called_on,
                call.closes_on,
                today,
                met_on=case.acknowledged_on if case.filed_within_window else None,
            )
        )
    res = gs_facts.current_resolution(db, case.id)
    if res is not None:
        start = res.created_at.date()
        out.append(
            clock(
                "petition_against_resolution",
                "Sec 6(2), Rule 14(1)",
                start,
                petition_due(start),
                today,
                alerts=ALERT_DAYS,
            )
        )
    for d in db.scalars(
        select(Dispute).where((Dispute.case_id == case.id) | (Dispute.neighbour_case_id == case.id))
    ):
        if d.overlap_ha <= 0:
            continue
        out.append(
            clock(
                "mutual_solution",
                "Rule 14(7)",
                d.detected_on,
                d.detected_on + timedelta(days=MUTUAL_SOLUTION_DAYS),
                today,
                met_on=d.joint_meeting_on or d.sdlc_referral_on,
            )
        )
    issued = _title_issued_on(case)
    if issued is not None:
        f = _followup(db, case.id)
        out.append(
            clock(
                "record_update",
                "Rule 12A(9)",
                issued,
                add_months(issued, RECORD_UPDATE_MONTHS),
                today,
                met_on=f.record_entry_on if f else None,
            )
        )
    return out


@router.get("/cases/{case_id}/timeline", response_model=list[ClockOut])
def timeline(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> list[ClockOut]:
    """Running statutory periods of this case, with days left and the next reminder date."""
    ctx = load_case(db, principal, case_id)
    return [
        ClockOut(
            kind=c.kind,
            rule=c.rule,
            starts_on=c.starts_on,
            due_on=c.due_on,
            status=c.status.value,
            days_remaining=c.days_remaining,
            next_alert_on=c.next_alert_on,
        )
        for c in case_clocks(db, ctx, date.today())
    ]
