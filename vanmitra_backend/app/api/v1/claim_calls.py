"""
The call for claims [Rule 11(1)] and tracked letters (G2, G5, G6, G7, G18).

The Gram Sabha calls for claims with a three-month window, extendable only with
written reasons and a resolution reference, and fixes the date for initiating the
CFR determination. Letters are tracked from drafting to dispatch, reminder and reply.
"""

import uuid
from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select

from ...auth.deps import CurrentPrincipal, DbSession, require_village_role, village_ref
from ...auth.principal import Principal
from ...domain.dates import CLAIM_WINDOW_MONTHS, add_months
from ...errors import ApiError, RuleViolation
from ...models import ClaimCase, GramSabha, LetterTemplate, Role, Village
from ...models.procedure import ClaimCall, Correspondence
from ...schemas.evidence import (
    ClaimCallCreate,
    ClaimCallDisplayed,
    ClaimCallExtend,
    ClaimCallOut,
    LetterCreate,
    LetterDispatch,
    LetterOut,
    LetterResponse,
)

router = APIRouter(tags=["claim-call", "letters"])

AnyRole = Annotated[tuple[Principal, Village], Depends(require_village_role())]
GramSabhaOnly = Annotated[tuple[Principal, Village], Depends(require_village_role(Role.GRAM_SABHA))]


def _gs(db: DbSession, village_id: uuid.UUID) -> GramSabha:
    gs = db.scalar(select(GramSabha).where(GramSabha.village_id == village_id))
    if gs is None:
        raise ApiError(409, "GRAM_SABHA_MISSING", "village.gram_sabha_missing")
    return gs


def current_claim_call(db: DbSession, gram_sabha_id: uuid.UUID) -> ClaimCall | None:
    return db.scalar(
        select(ClaimCall).where(
            ClaimCall.gram_sabha_id == gram_sabha_id, ClaimCall.is_current.is_(True)
        )
    )


def _call_out(c: ClaimCall, today: date | None = None) -> ClaimCallOut:
    today = today or date.today()
    return ClaimCallOut(
        id=c.id,
        called_on=c.called_on,
        window_ends_on=c.window_ends_on,
        closes_on=c.closes_on,
        days_remaining=max((c.closes_on - today).days, 0),
        is_open=c.called_on <= today <= c.closes_on,
        place_of_filing=c.place_of_filing,
        notice_displayed_on=c.notice_displayed_on,
        cfr_determination_on=c.cfr_determination_on,
        extended_to=c.extended_to,
        extension_reason=c.extension_reason,
        extension_resolution_ref=c.extension_resolution_ref,
        is_current=c.is_current,
    )


# ── Call for claims ───────────────────────────────────────────────────────────


@router.post(
    "/villages/{village_id}/claim-calls",
    response_model=ClaimCallOut,
    status_code=status.HTTP_201_CREATED,
)
def call_for_claims(body: ClaimCallCreate, db: DbSession, scope: GramSabhaOnly) -> ClaimCallOut:
    """Open a call for claims: window = three months from the date of calling [Rule 11(1)(a)]."""
    principal, village = scope
    gs = _gs(db, village.id)
    if body.notice_displayed_on and body.notice_displayed_on < body.called_on:
        raise ApiError(422, "NOTICE_BEFORE_CALL", "claim_call.notice_before_call")
    for old in db.scalars(
        select(ClaimCall).where(ClaimCall.gram_sabha_id == gs.id, ClaimCall.is_current.is_(True))
    ):
        old.is_current = False
    call = ClaimCall(
        gram_sabha_id=gs.id,
        called_on=body.called_on,
        window_ends_on=add_months(body.called_on, CLAIM_WINDOW_MONTHS),
        place_of_filing=body.place_of_filing,
        notice_displayed_on=body.notice_displayed_on,
        cfr_determination_on=body.cfr_determination_on,
        is_current=True,
        created_by_user_id=principal.user_id,
    )
    db.add(call)
    db.commit()
    db.refresh(call)
    return _call_out(call)


def _current_or_404(db: DbSession, village_id: uuid.UUID) -> ClaimCall:
    call = current_claim_call(db, _gs(db, village_id).id)
    if call is None:
        raise ApiError(404, "NO_CLAIM_CALL", "claim_call.none")
    return call


@router.get("/villages/{village_id}/claim-calls/current", response_model=ClaimCallOut)
def get_current_call(db: DbSession, scope: AnyRole) -> ClaimCallOut:
    return _call_out(_current_or_404(db, scope[1].id))


@router.get("/villages/{village_id}/claim-calls", response_model=list[ClaimCallOut])
def call_history(db: DbSession, scope: AnyRole) -> list[ClaimCallOut]:
    gs = _gs(db, scope[1].id)
    rows = db.scalars(
        select(ClaimCall)
        .where(ClaimCall.gram_sabha_id == gs.id)
        .order_by(ClaimCall.called_on.desc())
    ).all()
    return [_call_out(c) for c in rows]


@router.post("/villages/{village_id}/claim-calls/current/extend", response_model=ClaimCallOut)
def extend_call(body: ClaimCallExtend, db: DbSession, scope: GramSabhaOnly) -> ClaimCallOut:
    """Extend the window: written reasons and the resolution are mandatory [Rule 11(1)(a)]."""
    call = _current_or_404(db, scope[1].id)
    if body.extended_to <= call.closes_on:
        raise RuleViolation(
            "EXTENSION_NOT_LATER",
            "Rule 11(1)(a)",
            "claim_call.extension_not_later",
            {"closes_on": call.closes_on},
        )
    call.extended_to = body.extended_to
    call.extension_reason = body.reason
    call.extension_resolution_ref = body.resolution_ref
    db.commit()
    db.refresh(call)
    return _call_out(call)


