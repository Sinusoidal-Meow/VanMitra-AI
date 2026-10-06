"""
Claim cases: open a Form A / B / C claim, list and read cases.

Who opens which form (services.cases.CREATORS):
  Form A (ifr) individual claim ............ village user
  Form B (cr)  community rights ............ village user or Gram Sabha
  Form C (cfr) community forest resource ... Gram Sabha
Visibility: the claimant always; the Gram Sabha once filed to it; the SDO once it
reaches the SDO; district officers once it reaches the district (domain.workflow.can_view).
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy import select

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession, require_village_role, village_ref
from ...auth.principal import Principal
from ...domain.form_c import DEFAULT_RESOLUTION_STATEMENT
from ...domain.workflow import can_view
from ...errors import ApiError
from ...models import CaseState, ClaimCase, FormA, FormB, FormC, GramSabha, Role, Village
from ...schemas.cases import CaseCreate, CaseOut
from ...services.cases import CREATORS, CaseContext, load_case
from ._shared import case_out

router = APIRouter(tags=["cases"])


@router.post(
    "/villages/{village_id}/cases", response_model=CaseOut, status_code=status.HTTP_201_CREATED
)
def create_case(
    body: CaseCreate,
    db: DbSession,
    user: CurrentUser,
    scope: Annotated[
        tuple[Principal, Village], Depends(require_village_role(Role.VILLAGER, Role.GRAM_SABHA))
    ],
) -> CaseOut:
    """Open a claim: `ifr` → empty Form A, `cr` → empty Form B, `cfr` → empty Form C."""
    principal, village = scope
    roles = principal.roles_for(village_ref(village))
    if not roles & CREATORS[body.claim_type]:
        raise ApiError(
            403,
            "NOT_ALLOWED_TO_OPEN_FORM",
            "case.not_allowed_to_open_form",
            {"claim_type": body.claim_type, "allowed_roles": sorted(CREATORS[body.claim_type])},
        )
    gram_sabha = db.scalar(select(GramSabha).where(GramSabha.village_id == village.id))
    if gram_sabha is None:
        raise ApiError(409, "GRAM_SABHA_MISSING", "village.gram_sabha_missing")
    case = ClaimCase(
        gram_sabha_id=gram_sabha.id,
        claim_type=body.claim_type,
        state=CaseState.DRAFT,
        created_by_user_id=user.id,
        reached_stage=0,
    )
    if body.claim_type.value == "ifr":
        case.form_a = FormA(claimant_names=[], updated_by_user_id=user.id)
    elif body.claim_type.value == "cr":
        case.form_b = FormB(claimant_names=[], updated_by_user_id=user.id)
    else:
        case.form_c = FormC(
            resolution_statement=DEFAULT_RESOLUTION_STATEMENT,
            khasra_compartment_numbers=[],
            pastoral_seasonal_use=False,
            updated_by_user_id=user.id,
        )
    db.add(case)
    db.commit()
    db.refresh(case)
    return case_out(CaseContext(case=case, village=village, roles=roles, is_creator=True))


@router.get("/cases/mine", response_model=list[CaseOut])
def my_cases(db: DbSession, principal: CurrentPrincipal) -> list[CaseOut]:
    """Claims the caller has opened."""
    rows = db.execute(
        select(ClaimCase, Village)
        .join(GramSabha, GramSabha.id == ClaimCase.gram_sabha_id)
        .join(Village, Village.id == GramSabha.village_id)
        .where(ClaimCase.created_by_user_id == principal.user_id)
        .order_by(ClaimCase.created_at.desc())
    ).all()
    return [
        case_out(
            CaseContext(
                case=c, village=v, roles=principal.roles_for(village_ref(v)), is_creator=True
            )
        )
        for c, v in rows
    ]


@router.get("/villages/{village_id}/cases", response_model=list[CaseOut])
def village_cases(
    db: DbSession,
    scope: Annotated[tuple[Principal, Village], Depends(require_village_role())],
) -> list[CaseOut]:
    """Cases of a village that the caller may see (by role and how far each case has got)."""
    principal, village = scope
    roles = principal.roles_for(village_ref(village))
    cases = db.scalars(
        select(ClaimCase)
        .join(GramSabha, GramSabha.id == ClaimCase.gram_sabha_id)
        .where(GramSabha.village_id == village.id)
        .order_by(ClaimCase.created_at.desc())
    ).all()
    out = []
    for c in cases:
        mine = c.created_by_user_id == principal.user_id
        if can_view(roles=roles, is_creator=mine, reached_stage=c.reached_stage):
            out.append(case_out(CaseContext(case=c, village=village, roles=roles, is_creator=mine)))
    return out


@router.get("/cases/{case_id}", response_model=CaseOut)
def get_case(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> CaseOut:
    """A case with its state and the actions the caller may take now."""
    return case_out(load_case(db, principal, case_id))
