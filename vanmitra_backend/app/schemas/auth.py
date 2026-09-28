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
    village_id: uuid.UUID
    village_name_mr: str
    village_name_en: str
    role: Role
    valid_from: date
    valid_to: date | None


class MeResponse(BaseModel):
    id: uuid.UUID
    name: str
    phone: str
    is_admin: bool
    roles: list[RoleOut] = Field(description="Roles valid today, per village")
