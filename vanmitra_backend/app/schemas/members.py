"""Gram Sabha member roster: feeds the Form C member sheet, FRC composition and quorum."""

import uuid
from typing import Annotated

from pydantic import BaseModel, StringConstraints

from ..models.enums import Gender, MemberCategory

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]


class MemberCreate(BaseModel):
    name: Name
    gender: Gender
    category: MemberCategory


class MemberUpdate(BaseModel):
    name: Name | None = None
    gender: Gender | None = None
    category: MemberCategory | None = None
    active: bool | None = None


class MemberOut(BaseModel):
    id: uuid.UUID
    name: str
    gender: Gender
    category: MemberCategory
    active: bool