@router.post("/villages/{village_id}/claim-calls/current/displayed", response_model=ClaimCallOut)
def notice_displayed(body: ClaimCallDisplayed, db: DbSession, scope: GramSabhaOnly) -> ClaimCallOut:
    """Record the date the G1 notice was displayed at the customary public place."""
    call = _current_or_404(db, scope[1].id)
    if body.notice_displayed_on < call.called_on:
        raise ApiError(422, "NOTICE_BEFORE_CALL", "claim_call.notice_before_call")
    call.notice_displayed_on = body.notice_displayed_on
    db.commit()
    db.refresh(call)
    return _call_out(call)


# ── Letters ───────────────────────────────────────────────────────────────────


def _letter_out(c: Correspondence, today: date | None = None) -> LetterOut:
    today = today or date.today()
    return LetterOut(
        id=c.id,
        template=c.template,
        addressee=c.addressee,
        subject=c.subject,
        body=c.body,
        case_id=c.case_id,
        neighbour_village=c.neighbour_village,
        records_requested=list(c.records_requested),
        dispatched_on=c.dispatched_on,
        reminder_on=c.reminder_on,
        reminder_due=bool(
            c.reminder_on and c.response_received_on is None and today >= c.reminder_on
        ),
        response_received_on=c.response_received_on,
        outcome=c.outcome,
        created_at=c.created_at,
    )


@router.post(
    "/villages/{village_id}/letters", response_model=LetterOut, status_code=status.HTTP_201_CREATED
)
def create_letter(body: LetterCreate, db: DbSession, scope: GramSabhaOnly) -> LetterOut:
    principal, village = scope
    gs = _gs(db, village.id)
    if body.template is LetterTemplate.G2_INTIMATION_ADJOINING and not body.neighbour_village:
        raise ApiError(422, "NEIGHBOUR_VILLAGE_REQUIRED", "letter.neighbour_village_required")
    if body.case_id is not None:
        case = db.get(ClaimCase, body.case_id)
        if case is None or case.gram_sabha_id != gs.id:
            raise ApiError(422, "CASE_NOT_IN_VILLAGE", "letter.case_not_in_village")
    letter = Correspondence(
        gram_sabha_id=gs.id,
        case_id=body.case_id,
        template=body.template,
        addressee=body.addressee,
        subject=body.subject,
        body=body.body,
        neighbour_village=body.neighbour_village,
        records_requested=list(body.records_requested),
        created_by_user_id=principal.user_id,
    )
    db.add(letter)
    db.commit()
    db.refresh(letter)
    return _letter_out(letter)


@router.get("/villages/{village_id}/letters", response_model=list[LetterOut])
def list_letters(
    db: DbSession,
    scope: AnyRole,
    case_id: uuid.UUID | None = None,
    template: Annotated[LetterTemplate | None, Query()] = None,
) -> list[LetterOut]:
    query = select(Correspondence).where(Correspondence.gram_sabha_id == _gs(db, scope[1].id).id)
    if case_id:
        query = query.where(Correspondence.case_id == case_id)
    if template:
        query = query.where(Correspondence.template == template)
    return [_letter_out(c) for c in db.scalars(query.order_by(Correspondence.created_at)).all()]


def _letter_for_gs(db: DbSession, principal: Principal, letter_id: uuid.UUID) -> Correspondence:
    row = db.execute(
        select(Correspondence, Village)
        .join(GramSabha, GramSabha.id == Correspondence.gram_sabha_id)
        .join(Village, Village.id == GramSabha.village_id)
        .where(Correspondence.id == letter_id)
    ).first()
    if row is None or not principal.has(village_ref(row[1])):
        raise ApiError(404, "LETTER_NOT_FOUND", "letter.not_found")
    if not principal.has(village_ref(row[1]), [Role.GRAM_SABHA]):
        raise ApiError(403, "FORBIDDEN", "auth.forbidden_in_village")
    return row[0]


@router.post("/letters/{letter_id}/dispatch", response_model=LetterOut)
def dispatch_letter(
    letter_id: uuid.UUID, body: LetterDispatch, db: DbSession, principal: CurrentPrincipal
) -> LetterOut:
    letter = _letter_for_gs(db, principal, letter_id)
    letter.dispatched_on = body.dispatched_on
    letter.reminder_on = body.dispatched_on + timedelta(days=body.reminder_after_days)
    db.commit()
    db.refresh(letter)
    return _letter_out(letter)


@router.post("/letters/{letter_id}/response", response_model=LetterOut)
def record_response(
    letter_id: uuid.UUID, body: LetterResponse, db: DbSession, principal: CurrentPrincipal
) -> LetterOut:
    letter = _letter_for_gs(db, principal, letter_id)
    if letter.dispatched_on is None or body.received_on < letter.dispatched_on:
        raise ApiError(422, "RESPONSE_BEFORE_DISPATCH", "letter.response_before_dispatch")
    letter.response_received_on = body.received_on
    letter.outcome = body.outcome
    db.commit()
    db.refresh(letter)
    return _letter_out(letter)
