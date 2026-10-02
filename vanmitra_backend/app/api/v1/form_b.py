"""The Form B draft (Community Rights claim) [Rule 11(1)(a) and (4)]."""

import uuid

from fastapi import APIRouter

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession
from ...domain.form_b import FORM_B_RIGHTS, MIN_EVIDENCE_ITEMS, RIGHT_SPECS, form_b_completeness
from ...models import ClaimEvidenceEntry, ClaimType, EvidenceRule, FormBRightClaim
from ...schemas.form_b import (
    EvidenceOut,
    FormBFieldOut,
    FormBFieldsOut,
    FormBInput,
    FormBOut,
    RightOut,
)
from ...services.cases import CaseContext, ensure_claim_type, ensure_editable, load_case
from ._shared import completeness_out, village_header

router = APIRouter(tags=["form-b"])


def form_b_out(ctx: CaseContext) -> FormBOut:
    case, village = ctx.case, ctx.village
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
        editable=ctx.editable,
        header=village_header(village),
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
        completeness=completeness_out(completeness),
        updated_at=form.updated_at,
    )


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


@router.get("/cases/{case_id}/form-b", response_model=FormBOut)
def get_form_b(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> FormBOut:
    """The Form B draft, with items 2-5 from the registry and documentation completeness."""
    ctx = load_case(db, principal, case_id)
    ensure_claim_type(ctx, ClaimType.CR, "NOT_A_FORM_B_CASE")
    return form_b_out(ctx)


@router.put("/cases/{case_id}/form-b", response_model=FormBOut)
def put_form_b(
    case_id: uuid.UUID,
    body: FormBInput,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> FormBOut:
    """Replace the Form B draft. Only the claimant, only while the case is a draft."""
    ctx = load_case(db, principal, case_id)
    ensure_claim_type(ctx, ClaimType.CR, "NOT_A_FORM_B_CASE")
    ensure_editable(ctx)
    case = ctx.case
    form = case.form_b
    assert form is not None

    form.claimant_names = list(body.claimant_names)
    form.is_fdst_community = body.is_fdst_community
    form.is_otfd_community = body.is_otfd_community
    form.other_information = body.other_information
    form.updated_by_user_id = user.id

    # Replace child rows. Flush the deletes first: within one flush SQLAlchemy inserts
    # before it deletes, which would trip the unique (case_id, right_code) / (case_id, seq).
    form.rights.clear()
    case.evidence_entries.clear()
    db.flush()
    order = list(RIGHT_SPECS)
    form.rights.extend(
        FormBRightClaim(right_code=code, details=r.details, items=list(r.items))
        for code, r in sorted(body.rights.items(), key=lambda kv: order.index(kv[0]))
    )
    case.evidence_entries.extend(
        ClaimEvidenceEntry(seq=i, rule_ref=e.rule_ref, description=e.description)
        for i, e in enumerate(body.evidence, start=1)
    )
    db.commit()
    db.refresh(case)
    db.refresh(form)
    return form_b_out(ctx)
