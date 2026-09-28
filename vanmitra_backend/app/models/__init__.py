"""SQLAlchemy models. Import every model module here so Alembic sees all tables."""

from .base import Base
from .claims import ClaimCase, ClaimEvidenceEntry, FormB, FormBRightClaim
from .enums import (
    CaseState,
    ClaimType,
    ConsolidationStatus,
    EvidenceRule,
    FormBRight,
    Gender,
    MemberCategory,
    Role,
)
from .people import AppUser, GramSabha, GsMember, UserRole, Village

__all__ = [
    "AppUser",
    "Base",
    "CaseState",
    "ClaimCase",
    "ClaimEvidenceEntry",
    "ClaimType",
    "ConsolidationStatus",
    "EvidenceRule",
    "FormB",
    "FormBRight",
    "FormBRightClaim",
    "Gender",
    "GramSabha",
    "GsMember",
    "MemberCategory",
    "Role",
    "UserRole",
    "Village",
]
