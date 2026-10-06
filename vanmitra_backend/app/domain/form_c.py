"""
Form C: Claim Form for Rights to Community Forest Resource
[Section 3(1)(i) of the Act; Rule 11(1) and (4)], inserted by the 2012 Amendment.
Source: FRA Rules, Annexure I, Form C (FRARulesBook_Highlighted.pdf, printed page 30);
1mitra.md §6.3.

Form C fields → where they live:
  1-4  Village/Gram Sabha, Gram Panchayat, Tehsil/Taluka, District   village registry
  5    Names of Gram Sabha members, ST/OTFD status against each        gs_member roster
       ("presence of few ST/OTFD is sufficient to make the claim")
  5a   Resolving statement                                            form_c.resolution_statement
  5b   Map of the CFR: location and landmarks within the customary   form_c.area_description,
       boundary, or seasonal use of landscape (pastoral); need not    landmarks (four boundaries),
       match legal boundaries                                         pastoral_seasonal_use
  6    Khasra/Compartment No.(s), if any and if known                 khasra_compartment_numbers
  7    Bordering villages, incl. sharing of resources                 form_c_bordering_village
  8    List of evidence in support (Rule 13)                          claim_evidence_entry
  --   Signature/Thumb impression of the claimant(s)                  on the printed form (rule R4)

Completeness is ADVISORY (rule C2, BR-05): it never blocks saving and is never a score.
"""

from collections.abc import Iterable, Sequence
from dataclasses import dataclass

from ..models.enums import BoundarySide, EvidenceRule, MemberCategory
from .form_b import Completeness, CompletenessItem

# Item 5a, as printed on Form C. The FRC may edit it or replace it with the Marathi text.
DEFAULT_RESOLUTION_STATEMENT = (
    "We, the undersigned residents of this Gram Sabha hereby resolve that the area detailed "
    "below and in the attached map comprises our Community Forest Resource over which we are "
    "claiming recognition of our forest rights under Section 3(1)(i)."
)

FOUR_SIDES: tuple[BoundarySide, ...] = (
    BoundarySide.EAST,
    BoundarySide.WEST,
    BoundarySide.NORTH,
    BoundarySide.SOUTH,
)

# Rule 11(1)(a): at least two evidences; a CFR claim also needs Rule 13(2) evidence (Spec §4.3).
MIN_GENERAL_EVIDENCE = 2
MIN_CFR_EVIDENCE = 1


@dataclass(frozen=True)
class MemberSheetCounts:
    total: int
    st: int
    otfd: int


def member_sheet_counts(categories: Iterable[MemberCategory]) -> MemberSheetCounts:
    cats = list(categories)
    return MemberSheetCounts(
        total=len(cats),
        st=sum(1 for c in cats if c == MemberCategory.ST),
        otfd=sum(1 for c in cats if c == MemberCategory.OTFD),
    )


def form_c_completeness(
    *,
    village_fields: Sequence[str | None],
    members: MemberSheetCounts,
    resolution_statement: str | None,
    area_description: str | None,
    landmark_sides: Iterable[BoundarySide],
    bordering_village_count: int,
    evidence_rules: Sequence[EvidenceRule],
) -> Completeness:
    """
    Documentation completeness for a Form C draft. Advisory: it says nothing about
    eligibility and blocks nothing. Item 6 (khasra) is optional by design and not checked.
    """
    sides = set(landmark_sides)
    general = sum(1 for r in evidence_rules if r.is_general)
    cfr = sum(1 for r in evidence_rules if not r.is_general)
    return Completeness(
        (
            CompletenessItem(
                "FC-1",
                all(bool(f and f.strip()) for f in village_fields),
                "1-4",
                "Rule 11(1)",
                "form_c.village_details_incomplete",
            ),
            CompletenessItem(
                "FC-2",
                members.total > 0 and (members.st + members.otfd) > 0,
                "5",
                "Form C item 5",
                "form_c.member_sheet_missing_st_otfd",
            ),
            CompletenessItem(
                "FC-3",
                bool(resolution_statement and resolution_statement.strip()),
                "5a",
                "Section 3(1)(i)",
                "form_c.resolution_statement_missing",
            ),
            CompletenessItem(
                "FC-4",
                bool(area_description and area_description.strip()),
                "5b",
                "Rule 12(1)(g)",
                "form_c.area_not_described",
            ),
            CompletenessItem(
                "FC-5",
                all(s in sides for s in FOUR_SIDES),
                "5b",
                "Rule 12(1)(g)",
                "form_c.boundary_landmarks_missing",
            ),
            CompletenessItem(
                "FC-6",
                bordering_village_count > 0,
                "7",
                "Rule 11(1)(b)",
                "form_c.no_bordering_village",
            ),
            CompletenessItem(
                "FC-7",
                general >= MIN_GENERAL_EVIDENCE,
                "8",
                "Rule 11(1)(a), Rule 13(3)",
                "form_c.fewer_than_two_general_evidences",
            ),
            CompletenessItem(
                "FC-8",
                cfr >= MIN_CFR_EVIDENCE,
                "8",
                "Rule 13(2)",
                "form_c.no_cfr_evidence",
            ),
        )
    )
