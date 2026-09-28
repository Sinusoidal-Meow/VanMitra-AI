"""Controlled vocabularies shared by models, schemas and rules."""

from enum import StrEnum


class Role(StrEnum):
    """The three app roles (PROJECT_PLAN §3, decision D1)."""

    FACILITATOR = "facilitator"  # NGO field worker: drafts only
    FRC_MEMBER = "frc_member"  # Forest Rights Committee member [Rule 3]
    GS_SECRETARY = "gs_secretary"  # Gram Panchayat Secretary [Rule 11(6)]


class Gender(StrEnum):
    FEMALE = "female"
    MALE = "male"
    OTHER = "other"


class MemberCategory(StrEnum):
    """Form C item 5: ST / OTFD status against each Gram Sabha member."""

    ST = "st"  # Scheduled Tribe
    OTFD = "otfd"  # Other Traditional Forest Dweller [Sec 2(o)]
    OTHER = "other"


class ConsolidationStatus(StrEnum):
    """Rule 2A: hamlets and unrecorded settlements are listed, consolidated, finalised."""

    RECOGNISED = "recognised"  # already a recorded village
    LISTED = "listed"  # listed and passed by its own Gram Sabha
    CONSOLIDATED = "consolidated"  # consolidated by the SDO
    FINALISED = "finalised"  # finalised by the DLC
