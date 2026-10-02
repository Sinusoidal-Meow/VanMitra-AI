"""SQLAlchemy models. Import every model module here so Alembic sees all tables."""

from .base import Base
from .claims import (
    ClaimCase,
    ClaimEvidenceEntry,
    FormB,
    FormBRightClaim,
    FormC,
    FormCBorderingVillage,
    FormCLandmark,
)
from .enums import (
    BoundarySide,
    CaseState,
    ClaimType,
    ConsolidationStatus,
    EvidenceRule,
    FormBRight,
    Gender,
    LandmarkKind,
    MemberCategory,
    Role,
)
from .people import AppUser, GramSabha, GsMember, UserRole, Village

__all__ = [
    "AppUser",
    "Base",
    "BoundarySide",
    "CaseState",
    "ClaimCase",
    "ClaimEvidenceEntry",
    "ClaimType",
    "ConsolidationStatus",
    "EvidenceRule",
    "FormB",
    "FormBRight",
    "FormBRightClaim",
    "FormC",
    "FormCBorderingVillage",
    "FormCLandmark",
    "Gender",
    "GramSabha",
    "GsMember",
    "LandmarkKind",
    "MemberCategory",
    "Role",
    "UserRole",
    "Village",
]
