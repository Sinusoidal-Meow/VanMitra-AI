"""The Form A draft (Individual Forest Rights claim) [Rule 11(1)(a)]."""

import uuid
from decimal import Decimal

from fastapi import APIRouter

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession
from ...domain.form_a import CLAIM_SPECS, FORM_A_CLAIMS, MAX_RECOGNISABLE_HA, form_a_completeness
from ...models import ClaimEvidenceEntry, ClaimType, FormAClaimItem, FormAFamilyMember
from ...schemas.form_a import ClaimItemOut, FamilyMemberOut, FormAInput, FormAOut
from ...schemas.form_b import EvidenceOut
from ...services.cases import CaseContext, ensure_claim_type, ensure_editable, load_case
from ._shared import completeness_out, village_header

router = APIRouter(tags=["form-a"])


def _ha(value: Decimal | None) -> float | None:
    return float(value) if value is not None else None


def form_a_out(ctx: CaseContext) -> FormAOut:
    case, village = ctx.case, ctx.village
    form = case.form_a
    assert form is not None
    claimed = {c.claim_code: c for c in form.claims}
    evidence = sorted(case.evidence_entries, key=lambda e: e.seq)
    total = round(sum(float(c.extent_ha or 0) for c in form.claims), 2)
    completeness = form_a_completeness(
        village_fields=(village.name_mr, village.gram_panchayat, village.taluka, village.district),
        claimant_names=form.claimant_names,
        address=form.address,
        is_scheduled_tribe=form.is_scheduled_tribe,
        is_otfd=form.is_otfd,
        claimed=claimed.keys(),
        evidence_rules=[e.rule_ref for e in evidence],
    )
    return FormAOut(
        case_id=case.id,
        state=case.state,
        editable=ctx.editable,
        header=village_header(village),
        claimant_names=list(form.claimant_names),
        spouse_name=form.spouse_name,
        father_mother_name=form.father_mother_name,
        address=form.address,
        is_scheduled_tribe=form.is_scheduled_tribe,
        is_otfd=form.is_otfd,
        spouse_is_scheduled_tribe=form.spouse_is_scheduled_tribe,
        family_members=[
            FamilyMemberOut(seq=m.seq, name=m.name, age=m.age, relation=m.relation)
            for m in sorted(form.family_members, key=lambda m: m.seq)
        ],
        claims=[
            ClaimItemOut(
                code=spec.code,
                form_item=spec.form_item,
                label_en=spec.label_en,
                section=spec.section,
                claimed=spec.code in claimed,
                extent_ha=_ha(claimed[spec.code].extent_ha) if spec.code in claimed else None,
                details=claimed[spec.code].details if spec.code in claimed else None,
            )
            for spec in FORM_A_CLAIMS
        ],
        total_extent_ha=total,
        extent_note=(
            f"Recognition is limited to land under actual occupation and cannot exceed "
            f"{MAX_RECOGNISABLE_HA:g} ha [Section 4(6)]."
            if total > MAX_RECOGNISABLE_HA
            else None
        ),
        evidence=[
            EvidenceOut(seq=e.seq, rule_ref=e.rule_ref, description=e.description) for e in evidence
        ],
        other_information=form.other_information,
        completeness=completeness_out(completeness),
        updated_at=form.updated_at,
    )


@router.get("/cases/{case_id}/form-a", response_model=FormAOut)
def get_form_a(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> FormAOut:
    """The Form A draft, with items 5-8 from the registry and documentation completeness."""
    ctx = load_case(db, principal, case_id)
    ensure_claim_type(ctx, ClaimType.IFR, "NOT_A_FORM_A_CASE")
    return form_a_out(ctx)


@router.put("/cases/{case_id}/form-a", response_model=FormAOut)
def put_form_a(
    case_id: uuid.UUID,
    body: FormAInput,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> FormAOut:
    """Replace the Form A draft. Only the claimant, only while the case is a draft."""
    ctx = load_case(db, principal, case_id)
    ensure_claim_type(ctx, ClaimType.IFR, "NOT_A_FORM_A_CASE")
    ensure_editable(ctx)
    case = ctx.case
    form = case.form_a
    assert form is not None

    form.claimant_names = list(body.claimant_names)
    form.spouse_name = body.spouse_name
    form.father_mother_name = body.father_mother_name
    form.address = body.address
    form.is_scheduled_tribe = body.is_scheduled_tribe
    form.is_otfd = body.is_otfd
    form.spouse_is_scheduled_tribe = body.spouse_is_scheduled_tribe
    form.other_information = body.other_information
    form.updated_by_user_id = user.id

    form.family_members = [
        FormAFamilyMember(seq=i, name=m.name, age=m.age, relation=m.relation)
        for i, m in enumerate(body.family_members, start=1)
    ]
    order = list(CLAIM_SPECS)
    form.claims = [
        FormAClaimItem(
            claim_code=code,
            extent_ha=Decimal(str(round(c.extent_ha, 2))) if c.extent_ha is not None else None,
            details=c.details,
        )
        for code, c in sorted(body.claims.items(), key=lambda kv: order.index(kv[0]))
    ]
    case.evidence_entries = [
        ClaimEvidenceEntry(seq=i, rule_ref=e.rule_ref, description=e.description)
        for i, e in enumerate(body.evidence, start=1)
    ]
    db.commit()
    return form_a_out(ctx)
