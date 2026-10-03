"""Village registry, Forest Rights Committee and claimants."""

import uuid
from datetime import date
from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

from ..models.enums import ConsolidationStatus, Gender, MemberCategory

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
Short = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
Ref = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]


# ── Village registry [Rule 2A] ─────────────────────────────────────────────────


class VillageCreate(BaseModel):
    name_mr: Name
    name_en: Name
    gram_panchayat: Name
    taluka: Short
    district: Short
    state: Short = "Maharashtra"
    lgd_code: Annotated[str, StringConstraints(strip_whitespace=True, max_length=20)] | None = (
        Field(default=None, description="LGD / Census 2011 village code, e.g. 551855 for Ozar")
    )
    parent_village_id: uuid.UUID | None = Field(
        default=None, description="Set for a hamlet / pada / habitation [Rule 2A]"
    )
    consolidation_status: ConsolidationStatus = ConsolidationStatus.RECOGNISED


class VillageUpdate(BaseModel):
    name_mr: Name | None = None
    name_en: Name | None = None
    gram_panchayat: Name | None = None
    taluka: Short | None = None
    district: Short | None = None
    lgd_code: str | None = Field(default=None, max_length=20)
    consolidation_status: ConsolidationStatus | None = None


class VillageOut(BaseModel):
    id: uuid.UUID
    name_mr: str
    name_en: str
    gram_panchayat: str
    taluka: str
    district: str
    state: str
    lgd_code: str | None
    parent_village_id: uuid.UUID | None
    consolidation_status: ConsolidationStatus
    gram_sabha_id: uuid.UUID | None


# ── Forest Rights Committee [Rule 3] ───────────────────────────────────────────


class FrcCheckIn(BaseModel):
    member_ids: list[uuid.UUID] = Field(max_length=30)
    chair_id: uuid.UUID | None = None
    secretary_id: uuid.UUID | None = None


class FrcCreate(FrcCheckIn):
    constituted_on: date
    resolution_ref: Ref | None = Field(
        default=None, description="Gram Sabha resolution that elected the FRC (number, date)"
    )


class FrcCheckOut(BaseModel):
    """Rule 3(1) arithmetic: 10-15 members, ≥ ⅔ ST (if the Gram Sabha has STs), ≥ ⅓ women."""

    ok: bool
    members: int
    st: int
    women: int
    required_st: int
    required_women: int
    st_rule_applies: bool
    failures: list[str]


class FrcMemberOut(BaseModel):
    gs_member_id: uuid.UUID
    name: str
    gender: Gender
    category: MemberCategory
    is_chair: bool
    is_secretary: bool


class FrcOut(BaseModel):
    id: uuid.UUID
    constituted_on: date
    resolution_ref: str | None
    sdlc_intimated_on: date | None
    is_current: bool
    composition: FrcCheckOut
    members: list[FrcMemberOut]


class FrcIntimation(BaseModel):
    sdlc_intimated_on: date


# ── Claimants per case ─────────────────────────────────────────────────────────


class ClaimantsIn(BaseModel):
    member_ids: list[uuid.UUID] = Field(max_length=500)


class ClaimantOut(BaseModel):
    gs_member_id: uuid.UUID
    name: str
    gender: Gender
    category: MemberCategory
