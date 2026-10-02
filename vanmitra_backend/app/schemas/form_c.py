"""Form C (community forest resource) request/response models. Comments give the form item."""

import uuid
from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

from ..models.enums import BoundarySide, CaseState, EvidenceRule, LandmarkKind, MemberCategory
from .form_b import CompletenessOut, EvidenceInput, EvidenceOut, VillageHeader

Label = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
Short = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)]
LongText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=4000)]


class LandmarkInput(BaseModel):
    side: BoundarySide = Field(examples=["east"])
    kind: LandmarkKind = Field(examples=["stream"])
    name: Label = Field(examples=["Nagdevta stream"])
    description: LongText | None = None


class BorderingVillageInput(BaseModel):
    name: Label = Field(examples=["Chambharshet"])
    shares_resources: bool = False
    sharing_details: LongText | None = None


class FormCInput(BaseModel):
    """The whole Form C draft (PUT replaces it). Every part may be empty while drafting."""

    # Item 5a. Omit (null) to keep the printed default statement.
    resolution_statement: LongText | None = None
    # Item 5b
    area_description: LongText | None = None
    approx_area_ha: float | None = Field(default=None, ge=0, le=1_000_000)
    pastoral_seasonal_use: bool = False
    seasonal_use_details: LongText | None = None
    landmarks: list[LandmarkInput] = Field(default_factory=list, max_length=200)
    # Item 6: optional ("if any and if known")
    khasra_compartment_numbers: list[Short] = Field(default_factory=list, max_length=200)
    # Item 7
    bordering_villages: list[BorderingVillageInput] = Field(default_factory=list, max_length=50)
    # Item 8, in print order
    evidence: list[EvidenceInput] = Field(default_factory=list, max_length=200)


class MemberSheetRow(BaseModel):
    name: str
    category: MemberCategory


class MemberSheetOut(BaseModel):
    """Item 5: generated from the Gram Sabha roster (maintained by the GS Secretary)."""

    total: int
    st: int
    otfd: int
    members: list[MemberSheetRow]


class LandmarkOut(BaseModel):
    seq: int
    side: BoundarySide
    kind: LandmarkKind
    name: str
    description: str | None


class BorderingVillageOut(BaseModel):
    seq: int
    name: str
    shares_resources: bool
    sharing_details: str | None


class FormCOut(BaseModel):
    case_id: uuid.UUID
    state: CaseState
    editable: bool
    header: VillageHeader  # items 1-4
    member_sheet: MemberSheetOut  # item 5
    resolution_statement: str  # item 5a
    area_description: str | None  # item 5b
    approx_area_ha: float | None
    pastoral_seasonal_use: bool
    seasonal_use_details: str | None
    landmarks: list[LandmarkOut]
    khasra_compartment_numbers: list[str]  # item 6
    bordering_villages: list[BorderingVillageOut]  # item 7
    evidence: list[EvidenceOut]  # item 8
    completeness: CompletenessOut
    updated_at: datetime


class FormCFieldsOut(BaseModel):
    """Static description of Form C for building the screen from the backend."""

    form: str
    rule: str
    default_resolution_statement: str
    boundary_sides: list[BoundarySide]
    landmark_kinds: list[LandmarkKind]
    evidence_rules: list[EvidenceRule]
    min_general_evidence: int
    min_cfr_evidence: int
