"""
Form B: Claim Form for Community Rights [Rule 11(1)(a) and (4)].
Source: FRA Rules 2007 (as amended 2012), Annexure I, Form B
(FRARulesBook_Highlighted.pdf, printed page 29).

Form B fields → where they live:
  1   Name of the claimant(s)                  form_b.claimant_names
  1a  FDST community: Yes/No                   form_b.is_fdst_community
  1b  OTFD community: Yes/No                   form_b.is_otfd_community
  2-5 Village, Gram Panchayat, Tehsil/Taluka,  village registry (never free text)
      District
  Nature of community rights enjoyed: items 1-6 → FORM_B_RIGHTS below
  7   Evidence in support (Rule 13)            claim_evidence_entry
  8   Any other information                    form_b.other_information
  --  Signature/Thumb impression               on the printed form (rule R4); scan later

Completeness is ADVISORY only (PROJECT_PLAN rule R2, BR-05): it never blocks
saving and is never shown as a score.
"""

from collections.abc import Iterable, Sequence
from dataclasses import dataclass

from ..models.enums import EvidenceRule, FormBRight


@dataclass(frozen=True)
class RightSpec:
    code: FormBRight
    form_item: str  # numbering as printed on Form B
    label_en: str
    section: str  # provision of the Act the right arises under


# "Nature of community rights enjoyed", in the order printed on the form.
# NOTE item 3: the printed form cites "Section 3(1)(g)" under item 3(c), but the rights in
# item 3 (fish and water bodies, grazing, nomadic/pastoralist access) are those of
# Section 3(1)(d); Section 3(1)(g) is conversion of pattas/leases. We cite 3(1)(d) and
# keep the form wording. Confirm against the Gazette text before generating the PDF.
FORM_B_RIGHTS: tuple[RightSpec, ...] = (
    RightSpec(
        FormBRight.NISTAR,
        "1",
        "Community rights such as nistar, if any",
        "Section 3(1)(b)",
    ),
    RightSpec(
        FormBRight.MINOR_FOREST_PRODUCE,
        "2",
        "Rights over minor forest produce, if any",
        "Section 3(1)(c)",
    ),
    RightSpec(
        FormBRight.WATER_BODIES,
        "3(a)",
        "Community rights: uses or entitlements (fish, water bodies), if any",
        "Section 3(1)(d)",
    ),
    RightSpec(
        FormBRight.GRAZING,
        "3(b)",
        "Community rights: grazing, if any",
        "Section 3(1)(d)",
    ),
    RightSpec(
        FormBRight.NOMADIC_PASTORAL_ACCESS,
        "3(c)",
        "Community rights: traditional resource access for nomadic and pastoralist, if any",
        "Section 3(1)(d)",
    ),
    RightSpec(
        FormBRight.HABITAT,
        "4",
        "Community tenures of habitat and habitation for PTGs and pre-agricultural "
        "communities, if any",
        "Section 3(1)(e)",
    ),
    RightSpec(
        FormBRight.BIODIVERSITY_KNOWLEDGE,
        "5",
        "Right to access biodiversity, intellectual property and traditional knowledge, if any",
        "Section 3(1)(k)",
    ),
    RightSpec(
        FormBRight.OTHER_TRADITIONAL,
        "6",
        "Other traditional right, if any",
        "Section 3(1)(l)",
    ),
)

RIGHT_SPECS: dict[FormBRight, RightSpec] = {r.code: r for r in FORM_B_RIGHTS}

# Rule 11(1)(a): a claim is made "along with at least two of the evidences" in Rule 13.
MIN_EVIDENCE_ITEMS = 2


@dataclass(frozen=True)
class CompletenessItem:
    id: str
    ok: bool
    form_item: str
    rule: str
    message_key: str  # translated by the app; shown when ok is False


@dataclass(frozen=True)
class Completeness:
    items: tuple[CompletenessItem, ...]

    @property
    def done(self) -> int:
        return sum(1 for i in self.items if i.ok)

    @property
    def total(self) -> int:
        return len(self.items)


def form_b_completeness(
    *,
    village_fields: Sequence[str | None],
    claimant_names: Sequence[str],
    is_fdst_community: bool | None,
    is_otfd_community: bool | None,
    claimed_rights: Iterable[FormBRight],
    evidence_rules: Sequence[EvidenceRule],
) -> Completeness:
    """
    Documentation completeness for a Form B draft: which items are still empty.
    Advisory. It says nothing about eligibility and blocks nothing.
    """
    return Completeness(
        (
            CompletenessItem(
                "B-1",
                bool(claimant_names),
                "1",
                "Rule 11(1)(a)",
                "form_b.claimant_names_missing",
            ),
            CompletenessItem(
                "B-2",
                is_fdst_community is not None and is_otfd_community is not None,
                "1(a), 1(b)",
                "Rule 11(1)(a)",
                "form_b.community_status_unanswered",
            ),
            CompletenessItem(
                "B-3",
                all(bool(f and f.strip()) for f in village_fields),
                "2-5",
                "Rule 11(1)(a)",
                "form_b.village_details_incomplete",
            ),
            CompletenessItem(
                "B-4",
                any(True for _ in claimed_rights),
                "Nature of community rights, 1-6",
                "Section 3(1)",
                "form_b.no_right_described",
            ),
            CompletenessItem(
                "B-5",
                len(evidence_rules) >= MIN_EVIDENCE_ITEMS,
                "7",
                "Rule 11(1)(a), Rule 13(3)",
                "form_b.fewer_than_two_evidences",
            ),
        )
    )
