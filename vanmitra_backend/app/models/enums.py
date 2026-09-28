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


class ClaimType(StrEnum):
    """The three claim types share one case table (Spec §2.1)."""

    IFR = "ifr"  # Individual Forest Rights, Form A [Rule 11(1)(a)]
    CR = "cr"  # Community Rights, Form B [Rule 11(1)(a), 11(4)]
    CFR = "cfr"  # Community Forest Resource, Form C [Rule 11(1), 11(4)]


class CaseState(StrEnum):
    """Claim state machine (PROJECT_PLAN §4.2). Only DRAFT is reachable so far."""

    DRAFT = "draft"
    EVIDENCE_COLLECTION = "evidence_collection"
    MAPPING_IN_PROGRESS = "mapping_in_progress"
    DISPUTE_JOINT_HEARING = "dispute_joint_hearing"
    FRC_VERIFICATION = "frc_verification"
    GS_READY = "gs_ready"
    GS_RESOLVED = "gs_resolved"
    SUBMITTED_SDLC = "submitted_sdlc"
    SDLC_UNDER_EXAM = "sdlc_under_exam"
    SDLC_FORWARDED = "sdlc_forwarded"
    DLC_UNDER_CONSIDERATION = "dlc_under_consideration"
    REMANDED_TO_GS = "remanded_to_gs"
    MODIFIED_REJECTED = "modified_rejected"
    PETITION_FILED = "petition_filed"
    TITLE_APPROVED = "title_approved"
    SURVEY_PENDING = "survey_pending"
    RECORD_UPDATED = "record_updated"
    CFR_ACTIVE = "cfr_active"


class FormBRight(StrEnum):
    """Form B, "Nature of community rights enjoyed", items 1-6 (Annexure I)."""

    NISTAR = "nistar"  # item 1
    MINOR_FOREST_PRODUCE = "minor_forest_produce"  # item 2
    WATER_BODIES = "water_bodies"  # item 3(a)
    GRAZING = "grazing"  # item 3(b)
    NOMADIC_PASTORAL_ACCESS = "nomadic_pastoral_access"  # item 3(c)
    HABITAT = "habitat"  # item 4
    BIODIVERSITY_KNOWLEDGE = "biodiversity_knowledge"  # item 5
    OTHER_TRADITIONAL = "other_traditional"  # item 6


class EvidenceRule(StrEnum):
    """Rule 13 sub-clauses: the controlled vocabulary every evidence item is tagged with."""

    R13_1_A = "13(1)(a)"  # public documents, Government records
    R13_1_B = "13(1)(b)"  # Government authorised documents (voter ID, ration card...)
    R13_1_C = "13(1)(c)"  # physical attributes (houses, bunds, check dams)
    R13_1_D = "13(1)(d)"  # quasi-judicial and judicial records
    R13_1_E = "13(1)(e)"  # research studies, customs and traditions
    R13_1_F = "13(1)(f)"  # records of erstwhile princely States / intermediaries
    R13_1_G = "13(1)(g)"  # traditional structures (wells, burial grounds, sacred places)
    R13_1_H = "13(1)(h)"  # genealogy
    R13_1_I = "13(1)(i)"  # statement of elders other than claimants
    R13_2_A = "13(2)(a)"  # community rights such as nistar
    R13_2_B = "13(2)(b)"  # grazing grounds, MFP areas, fishing grounds, water sources...
    R13_2_C = "13(2)(c)"  # community structures, sacred groves, burial grounds
    R13_2_D = "13(2)(d)"  # earlier classification as protected forest / gochar / nistari
    R13_2_E = "13(2)(e)"  # traditional agriculture

    @property
    def is_general(self) -> bool:
        """Rule 13(1) (general) as opposed to 13(2) (community forest resource)."""
        return self.value.startswith("13(1)")
