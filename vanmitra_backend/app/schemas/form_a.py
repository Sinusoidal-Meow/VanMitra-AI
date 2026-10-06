"""Form A (individual forest rights) request/response models. Comments give the form item."""

import uuid
from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints, field_validator

from ..models.enums import CaseState, FormAClaim
from .form_b import CompletenessOut, EvidenceInput, EvidenceOut, VillageHeader

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
Short = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
LongText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=4000)]


class FamilyMemberInput(BaseModel):
    name: Name
    age: int | None = Field(default=None, ge=0, le=130)
    relation: Short | None = Field(default=None, examples=["son"])


class ClaimItemInput(BaseModel):
    """A claimed item; leave an item out of `claims` if it is not claimed."""

    extent_ha: float | None = Field(default=None, ge=0, le=10_000, description="Area in hectares")
    details: LongText = Field(description="Location, landmarks, since when, how used")


class FormAInput(BaseModel):
    """The whole Form A draft (PUT replaces it). Every part may be empty while drafting."""

    claimant_names: list[Name] = Field(default_factory=list, max_length=20)  # item 1
    spouse_name: Name | None = None  # item 2
    father_mother_name: Name | None = None  # item 3
    address: LongText | None = None  # item 4
    is_scheduled_tribe: bool | None = None  # item 9(a)
    is_otfd: bool | None = None  # item 9(b)
    spouse_is_scheduled_tribe: bool | None = None  # item 9 note
    family_members: list[FamilyMemberInput] = Field(default_factory=list, max_length=50)  # 10
    claims: dict[FormAClaim, ClaimItemInput] = Field(default_factory=dict)  # nature of claim 1-7
    evidence: list[EvidenceInput] = Field(default_factory=list, max_length=200)  # item 8
    other_information: LongText | None = None  # item 9

    @field_validator("claimant_names")
    @classmethod
    def _unique(cls, names: list[str]) -> list[str]:
        if len({n.casefold() for n in names}) != len(names):
            raise ValueError("duplicate claimant name")
        return names


class FamilyMemberOut(BaseModel):
    seq: int
    name: str
    age: int | None
    relation: str | None


class ClaimItemOut(BaseModel):
    code: FormAClaim
    form_item: str
    label_en: str
    section: str
    claimed: bool
    extent_ha: float | None
    details: str | None


class FormAOut(BaseModel):
    case_id: uuid.UUID
    state: CaseState
    editable: bool
    header: VillageHeader  # items 5-8
    claimant_names: list[str]
    spouse_name: str | None
    father_mother_name: str | None
    address: str | None
    is_scheduled_tribe: bool | None
    is_otfd: bool | None
    spouse_is_scheduled_tribe: bool | None
    family_members: list[FamilyMemberOut]
    claims: list[ClaimItemOut] = Field(description="All 8 items in printed order")
    total_extent_ha: float
    extent_note: str | None = Field(description="Sec 4(6) note when the total exceeds 4 ha")
    evidence: list[EvidenceOut]
    other_information: str | None
    completeness: CompletenessOut
    updated_at: datetime
