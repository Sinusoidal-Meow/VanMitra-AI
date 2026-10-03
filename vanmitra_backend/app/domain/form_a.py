"""
Form A: Claim Form for Rights to Forest Land [Rule 11(1)(a)] (Annexure I, Form A;
FRARulesBook_Highlighted.pdf printed pages 27-28; 1mitra.md §6.1).

  1  Name of the claimant(s)            form_a.claimant_names
  2  Name of the spouse                 form_a.spouse_name
  3  Name of father/mother              form_a.father_mother_name
  4  Address                            form_a.address
  5-8 Village, GP, Tehsil, District     village registry
  9  (a) ST yes/no (b) OTFD yes/no;     is_scheduled_tribe, is_otfd,
     spouse ST (attach certificate)     spouse_is_scheduled_tribe
  10 Other family members with age      form_a_family_member
  Nature of claim on land 1-7           FORM_A_CLAIMS below → form_a_claim
  8  Evidence in support (Rule 13)      claim_evidence_entry
  9  Any other information              form_a.other_information
  -- Signature / thumb impression       on the printed form

Completeness is ADVISORY: it never blocks saving or submitting, and is never a score.
"""

from collections.abc import Iterable, Sequence
from dataclasses import dataclass

from ..models.enums import EvidenceRule, FormAClaim
from .form_b import Completeness, CompletenessItem


@dataclass(frozen=True)
class ClaimSpec:
    code: FormAClaim
    form_item: str
    label_en: str
    section: str
    has_extent: bool  # whether an area (ha) is asked for


FORM_A_CLAIMS: tuple[ClaimSpec, ...] = (
    ClaimSpec(FormAClaim.HABITATION, "1(a)", "Extent of forest land occupied: for habitation",
              "Section 3(1)(a)", True),
    ClaimSpec(FormAClaim.SELF_CULTIVATION, "1(b)",
              "Extent of forest land occupied: for self-cultivation, if any",
              "Section 3(1)(a)", True),
    ClaimSpec(FormAClaim.DISPUTED_LAND, "2", "Disputed lands, if any", "Section 3(1)(f)", True),
    ClaimSpec(FormAClaim.PATTA_LEASE_GRANT, "3", "Pattas / leases / grants, if any",
              "Section 3(1)(g)", True),
    ClaimSpec(FormAClaim.IN_SITU_REHABILITATION, "4",
              "Land for in situ rehabilitation or alternative land, if any",
              "Section 3(1)(m)", True),
    ClaimSpec(FormAClaim.DISPLACED_WITHOUT_COMPENSATION, "5",
              "Land from where displaced without land compensation", "Section 4(8)", True),
    ClaimSpec(FormAClaim.FOREST_VILLAGE, "6", "Extent of land in forest villages, if any",
              "Section 3(1)(h)", True),
    ClaimSpec(FormAClaim.OTHER_TRADITIONAL, "7", "Any other traditional right, if any",
              "Section 3(1)(l)", False),
)  # fmt: skip

CLAIM_SPECS: dict[FormAClaim, ClaimSpec] = {c.code: c for c in FORM_A_CLAIMS}

MIN_EVIDENCE_ITEMS = 2  # Rule 11(1)(a)

# Sec 4(6): recognition of land under occupation is limited to the area under actual
# occupation and in no case exceeds 4 hectares. Shown as a note, never as a block.
MAX_RECOGNISABLE_HA = 4.0


def form_a_completeness(
    *,
    village_fields: Sequence[str | None],
    claimant_names: Sequence[str],
    address: str | None,
    is_scheduled_tribe: bool | None,
    is_otfd: bool | None,
    claimed: Iterable[FormAClaim],
    evidence_rules: Sequence[EvidenceRule],
) -> Completeness:
    return Completeness(
        (
            CompletenessItem("FA-1", bool(claimant_names), "1", "Rule 11(1)(a)",
                             "form_a.claimant_names_missing"),
            CompletenessItem("FA-2", bool(address and address.strip()), "4", "Rule 11(1)(a)",
                             "form_a.address_missing"),
            CompletenessItem("FA-3", all(bool(f and f.strip()) for f in village_fields), "5-8",
                             "Rule 11(1)(a)", "form_a.village_details_incomplete"),
            CompletenessItem("FA-4", is_scheduled_tribe is not None and is_otfd is not None,
                             "9", "Rule 11(1)(a)", "form_a.status_unanswered"),
            CompletenessItem("FA-5", any(True for _ in claimed), "Nature of claim 1-7",
                             "Section 3(1)", "form_a.no_claim_described"),
            CompletenessItem("FA-6", len(evidence_rules) >= MIN_EVIDENCE_ITEMS, "8",
                             "Rule 11(1)(a), Rule 13(3)", "form_a.fewer_than_two_evidences"),
        )
    )  # fmt: skip
