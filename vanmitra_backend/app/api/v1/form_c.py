"""
The Form C draft (Community Forest Resource claim) [Sec 3(1)(i); Rule 11(1), 11(4)].

Who may do what (PROJECT_PLAN §3):
- The FRC prepares Form C on behalf of the Gram Sabha [Rule 11(4)]; the NGO facilitator
  may help draft it (rule C5: drafts only). Both may edit drafts.
- Any role in the village may read it. The member sheet (item 5) comes from the roster
  kept by the Gram Sabha Secretary.
"""

import uuid
from decimal import Decimal

from fastapi import APIRouter
from sqlalchemy import select

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession
from ...auth.principal import Principal
from ...domain.form_c import (
    DEFAULT_RESOLUTION_STATEMENT,
    MIN_CFR_EVIDENCE,
    MIN_GENERAL_EVIDENCE,
    form_c_completeness,
    member_sheet_counts,
)
from ...errors import ApiError
from ...models import (
    BoundarySide,
    CaseState,
    ClaimCase,
    ClaimEvidenceEntry,
    ClaimType,
    EvidenceRule,
    FormCBorderingVillage,
    FormCLandmark,
    GsMember,
    LandmarkKind,
    Role,
    Village,
)
from ...schemas.form_b import CompletenessItemOut, CompletenessOut, EvidenceOut, VillageHeader
from ...schemas.form_c import (
    BorderingVillageOut,
    FormCFieldsOut,
    FormCInput,
    FormCOut,
    LandmarkOut,
    MemberSheetOut,
    MemberSheetRow,
)
from ...services.cases import load_case

router = APIRouter(tags=["form-c"])

FORM_C_EDITORS = (Role.FACILITATOR, Role.FRC_MEMBER)


def _load_form_c_case(
    db: DbSession, principal: Principal, case_id: uuid.UUID, roles: tuple[Role, ...] | None
) -> tuple[ClaimCase, Village]:
    case, village = load_case(db, principal, case_id, roles)
    if case.claim_type != ClaimType.CFR or case.form_c is None:
        raise ApiError(409, "NOT_A_FORM_C_CASE", "case.not_form_c", {"claim_type": case.claim_type})
    return case, village


def _form_c_out(db: DbSession, case: ClaimCase, village: Village) -> FormCOut:
    form = case.form_c
    assert form is not None
    members = db.scalars(
        select(GsMember)
        .where(GsMember.gram_sabha_id == case.gram_sabha_id, GsMember.active.is_(True))
        .order_by(GsMember.name)
    ).all()
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
        editable=case.state == CaseState.DRAFT,
        header=VillageHeader(
            village_id=village.id,
            village_name_mr=village.name_mr,
            village_name_en=village.name_en,
            gram_panchayat=village.gram_panchayat,
            taluka=village.taluka,
            district=village.district,
        ),
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
        completeness=CompletenessOut(
            done=completeness.done,
            total=completeness.total,
            items=[
                CompletenessItemOut(
                    id=i.id, ok=i.ok, form_item=i.form_item, rule=i.rule, message_key=i.message_key
                )
                for i in completeness.items
            ],
        ),
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
    case, village = _load_form_c_case(db, principal, case_id, None)
    return _form_c_out(db, case, village)


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
    case, village = _load_form_c_case(db, principal, case_id, FORM_C_EDITORS)
    if case.state != CaseState.DRAFT:
        raise ApiError(409, "CASE_NOT_EDITABLE", "case.not_editable", {"state": case.state})
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

    # Child rows are replaced wholesale. Flush the deletes first: within one flush
    # SQLAlchemy inserts before it deletes, which would trip the unique (case_id, seq).
    form.landmarks.clear()
    form.bordering_villages.clear()
    case.evidence_entries.clear()
    db.flush()
    form.landmarks.extend(
        FormCLandmark(seq=i, side=lm.side, kind=lm.kind, name=lm.name, description=lm.description)
        for i, lm in enumerate(body.landmarks, start=1)
    )
    form.bordering_villages.extend(
        FormCBorderingVillage(
            seq=i,
            name=b.name,
            shares_resources=b.shares_resources,
            sharing_details=b.sharing_details,
        )
        for i, b in enumerate(body.bordering_villages, start=1)
    )
    case.evidence_entries.extend(
        ClaimEvidenceEntry(seq=i, rule_ref=e.rule_ref, description=e.description)
        for i, e in enumerate(body.evidence, start=1)
    )
    db.commit()
    db.refresh(case)
    db.refresh(form)
    return _form_c_out(db, case, village)
