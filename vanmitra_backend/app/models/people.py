"""Village, Gram Sabha, members and app users (Stage 0)."""

import uuid
from datetime import date, datetime

from pydantic import Field

from .base import Doc, TimestampedDoc, now_ms
from .enums import ConsolidationStatus, Gender, MemberCategory, Role


class Village(TimestampedDoc):
    """Village or hamlet. Hamlets point at their parent village [Rule 2A]."""

    COLLECTION = "village"

    lgd_code: str | None = None  # unique when present
    name_mr: str
    name_en: str
    gram_panchayat: str
    taluka: str  # drives the SDLC jurisdiction
    district: str  # drives the DLC jurisdiction
    state: str = "Maharashtra"
    parent_village_id: uuid.UUID | None = None
    consolidation_status: ConsolidationStatus = ConsolidationStatus.RECOGNISED


class GramSabha(TimestampedDoc):
    """The Gram Sabha of a village: owner of the CFR claim [Sec 6(1)]. One per village."""

    COLLECTION = "gram_sabha"

    village_id: uuid.UUID
    # Head and length of this Gram Sabha's hash chain (PROJECT_PLAN rule R8).
    chain_head_hash: str | None = None
    chain_length: int = 0


class GsMember(TimestampedDoc):
    """
    Gram Sabha member. Gender and category feed three legal computations:
    FRC composition [Rule 3(1)], quorum [Rule 4(2)] and the Form C member sheet.
    Whether a member is a claimant is per case (case_claimant, Stage 2).
    """

    COLLECTION = "gs_member"

    gram_sabha_id: uuid.UUID
    name: str
    gender: Gender
    category: MemberCategory
    active: bool = True


class AppUser(TimestampedDoc):
    """A person who logs in. Roles are per village, in user_role."""

    COLLECTION = "app_user"

    phone: str  # unique
    pin_hash: str
    name: str
    gs_member_id: uuid.UUID | None = None
    # Back-office implementation team only; grants no access to case content.
    is_admin: bool = False
    is_active: bool = True
    last_login_at: datetime | None = None


class UserRole(Doc):
    """
    A role held by a user within a jurisdiction, with validity dates (transfers keep
    history). Village roles name a village; the SDO a taluka + district.
    """

    COLLECTION = "user_role"

    user_id: uuid.UUID
    village_id: uuid.UUID | None = None
    taluka: str | None = None
    district: str | None = None
    role: Role
    valid_from: date = Field(default_factory=date.today)
    valid_to: date | None = None
    created_at: datetime = Field(default_factory=now_ms)

    def is_active_on(self, day: date) -> bool:
        return self.valid_from <= day and (self.valid_to is None or day <= self.valid_to)
