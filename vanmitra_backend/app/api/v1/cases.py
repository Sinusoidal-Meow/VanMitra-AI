"""
Claim cases and the Form B draft (community rights). Form C lives in form_c.py.

Who may do what (PROJECT_PLAN §3):
- Form B is prepared by the FRC on behalf of the Gram Sabha [Rule 11(4)]; the NGO
  facilitator may help draft it (rule R5: drafts only). Both may create and edit drafts.
- The Gram Sabha Secretary, and any role in the village, may read it.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy import select

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession, require_village_role
from ...auth.principal import Principal
from ...domain.form_b import FORM_B_RIGHTS, MIN_EVIDENCE_ITEMS, RIGHT_SPECS, form_b_completeness
from ...domain.form_c import DEFAULT_RESOLUTION_STATEMENT
from ...errors import ApiError
from ...models import (
    CaseState,
    ClaimCase,
    ClaimEvidenceEntry,
    ClaimType,
    EvidenceRule,
    FormB,
    FormBRightClaim,
    FormC,
    GramSabha,
    Role,
    Village,
)
from ...schemas.form_b import (
    CaseCreate,
    CaseOut,
    CompletenessItemOut,
    CompletenessOut,
    EvidenceOut,
    FormBFieldOut,
    FormBFieldsOut,
    FormBInput,
    FormBOut,
    RightOut,
    VillageHeader,
)
from ...services.cases import load_case

router = APIRouter(tags=["cases", "form-b"])

FORM_B_EDITORS = (Role.FACILITATOR, Role.FRC_MEMBER)

# Claim types whose forms the API can take so far: Form B (CR) and Form C (CFR). Form A later.
AVAILABLE_CLAIM_TYPES = {ClaimType.CR, ClaimType.CFR}


def _case_out(case: ClaimCase, village_id: uuid.UUID) -> CaseOut:
    return CaseOut(
        id=case.id,
        village_id=village_id,
        gram_sabha_id=case.gram_sabha_id,
        claim_type=case.claim_type,
        state=case.state,
        created_at=case.created_at,
        updated_at=case.updated_at,
    )


def _form_b_out(case: ClaimCase, village: Village) -> FormBOut:
    form = case.form_b
    assert form is not None
    claimed = {r.right_code: r for r in form.rights}
    evidence = sorted(case.evidence_entries, key=lambda e: e.seq)
    completeness = form_b_completeness(
        village_fields=(village.name_mr, village.gram_panchayat, village.taluka, village.district),
        claimant_names=form.claimant_names,
        is_fdst_community=form.is_fdst_community,
        is_otfd_community=form.is_otfd_community,
        claimed_rights=claimed.keys(),
        evidence_rules=[e.rule_ref for e in evidence],
    )
    return FormBOut(
        case_id=case.id,
        state=case.state,
        editable=case.state == CaseState.DRAFT,
        header=VillageHeader(
            village_id=village.id,
            village_name_mr=village.name_mr,
            village_name_en=village.name_en,
            gram_panchayat=village.gram_panchayat,
            taluka=village.taluka,
            district=village.district,
        ),
        claimant_names=list(form.claimant_names),
        is_fdst_community=form.is_fdst_community,
        is_otfd_community=form.is_otfd_community,
        rights=[
            RightOut(
                code=spec.code,
                form_item=spec.form_item,
                label_en=spec.label_en,
                section=spec.section,
                claimed=spec.code in claimed,
                details=claimed[spec.code].details if spec.code in claimed else None,
                items=list(claimed[spec.code].items) if spec.code in claimed else [],
            )
            for spec in FORM_B_RIGHTS
        ],
        evidence=[
            EvidenceOut(seq=e.seq, rule_ref=e.rule_ref, description=e.description) for e in evidence
        ],
        other_information=form.other_information,
        completeness=CompletenessOut(
            done=completeness.done,
            total=completeness.total,
            items=[
                CompletenessItemOut(
                    id=i.id,
                    ok=i.ok,
                    form_item=i.form_item,
                    rule=i.rule,
                    message_key=i.message_key,
                )
                for i in completeness.items
            ],
        ),
        updated_at=form.updated_at,
    )


# ── Form B description (static) ───────────────────────────────────────────────


@router.get("/forms/form-b/fields", response_model=FormBFieldsOut)
def form_b_fields(_: CurrentUser) -> FormBFieldsOut:
    """Form B's rights (items 1-6) with their provisions, and the Rule 13 evidence tags."""
    return FormBFieldsOut(
        form="Form B: Claim Form for Community Rights",
        rule="Rule 11(1)(a) and (4)",
        rights=[
            FormBFieldOut(
                code=s.code, form_item=s.form_item, label_en=s.label_en, section=s.section
            )
            for s in FORM_B_RIGHTS
        ],
        evidence_rules=list(EvidenceRule),
        min_evidence_items=MIN_EVIDENCE_ITEMS,
    )


