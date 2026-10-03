"""
The claim path: submit → Gram Sabha → SDO → district (three officers) → title draft.
Rules live in domain.workflow; this router records every action in workflow_event.
"""

import uuid

from fastapi import APIRouter
from sqlalchemy import select

from ...auth.deps import CurrentPrincipal, DbSession, village_ref
from ...domain.workflow import STAGE, WorkflowError, decide
from ...errors import ApiError, RuleViolation
from ...models import CaseState, ClaimCase, GramSabha, Village, WorkflowAction, WorkflowEvent
from ...schemas.cases import ActionIn, CaseOut, EventOut, TitleDraftOut
from ...services import acknowledgement, ledger
from ...services.cases import CaseContext, district_approvals, load_case
from ...services.title import build_title_draft
from ._shared import case_out

router = APIRouter(tags=["workflow"])

REVIEW_STATES = (CaseState.GS_REVIEW, CaseState.SDO_REVIEW, CaseState.DISTRICT_REVIEW)


def _act(
    db: DbSession,
    principal: CurrentPrincipal,
    case_id: uuid.UUID,
    action: WorkflowAction,
    body: ActionIn | None,
) -> CaseOut:
    ctx = load_case(db, principal, case_id)
    case = ctx.case
    remarks = body.remarks if body else None
    try:
        decision = decide(
            state=case.state,
            action=action,
            actor_roles=ctx.roles,
            is_creator=ctx.is_creator,
            district_approvals=district_approvals(case),
            remarks=remarks,
        )
    except WorkflowError as e:
        if e.rule:
            raise RuleViolation(e.error, e.rule, e.message_key, status_code=e.status) from e
        raise ApiError(e.status, e.error, e.message_key, {"state": case.state}) from e

    if action is WorkflowAction.SUBMIT:
        # Written acknowledgement of the claim when first filed [Rule 11(3)].
        acknowledgement.issue(db, case, ctx.village)
    event = WorkflowEvent(
        case_id=case.id,
        action=action,
        from_state=case.state,
        to_state=decision.to_state,
        actor_user_id=principal.user_id,
        actor_role=decision.acting_role,
        actor_name=principal.name,
        remarks=remarks,
    )
    db.add(event)
    ledger.append(db, case.gram_sabha_id, event)
    case.state = decision.to_state
    case.reached_stage = max(case.reached_stage, STAGE.get(decision.to_state, 0))
    db.commit()
    db.refresh(case)
    db.expire(case, ["events"])  # reload history so approvals include this action
    return case_out(ctx)


@router.post("/cases/{case_id}/submit", response_model=CaseOut)
def submit(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> CaseOut:
    """The claimant files the draft to the Gram Panchayat / Gram Sabha."""
    return _act(db, principal, case_id, WorkflowAction.SUBMIT, None)


@router.post("/cases/{case_id}/approve", response_model=CaseOut)
def approve(
    case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal, body: ActionIn | None = None
) -> CaseOut:
    """
    Gram Sabha → SDO; SDO → district; at the district each officer approves once and the
    title is issued when the Collector, DFO and Tribal Welfare Officer have all approved.
    """
    return _act(db, principal, case_id, WorkflowAction.APPROVE, body)


@router.post("/cases/{case_id}/return", response_model=CaseOut)
def return_case(
    case_id: uuid.UUID, body: ActionIn, db: DbSession, principal: CurrentPrincipal
) -> CaseOut:
    """Send back one level with remarks: GS → claimant, SDO → GS, district → SDO."""
    return _act(db, principal, case_id, WorkflowAction.RETURN, body)


@router.post("/cases/{case_id}/reject", response_model=CaseOut)
def reject(
    case_id: uuid.UUID, body: ActionIn, db: DbSession, principal: CurrentPrincipal
) -> CaseOut:
    """Reject with written reasons [Rule 12A(7)]. Final in this module."""
    return _act(db, principal, case_id, WorkflowAction.REJECT, body)


@router.get("/cases/{case_id}/history", response_model=list[EventOut])
def history(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> list[EventOut]:
    """Every action on the case, oldest first: who, in which role, remarks, when."""
    ctx = load_case(db, principal, case_id)
    return [
        EventOut(
            action=e.action,
            from_state=e.from_state,
            to_state=e.to_state,
            actor_name=e.actor_name,
            actor_role=e.actor_role,
            remarks=e.remarks,
            at=e.created_at,
        )
        for e in ctx.case.events
    ]


@router.get("/review/queue", response_model=list[CaseOut])
def review_queue(db: DbSession, principal: CurrentPrincipal) -> list[CaseOut]:
    """Cases waiting for the caller's decision, across their jurisdiction, oldest first."""
    rows = db.execute(
        select(ClaimCase, Village)
        .join(GramSabha, GramSabha.id == ClaimCase.gram_sabha_id)
        .join(Village, Village.id == GramSabha.village_id)
        .where(ClaimCase.state.in_(REVIEW_STATES))
        .order_by(ClaimCase.updated_at)
    ).all()
    out = []
    for case, village in rows:
        roles = principal.roles_for(village_ref(village))
        if not roles:
            continue
        ctx = CaseContext(
            case=case,
            village=village,
            roles=roles,
            is_creator=case.created_by_user_id == principal.user_id,
        )
        item = case_out(ctx)
        if WorkflowAction.APPROVE in item.allowed_actions:
            out.append(item)
    return out


@router.get("/cases/{case_id}/title-draft", response_model=TitleDraftOut)
def title_draft(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> TitleDraftOut:
    """Annexure II / III / IV draft, available once the case reaches the district."""
    ctx = load_case(db, principal, case_id)
    if ctx.case.state not in (CaseState.DISTRICT_REVIEW, CaseState.TITLE_ISSUED):
        raise ApiError(409, "TITLE_NOT_AVAILABLE", "title.not_available", {"state": ctx.case.state})
    return build_title_draft(db, ctx)
