"""Loading cases with jurisdiction + visibility checked, edit guards and workflow helpers."""

import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth.deps import village_ref
from ..auth.principal import Principal
from ..domain.dates import ist_date
from ..domain.workflow import can_view, resubmit_deadline
from ..errors import ApiError
from ..models import (
    CaseState,
    ClaimCase,
    ClaimType,
    GramSabha,
    Role,
    Village,
    WorkflowAction,
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


@dataclass(frozen=True)
class ReturnInfo:
    """A claim that was sent back to the villager and is waiting to be corrected."""

    by_role: Role
    by_name: str
    remarks: str
    returned_on: date
    resubmit_by: date


def returned_info(case: ClaimCase) -> ReturnInfo | None:
    """
    Set while the claim is a draft that was sent back and not yet resubmitted: who sent it
    back, why, and the last day the villager may resubmit (RESUBMIT_DAYS from the return).
    """
    if case.state is not CaseState.DRAFT or not case.events:
        return None
    last = case.events[-1]  # ordered by created_at
    if last.action is not WorkflowAction.RETURN or last.actor_role is None:
        return None
    returned_on = ist_date(last.created_at)
    return ReturnInfo(
        by_role=last.actor_role,
        by_name=last.actor_name,
        remarks=last.remarks or "",
        returned_on=returned_on,
        resubmit_by=resubmit_deadline(returned_on),
    )
