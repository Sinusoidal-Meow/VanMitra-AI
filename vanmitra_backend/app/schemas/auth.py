import uuid
from datetime import date
from typing import Literal

from pydantic import BaseModel, Field

from ..models import Role

# 10-digit Indian mobile number, without +91 (the app strips it).
PHONE_PATTERN = r"^[6-9]\d{9}$"
PIN_PATTERN = r"^\d{6}$"


class LoginRequest(BaseModel):
    phone: str = Field(pattern=PHONE_PATTERN, examples=["9000000001"])
    pin: str = Field(pattern=PIN_PATTERN, examples=["123456"])


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"  # noqa: S105 (OAuth2 scheme name)
    expires_in: int = Field(description="Access token lifetime in seconds")


class RoleOut(BaseModel):
    role: Role
    level: str = Field(description="village | subdivision | district")
    village_id: uuid.UUID | None
    village_name_mr: str | None
    village_name_en: str | None
    taluka: str | None
    district: str | None
    valid_from: date
    valid_to: date | None


class MeResponse(BaseModel):
    id: uuid.UUID
    name: str
    phone: str
    is_admin: bool
    roles: list[RoleOut] = Field(description="Roles valid today, with jurisdiction")


class RegisterRequest(BaseModel):
    """Self-registration of a village user (claimant). Officials are created by an admin."""

    name: str = Field(min_length=1, max_length=200)
    phone: str = Field(pattern=PHONE_PATTERN)
    pin: str = Field(pattern=PIN_PATTERN)
    village_id: uuid.UUID


class PublicVillage(BaseModel):
    id: uuid.UUID
    name_mr: str
    name_en: str
    gram_panchayat: str
    taluka: str
    district: str


class OfficialCreate(BaseModel):
    """
    Admin creates Gram Sabha and government accounts with their jurisdiction:
    gram_sabha / villager → village_id; sdo → taluka + district;
    collector / dfo / tribal_welfare_officer → district.
    """

    name: str = Field(min_length=1, max_length=200)
    phone: str = Field(pattern=PHONE_PATTERN)
    pin: str = Field(pattern=PIN_PATTERN)
    role: Role
    village_id: uuid.UUID | None = None
    taluka: str | None = Field(default=None, max_length=100)
    district: str | None = Field(default=None, max_length=100)


class UserOut(BaseModel):
    id: uuid.UUID
    name: str
    phone: str
    role: Role
    village_id: uuid.UUID | None
    taluka: str | None
    district: str | None
