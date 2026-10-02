"""Form B (community rights) request/response models. Field comments give the form item."""

import uuid
from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints, field_validator

from ..models.enums import CaseState, EvidenceRule, FormBRight

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
Label = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
LongText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=4000)]


# ── Form B input ───────────────────────────────────────────────────────────────


class RightInput(BaseModel):
    """A right the community enjoys. Leave a right out of `rights` if it is not claimed."""

    details: LongText = Field(description="How the community enjoys this right, in its own words")
    items: list[Label] = Field(
        default_factory=list,
        max_length=50,
        description="Optional named things: produce, ponds, grazing areas, local names",
    )


class EvidenceInput(BaseModel):
    rule_ref: EvidenceRule = Field(examples=["13(1)(a)"])
    description: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=1000)
    ] = Field(examples=["Nistar patrak of Ozhar village, Revenue Dept., 1962"])


class FormBInput(BaseModel):
    """
    The whole Form B draft (PUT replaces it). Every part may be empty while drafting;
    GET .../form-b reports what is still missing.
    """

    # Item 1
    claimant_names: list[Name] = Field(
        default_factory=list, max_length=100, examples=[["Ozhar Gram Sabha"]]
    )
    # Items 1(a), 1(b). null = not answered yet
    is_fdst_community: bool | None = None
    is_otfd_community: bool | None = None
    # "Nature of community rights enjoyed", items 1-6: only the rights being claimed
    rights: dict[FormBRight, RightInput] = Field(default_factory=dict)
    # Item 7, in the order it should be printed
    evidence: list[EvidenceInput] = Field(default_factory=list, max_length=200)
    # Item 8
    other_information: LongText | None = None

    @field_validator("claimant_names")
    @classmethod
    def _unique_names(cls, names: list[str]) -> list[str]:
        seen: set[str] = set()
        for n in names:
            if n.casefold() in seen:
                raise ValueError(f"duplicate claimant name: {n}")
            seen.add(n.casefold())
        return names


# ── Form B output ──────────────────────────────────────────────────────────────


class VillageHeader(BaseModel):
    """Form B items 2-5, read from the village registry (never typed in)."""

    village_id: uuid.UUID
    village_name_mr: str  # item 2
    village_name_en: str  # item 2
    gram_panchayat: str  # item 3
    taluka: str  # item 4
    district: str  # item 5


class RightOut(BaseModel):
    code: FormBRight
    form_item: str
    label_en: str
    section: str
    claimed: bool
    details: str | None
    items: list[str]


class EvidenceOut(BaseModel):
    seq: int
    rule_ref: EvidenceRule
    description: str


class CompletenessItemOut(BaseModel):
    id: str
    ok: bool
    form_item: str
    rule: str
    message_key: str


class CompletenessOut(BaseModel):
    """Documentation completeness: advisory only. Never a score, never an eligibility result."""

    done: int
    total: int
    items: list[CompletenessItemOut]


class FormBOut(BaseModel):
    case_id: uuid.UUID
    state: CaseState
    editable: bool
    header: VillageHeader
    claimant_names: list[str]
    is_fdst_community: bool | None
    is_otfd_community: bool | None
    rights: list[RightOut] = Field(description="All 8 rights in form order, claimed or not")
    evidence: list[EvidenceOut]
    other_information: str | None
    completeness: CompletenessOut
    updated_at: datetime


class FormBFieldOut(BaseModel):
    code: FormBRight
    form_item: str
    label_en: str
    section: str


class FormBFieldsOut(BaseModel):
    """Static description of Form B, so the app can build its screen from the backend."""

    form: str
    rule: str
    rights: list[FormBFieldOut]
    evidence_rules: list[EvidenceRule]
    min_evidence_items: int
