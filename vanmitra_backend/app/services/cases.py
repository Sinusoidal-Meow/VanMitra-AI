"""Loading cases with jurisdiction + visibility checked, edit guards and workflow helpers."""

import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth.deps import village_ref
from ..auth.principal import Principal
from ..domain.workflow import can_view
from ..errors import ApiError
from ..models import (
    DISTRICT_ROLES,
    CaseState,
    ClaimCase,
    ClaimType,
    GramSabha,
    Role,
    Village,
    WorkflowAction,
    WorkflowEvent,
)

# Who may open which form. Form A is an individual claim (village user); Form C is the
# Gram Sabha's community forest resource claim; Form B (community rights) either.
CREATORS: dict[ClaimType, frozenset[Role]] = {
    ClaimType.IFR: frozenset({Role.VILLAGER}),
    ClaimType.CR: frozenset({Role.VILLAGER, Role.GRAM_SABHA}),
    ClaimType.CFR: frozenset({Role.GRAM_SABHA}),
}


@dataclass
class CaseContext:
    case: ClaimCase
    village: Village
    roles: set[Role]  # caller's roles whose jurisdiction covers this village
    is_creator: bool

    @property
    def editable(self) -> bool:
        return self.case.state is CaseState.DRAFT and self.is_creator


def load_case(db: Session, principal: Principal, case_id: uuid.UUID) -> CaseContext:
    """The case if the caller may see it; otherwise 404 (existence is not revealed)."""
    row = db.execute(
        select(ClaimCase, Village)
        .join(GramSabha, GramSabha.id == ClaimCase.gram_sabha_id)
        .join(Village, Village.id == GramSabha.village_id)
        .where(ClaimCase.id == case_id)
    ).first()
    if row is None:
        raise ApiError(404, "CASE_NOT_FOUND", "case.not_found")
    case, village = row[0], row[1]
    roles = principal.roles_for(village_ref(village))
    is_creator = case.created_by_user_id == principal.user_id
    if not can_view(roles=roles, is_creator=is_creator, reached_stage=case.reached_stage):
        raise ApiError(404, "CASE_NOT_FOUND", "case.not_found")
    return CaseContext(case=case, village=village, roles=roles, is_creator=is_creator)


def ensure_editable(ctx: CaseContext) -> None:
    """Forms are edited only by their claimant, and only while the case is a draft."""
    if not ctx.is_creator:
        raise ApiError(403, "ONLY_CLAIMANT_CAN_EDIT", "case.only_claimant_edits")
    if ctx.case.state is not CaseState.DRAFT:
        raise ApiError(409, "CASE_NOT_EDITABLE", "case.not_editable", {"state": ctx.case.state})


def ensure_claim_type(ctx: CaseContext, claim_type: ClaimType, error: str) -> None:
    if ctx.case.claim_type is not claim_type:
        raise ApiError(409, error, "case.wrong_form", {"claim_type": ctx.case.claim_type})


def district_approvals(case: ClaimCase) -> frozenset[Role]:
    """District officers who have approved since the case last entered district review."""
    approvals: set[Role] = set()
    for ev in case.events:  # ordered by created_at
        if (
            ev.to_state is CaseState.DISTRICT_REVIEW
            and ev.from_state is not CaseState.DISTRICT_REVIEW
        ):
            approvals = set()  # a new district round starts
        elif (
            ev.action is WorkflowAction.APPROVE
            and ev.from_state is CaseState.DISTRICT_REVIEW
            and ev.actor_role in DISTRICT_ROLES
        ):
            approvals.add(ev.actor_role)
    return frozenset(approvals)


def district_signatories(case: ClaimCase) -> dict[Role, WorkflowEvent]:
    """The approving event of each district officer in the final (or current) round."""
    current: dict[Role, WorkflowEvent] = {}
    for ev in case.events:
        if (
            ev.to_state is CaseState.DISTRICT_REVIEW
            and ev.from_state is not CaseState.DISTRICT_REVIEW
        ):
            current = {}
        elif (
            ev.action is WorkflowAction.APPROVE
            and ev.from_state is CaseState.DISTRICT_REVIEW
            and ev.actor_role in DISTRICT_ROLES
        ):
            current[ev.actor_role] = ev
    return current