# ── Cases in a village ────────────────────────────────────────────────────────


@router.post(
    "/villages/{village_id}/cases",
    response_model=CaseOut,
    status_code=status.HTTP_201_CREATED,
)
def create_case(
    village_id: uuid.UUID,
    body: CaseCreate,
    db: DbSession,
    user: CurrentUser,
    _: Annotated[Principal, Depends(require_village_role(*FORM_B_EDITORS))],
) -> CaseOut:
    """Open a claim case for the village's Gram Sabha: `cr` → empty Form B, `cfr` → empty Form C."""
    if body.claim_type not in AVAILABLE_CLAIM_TYPES:
        raise ApiError(
            422,
            "CLAIM_TYPE_NOT_AVAILABLE",
            "case.claim_type_not_available",
            {"claim_type": body.claim_type, "available": sorted(AVAILABLE_CLAIM_TYPES)},
        )
    gram_sabha = db.scalar(select(GramSabha).where(GramSabha.village_id == village_id))
    if gram_sabha is None:
        raise ApiError(409, "GRAM_SABHA_MISSING", "village.gram_sabha_missing")
    case = ClaimCase(
        gram_sabha_id=gram_sabha.id,
        claim_type=body.claim_type,
        state=CaseState.DRAFT,
        created_by_user_id=user.id,
    )
    if body.claim_type == ClaimType.CR:
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
    return _case_out(case, village_id)


@router.get("/villages/{village_id}/cases", response_model=list[CaseOut])
def list_cases(
    village_id: uuid.UUID,
    db: DbSession,
    _: Annotated[Principal, Depends(require_village_role())],
) -> list[CaseOut]:
    cases = db.scalars(
        select(ClaimCase)
        .join(GramSabha, GramSabha.id == ClaimCase.gram_sabha_id)
        .where(GramSabha.village_id == village_id)
        .order_by(ClaimCase.created_at.desc())
    ).all()
    return [_case_out(c, village_id) for c in cases]


# ── Form B draft ──────────────────────────────────────────────────────────────


def _load_form_b_case(
    db: DbSession, principal: Principal, case_id: uuid.UUID, roles: tuple[Role, ...] | None
) -> tuple[ClaimCase, Village]:
    case, village = load_case(db, principal, case_id, roles)
    if case.claim_type != ClaimType.CR or case.form_b is None:
        raise ApiError(409, "NOT_A_FORM_B_CASE", "case.not_form_b", {"claim_type": case.claim_type})
    return case, village


@router.get("/cases/{case_id}/form-b", response_model=FormBOut)
def get_form_b(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> FormBOut:
    """The Form B draft, with items 2-5 from the registry and documentation completeness."""
    case, village = _load_form_b_case(db, principal, case_id, None)
    return _form_b_out(case, village)


@router.put("/cases/{case_id}/form-b", response_model=FormBOut)
def put_form_b(
    case_id: uuid.UUID,
    body: FormBInput,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> FormBOut:
    """
    Replace the Form B draft. Allowed only while the case is a DRAFT; after that the
    form is part of the signed record and changes need a superseding record (BR-15).
    """
    case, village = _load_form_b_case(db, principal, case_id, FORM_B_EDITORS)
    if case.state != CaseState.DRAFT:
        raise ApiError(409, "CASE_NOT_EDITABLE", "case.not_editable", {"state": case.state})
    form = case.form_b
    assert form is not None

    form.claimant_names = list(body.claimant_names)
    form.is_fdst_community = body.is_fdst_community
    form.is_otfd_community = body.is_otfd_community
    form.other_information = body.other_information
    form.updated_by_user_id = user.id

    # Rights and evidence are replaced wholesale. Flush the deletes first: within one
    # flush SQLAlchemy inserts before it deletes, which would trip the unique
    # (case_id, right_code) and (case_id, seq) constraints on a re-submitted item.
    form.rights.clear()
    case.evidence_entries.clear()
    db.flush()
    form.rights.extend(
        FormBRightClaim(right_code=code, details=r.details, items=list(r.items))
        for code, r in sorted(body.rights.items(), key=lambda kv: list(RIGHT_SPECS).index(kv[0]))
    )
    case.evidence_entries.extend(
        ClaimEvidenceEntry(seq=i, rule_ref=e.rule_ref, description=e.description)
        for i, e in enumerate(body.evidence, start=1)
    )
    db.commit()
    db.refresh(case)
    db.refresh(form)
    return _form_b_out(case, village)
