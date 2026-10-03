"""Controlled vocabularies shared by models, schemas and rules."""

from enum import StrEnum


class Role(StrEnum):
    """
    Module 3 logins, in three levels (claim path: village → SDO → district).
    Village roles are scoped to one village, the SDO to a taluka (sub-division),
    district officers to a district.
    """

    # Level 1: village
    VILLAGER = "villager"  # village user / claimant: files Forms A, B, C
    GRAM_SABHA = "gram_sabha"  # Gram Panchayat / Gram Sabha office: reviews, forwards to SDO
    # Level 2: sub-division
    SDO = "sdo"  # Sub-Divisional Officer, chair of the SDLC [Rule 5, 6(j)]
    # Level 3: district (all three sign the title, Rule 8(h)(i))
    COLLECTOR = "collector"  # District Collector / Deputy Commissioner, chair of the DLC
    DFO = "dfo"  # Divisional Forest Officer / Deputy Conservator of Forests
    TRIBAL_WELFARE_OFFICER = "tribal_welfare_officer"  # District Tribal Welfare Officer

    @property
    def level(self) -> str:
        if self in (Role.VILLAGER, Role.GRAM_SABHA):
            return "village"
        if self is Role.SDO:
            return "subdivision"
        return "district"


DISTRICT_ROLES: tuple[Role, ...] = (Role.COLLECTOR, Role.DFO, Role.TRIBAL_WELFARE_OFFICER)


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
    """
    Module 3 claim path:
    DRAFT → GS_REVIEW (filed to the Gram Panchayat / Gram Sabha) → SDO_REVIEW →
    DISTRICT_REVIEW (Collector, DFO, Tribal Welfare Officer each approve) → TITLE_ISSUED.
    Returns go one level down with remarks; REJECTED needs written reasons [Rule 12A(7)].
    """

    DRAFT = "draft"
    GS_REVIEW = "gs_review"
    SDO_REVIEW = "sdo_review"
    DISTRICT_REVIEW = "district_review"
    TITLE_ISSUED = "title_issued"
    REJECTED = "rejected"


class WorkflowAction(StrEnum):
    SUBMIT = "submit"  # village user / Gram Sabha files the draft
    APPROVE = "approve"
    RETURN = "return"  # back one level, with remarks
    REJECT = "reject"  # terminal, with written reasons


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


class BoundarySide(StrEnum):
    """Where a Form C landmark lies: the four boundaries (चतु:सीमा) or inside the area."""

    EAST = "east"  # पूर्व
    WEST = "west"  # पश्चिम
    NORTH = "north"  # उत्तर
    SOUTH = "south"  # दक्षिण
    WITHIN = "within"  # inside the CFR area


class LandmarkKind(StrEnum):
    """Recognisable landmarks used to describe a CFR boundary [Rule 12(1)(g)]."""

    RIVER = "river"
    STREAM = "stream"  # नाला
    SPRING = "spring"  # झरा
    POND = "pond"  # तलाव
    SACRED_PLACE = "sacred_place"  # देवस्थान
    SACRED_GROVE = "sacred_grove"  # देवराई / sacred tree
    BURIAL_GROUND = "burial_ground"  # दफन / दहन भूमी
    WELL = "well"  # विहीर
    ROAD = "road"  # रस्ता / path
    COMPARTMENT_PILLAR = "compartment_pillar"
    HILL = "hill"
    OTHER = "other"


class FormAClaim(StrEnum):
    """Form A, "Nature of claim on land", items 1-7 (Annexure I)."""

    HABITATION = "habitation"  # item 1(a) [Sec 3(1)(a)]
    SELF_CULTIVATION = "self_cultivation"  # item 1(b) [Sec 3(1)(a)]
    DISPUTED_LAND = "disputed_land"  # item 2 [Sec 3(1)(f)]
    PATTA_LEASE_GRANT = "patta_lease_grant"  # item 3 [Sec 3(1)(g)]
    IN_SITU_REHABILITATION = "in_situ_rehabilitation"  # item 4 [Sec 3(1)(m)]
    DISPLACED_WITHOUT_COMPENSATION = "displaced_without_compensation"  # item 5 [Sec 4(8)]
    FOREST_VILLAGE = "forest_village"  # item 6 [Sec 3(1)(h)]
    OTHER_TRADITIONAL = "other_traditional"  # item 7 [Sec 3(1)(l)]


class EvidenceKind(StrEnum):
    """How an evidence item was captured (Spec 4.2, 4.3)."""

    DOCUMENT_SCAN = "document_scan"  # 7/12, nistar patrak, orders, maps, certificates
    PHOTO = "photo"  # geotagged photograph of a structure, site or landmark
    GPS_POINT = "gps_point"  # waypoint; supplementary only (rule C3)
    SATELLITE = "satellite"  # imagery; supplementary only [Rule 12A(11) Expl. 2]
    AUDIO = "audio"
    ELDER_STATEMENT = "elder_statement"  # Rule 13(1)(i): signed written statement
    TEXT_NOTE = "text_note"  # field observation, research extract, genealogy note

    @property
    def is_substitutable(self) -> bool:
        """GPS and satellite output can never alone satisfy the two-evidence test (BR-06)."""
        return self not in (EvidenceKind.GPS_POINT, EvidenceKind.SATELLITE)


class LetterTemplate(StrEnum):
    """Tracked outgoing letters (G-series), each with its rule."""

    G2_INTIMATION_ADJOINING = "g2_intimation_adjoining"  # Rule 11(1)(b)
    G2_INTIMATION_SDLC = "g2_intimation_sdlc"  # Rule 11(1)(b)
    G5_MAPS_REQUEST = "g5_maps_request"  # Rule 6(b)
    G6_RECORDS_REQUEST = "g6_records_request"  # Rule 12(4)
    G7_SITE_VISIT = "g7_site_visit"  # Rule 12(1)
    G18_SURVEY_REQUEST = "g18_survey_request"  # supports Rule 12A(9)
    OTHER = "other"
