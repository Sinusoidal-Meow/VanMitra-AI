"""
Title drafts [Rule 8(h), 8(i)]: Annexure II (Form A), III (Form B), IV (Form C).
Field order follows the printed annexures (1mitra.md §6.4). Signed by three district
officers: DFO/DCF, District Tribal Welfare Officer, Collector/DC.
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..domain.form_a import CLAIM_SPECS
from ..domain.form_b import RIGHT_SPECS
from ..domain.form_c import member_sheet_counts
from ..models import (
    BoundarySide,
    CaseState,
    ClaimType,
    GsMember,
    Role,
)
from ..schemas.cases import SignatoryOut, TitleDraftOut
from .cases import CaseContext, district_signatories

SIGNATORIES: tuple[tuple[Role, str], ...] = (
    (Role.DFO, "Divisional Forest Officer / Deputy Conservator of Forests"),
    (Role.TRIBAL_WELFARE_OFFICER, "District Tribal Welfare Officer"),
    (Role.COLLECTOR, "District Collector / Deputy Commissioner"),
)

NOTE = (
    "Title draft prepared with VanMitra for printing and signature. The signed paper is the "
    "title; this draft is not a government document until signed."
)


def _status(yes: bool | None, no_label: str = "No") -> str:
    return "Yes" if yes else (no_label if yes is False else "Not stated")


def _community(st: bool | None, otfd: bool | None) -> str:
    if st and otfd:
        return "Scheduled Tribe and Other Traditional Forest Dweller"
    if st:
        return "Scheduled Tribe"
    if otfd:
        return "Other Traditional Forest Dweller"
    return "Not stated"


def build_title_draft(db: Session, ctx: CaseContext) -> TitleDraftOut:
    case, village = ctx.case, ctx.village
    state_name = village.state or "Maharashtra"
    signed = district_signatories(case)
    signatories = [
        SignatoryOut(
            designation=label,
            role=role,
            name=signed[role].actor_name if role in signed else None,
            signed_at=signed[role].created_at if role in signed else None,
        )
        for role, label in SIGNATORIES
    ]
    issued = case.state is CaseState.TITLE_ISSUED
    status = "issued" if issued else "draft (awaiting district approval)"
    place = {
        "village_gram_sabha": f"{village.name_mr} ({village.name_en})",
        "gram_panchayat": village.gram_panchayat,
        "tehsil_taluka": village.taluka,
        "district": village.district,
    }

    if case.claim_type is ClaimType.IFR:
        form = case.form_a
        assert form is not None
        total = round(sum(float(c.extent_ha or 0) for c in form.claims), 2)
        holders = list(form.claimant_names) + ([form.spouse_name] if form.spouse_name else [])
        fields: dict[str, object] = {
            "1_holders_including_spouse": holders,
            "2_father_mother": form.father_mother_name,
            "3_dependents": [
                f"{m.name}" + (f" ({m.age})" if m.age is not None else "")
                for m in sorted(form.family_members, key=lambda m: m.seq)
            ],
            "4_address": form.address,
            "5_village_gram_sabha": place["village_gram_sabha"],
            "6_gram_panchayat": place["gram_panchayat"],
            "7_tehsil_taluka": place["tehsil_taluka"],
            "8_district": place["district"],
            "9_st_or_otfd": _community(form.is_scheduled_tribe, form.is_otfd),
            "10_area_ha": total,
            "11_boundaries": [
                f"{CLAIM_SPECS[c.claim_code].label_en}: {c.details}" for c in form.claims
            ],
        }
        return TitleDraftOut(
            case_id=case.id,
            annexure="Annexure II [Rule 8(h)]",
            title="Title for forest land under occupation",
            status=status,
            fields=fields,
            declaration=(
                "This title is heritable, but not alienable or transferable under sub-section "
                "(4) of Section 4 of the Act. We, the undersigned, hereby, for and on behalf of "
                f"the Government of {state_name} affix our signatures to confirm the above "
                "forest right."
            ),
            signatories=signatories,
            note=NOTE,
        )

    if case.claim_type is ClaimType.CR:
        form_b = case.form_b
        assert form_b is not None
        fields = {
            "1_holders": list(form_b.claimant_names),
            "2_village_gram_sabha": place["village_gram_sabha"],
            "3_gram_panchayat": place["gram_panchayat"],
            "4_tehsil_taluka": place["tehsil_taluka"],
            "5_district": place["district"],
            "6_st_or_otfd": _community(form_b.is_fdst_community, form_b.is_otfd_community),
            "7_nature_of_community_rights": [
                f"{RIGHT_SPECS[r.right_code].label_en} [{RIGHT_SPECS[r.right_code].section}]: "
                f"{r.details}"
                for r in form_b.rights
            ],
            "8_conditions": "None beyond those in the Act and the Rules",
            "9_boundaries": [
                {
                    "right": RIGHT_SPECS[r.right_code].label_en,
                    "survey_compartment_numbers": list(r.survey_compartment_numbers),
                    "area_ha": float(r.total_area_ha) if r.total_area_ha is not None else None,
                    "east": r.boundary_east,
                    "west": r.boundary_west,
                    "north": r.boundary_north,
                    "south": r.boundary_south,
                }
                for r in form_b.rights
                if r.survey_compartment_numbers
                or r.total_area_ha is not None
                or any((r.boundary_east, r.boundary_west, r.boundary_north, r.boundary_south))
            ]
            or "As described in the claim and the Gram Sabha resolution",
        }
        return TitleDraftOut(
            case_id=case.id,
            annexure="Annexure III [Rule 8(h)]",
            title="Title to community forest rights",
            status=status,
            fields=fields,
            declaration=(
                f"We, the undersigned, hereby, for and on behalf of the Government of {state_name} "
                "affix our signatures to confirm the forest right as mentioned in the Title to the "
                "above mentioned holders of community forest rights."
            ),
            signatories=signatories,
            note=NOTE,
        )

    form_c = case.form_c
    assert form_c is not None
    members = db.scalars(
        select(GsMember.category).where(
            GsMember.gram_sabha_id == case.gram_sabha_id, GsMember.active.is_(True)
        )
    ).all()
    counts = member_sheet_counts(members)
    by_side: dict[str, list[str]] = {}
    for lm in sorted(form_c.landmarks, key=lambda lm: lm.seq):
        by_side.setdefault(lm.side.value, []).append(lm.name)
    fields = {
        "1_village_gram_sabha": place["village_gram_sabha"],
        "2_gram_panchayat": place["gram_panchayat"],
        "3_tehsil_taluka": place["tehsil_taluka"],
        "4_district": place["district"],
        "5_st_otfd_or_both": _community(counts.st > 0, counts.otfd > 0),
        "6_boundary_description": {
            "customary_boundary": form_c.area_description,
            "prominent_landmarks": {
                side.value: by_side.get(side.value, [])
                for side in (
                    BoundarySide.EAST,
                    BoundarySide.WEST,
                    BoundarySide.NORTH,
                    BoundarySide.SOUTH,
                    BoundarySide.WITHIN,
                )
            },
            "khasra_compartment_numbers": list(form_c.khasra_compartment_numbers),
        },
    }
    return TitleDraftOut(
        case_id=case.id,
        annexure="Annexure IV [Rule 8(i)]",
        title="Title to Community Forest Resources",
        status=status,
        fields=fields,
        declaration=(
            "We, the undersigned, hereby, for and on behalf of the Government affix our "
            "signatures to confirm the community forest resource. The title is held by the "
            "Gram Sabha; no conditions are imposed beyond those in the Act and the Rules."
        ),
        signatories=signatories,
        note=NOTE,
    )
