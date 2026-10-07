"""
The Form C draft (Community Forest Resource claim) [Sec 3(1)(i); Rule 11(1), 11(4)].

Prepared and filed by the Gram Sabha (services.cases.CREATORS); only the claimant edits,
only while the case is a draft. Anyone who may see the case may read it. The member
sheet (item 5) comes from the roster kept by the Gram Sabha.
"""

import uuid
from decimal import Decimal

from fastapi import APIRouter

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession
from ...domain.form_c import (
    DEFAULT_RESOLUTION_STATEMENT,
    MIN_CFR_EVIDENCE,
    MIN_GENERAL_EVIDENCE,
    form_c_completeness,
    member_sheet_counts,
)
from ...models import (
    BoundarySide,
    ClaimEvidenceEntry,
    ClaimType,
    EvidenceRule,
    FormCBorderingVillage,
    FormCLandmark,
    GsMember,
    LandmarkKind,
)
from ...schemas.form_b import EvidenceOut
from ...schemas.form_c import (
    BorderingVillageOut,
    FormCFieldsOut,
    FormCInput,
    FormCOut,
    LandmarkOut,
    MemberSheetOut,
    MemberSheetRow,
)
from ...services.cases import CaseContext, ensure_claim_type, ensure_editable, load_case
from ._shared import completeness_out, village_header

router = APIRouter(tags=["form-c"])


def _form_c_out(db: DbSession, ctx: CaseContext) -> FormCOut:
    case, village = ctx.case, ctx.village
    form = case.form_c
    assert form is not None
    members = db.find(
        GsMember,
        {"gram_sabha_id": case.gram_sabha_id, "active": True},
        sort=[("name", 1)],
    )
    counts = member_sheet_counts(m.category for m in members)
    evidence = sorted(case.evidence_entries, key=lambda e: e.seq)
    landmarks = sorted(form.landmarks, key=lambda lm: lm.seq)
    bordering = sorted(form.bordering_villages, key=lambda b: b.seq)
    completeness = form_c_completeness(
        village_fields=(village.name_mr, village.gram_panchayat, village.taluka, village.district),
        members=counts,
        resolution_statement=form.resolution_statement,
        area_description=form.area_description,
        landmark_sides=(lm.side for lm in landmarks),
        bordering_village_count=len(bordering),
        evidence_rules=[e.rule_ref for e in evidence],
    )
    return FormCOut(
        case_id=case.id,
        state=case.state,
        editable=ctx.editable,
        header=village_header(village),
        member_sheet=MemberSheetOut(
            total=counts.total,
            st=counts.st,
            otfd=counts.otfd,
            members=[MemberSheetRow(name=m.name, category=m.category) for m in members],
        ),
        resolution_statement=form.resolution_statement,
        area_description=form.area_description,
        approx_area_ha=float(form.approx_area_ha) if form.approx_area_ha is not None else None,
        pastoral_seasonal_use=form.pastoral_seasonal_use,
        seasonal_use_details=form.seasonal_use_details,
        landmarks=[
            LandmarkOut(
                seq=lm.seq, side=lm.side, kind=lm.kind, name=lm.name, description=lm.description
            )
            for lm in landmarks
        ],
        khasra_compartment_numbers=list(form.khasra_compartment_numbers),
        bordering_villages=[
            BorderingVillageOut(
                seq=b.seq,
                name=b.name,
                shares_resources=b.shares_resources,
                sharing_details=b.sharing_details,
            )
            for b in bordering
        ],
        evidence=[
            EvidenceOut(seq=e.seq, rule_ref=e.rule_ref, description=e.description) for e in evidence
        ],
        completeness=completeness_out(completeness),
        updated_at=form.updated_at,
    )


@router.get("/forms/form-c/fields", response_model=FormCFieldsOut)
def form_c_fields(_: CurrentUser) -> FormCFieldsOut:
    """Form C vocabularies: boundary sides, landmark kinds, Rule 13 tags, default statement."""
    return FormCFieldsOut(
        form="Form C: Claim Form for Rights to Community Forest Resource",
        rule="Section 3(1)(i); Rule 11(1) and (4)",
        default_resolution_statement=DEFAULT_RESOLUTION_STATEMENT,
        boundary_sides=list(BoundarySide),
        landmark_kinds=list(LandmarkKind),
        evidence_rules=list(EvidenceRule),
        min_general_evidence=MIN_GENERAL_EVIDENCE,
        min_cfr_evidence=MIN_CFR_EVIDENCE,
    )


@router.get("/cases/{case_id}/form-c", response_model=FormCOut)
def get_form_c(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> FormCOut:
    """The Form C draft: items 1-4 from the registry, item 5 from the roster, completeness."""
    ctx = load_case(db, principal, case_id)
    ensure_claim_type(ctx, ClaimType.CFR, "NOT_A_FORM_C_CASE")
    return _form_c_out(db, ctx)


@router.put("/cases/{case_id}/form-c", response_model=FormCOut)
def put_form_c(
    case_id: uuid.UUID,
    body: FormCInput,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> FormCOut:
    """
    Replace the Form C draft. Allowed only while the case is a DRAFT; after that the form
    is part of the signed record and changes need a superseding record (BR-15).
    """
    ctx = load_case(db, principal, case_id)
    ensure_claim_type(ctx, ClaimType.CFR, "NOT_A_FORM_C_CASE")
    ensure_editable(ctx)
    case = ctx.case
    form = case.form_c
    assert form is not None

    form.resolution_statement = body.resolution_statement or DEFAULT_RESOLUTION_STATEMENT
    form.area_description = body.area_description
    form.approx_area_ha = (
        Decimal(str(round(body.approx_area_ha, 2))) if body.approx_area_ha is not None else None
    )
    form.pastoral_seasonal_use = body.pastoral_seasonal_use
    form.seasonal_use_details = body.seasonal_use_details
    form.khasra_compartment_numbers = list(dict.fromkeys(body.khasra_compartment_numbers))
    form.updated_by_user_id = user.id

    form.landmarks = [
        FormCLandmark(seq=i, side=lm.side, kind=lm.kind, name=lm.name, description=lm.description)
        for i, lm in enumerate(body.landmarks, start=1)
    ]
    form.bordering_villages = [
        FormCBorderingVillage(
            seq=i,
            name=b.name,
            shares_resources=b.shares_resources,
            sharing_details=b.sharing_details,
        )
        for i, b in enumerate(body.bordering_villages, start=1)
    ]
    case.evidence_entries = [
        ClaimEvidenceEntry(seq=i, rule_ref=e.rule_ref, description=e.description)
        for i, e in enumerate(body.evidence, start=1)
    ]
    db.commit()
    return _form_c_out(db, ctx)
