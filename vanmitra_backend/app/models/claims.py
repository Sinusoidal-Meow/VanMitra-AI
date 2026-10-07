"""
Claim cases. A claim and its form are one record: the Form A, B or C draft is stored
inside the claim, with its lists (family members, rights, landmarks, ...). The history
of actions on a claim is a separate, append-only record (workflow_event).
"""

import uuid
from datetime import date, datetime

from pydantic import Field

from .base import Dec2, Doc, Part, TimestampedDoc, new_id, now_ms
from .enums import (
    BoundarySide,
    CaseState,
    ClaimType,
    EvidenceRule,
    FormAClaim,
    FormBRight,
    LandmarkKind,
    Role,
    WorkflowAction,
)


class FormBRightClaim(Part):
    """A claimed right from Form B "Nature of community rights enjoyed" (items 1-6).

    No entry means the right is not claimed.
    """

    id: uuid.UUID = Field(default_factory=new_id)
    right_code: FormBRight  # one entry per right
    # How the community enjoys the right, in the community's own words (any language).
    details: str
    # Optional named things: produce (mahua, tendu), ponds, grazing areas, local names.
    items: list[str] = Field(default_factory=list)
    # Maharashtra field practice, "लाभ घेतलेल्या सामूहिक हक्कांचे स्वरूप" (1mitra.md §6.2):
    # per right, the survey/compartment numbers, the area, the four boundaries by landmark
    # (चतु:सीमा) and the annual quantity used. All optional.
    survey_compartment_numbers: list[str] = Field(default_factory=list)
    total_area_ha: Dec2 | None = None
    common_use_area_ha: Dec2 | None = None
    boundary_east: str | None = None
    boundary_west: str | None = None
    boundary_north: str | None = None
    boundary_south: str | None = None
    annual_quantity: str | None = None


class FormB(Part):
    """The Form B draft for a CR case. Items 2-5 come from the village registry."""

    # Item 1. Empty while drafting; completeness reports it.
    claimant_names: list[str] = Field(default_factory=list)
    # Items 1(a), 1(b). None = not answered yet.
    is_fdst_community: bool | None = None
    is_otfd_community: bool | None = None
    # Item 8.
    other_information: str | None = None
    updated_by_user_id: uuid.UUID
    rights: list[FormBRightClaim] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=now_ms)
    updated_at: datetime = Field(default_factory=now_ms)


class ClaimEvidenceEntry(Part):
    """
    A line of the form's "Evidence in support" list (Form B item 7 / Form C item 8),
    tagged with its Rule 13 sub-clause.
    """

    id: uuid.UUID = Field(default_factory=new_id)
    seq: int  # 1-based order as printed
    rule_ref: EvidenceRule
    description: str
    created_at: datetime = Field(default_factory=now_ms)


class FormCLandmark(Part):
    """A recognisable landmark of the CFR area (item 5b): on a boundary side or within."""

    id: uuid.UUID = Field(default_factory=new_id)
    seq: int
    side: BoundarySide
    kind: LandmarkKind
    name: str  # local name, e.g. "नागदेवता"
    description: str | None = None


class FormCBorderingVillage(Part):
    """Item 7: a bordering village, with any sharing of resources and responsibilities."""

    id: uuid.UUID = Field(default_factory=new_id)
    seq: int
    name: str
    shares_resources: bool = False
    sharing_details: str | None = None


class FormC(Part):
    """
    The Form C draft for a CFR case [Sec 3(1)(i); Rule 11(1), 11(4)].
    Items 1-4 come from the village registry and item 5 (member sheet) from the
    Gram Sabha roster; the map polygon itself is captured in the mapping stage.
    """

    # Item 5a: the resolving statement, editable by the FRC (local language allowed).
    resolution_statement: str
    # Item 5b: the community forest resource in words, until the mapped polygon exists.
    area_description: str | None = None
    approx_area_ha: Dec2 | None = None
    # Item 5b: "or seasonal use of landscape in the case of pastoral communities".
    pastoral_seasonal_use: bool = False
    seasonal_use_details: str | None = None
    # Item 6: khasra / compartment numbers, "if any and if known" (optional by design).
    khasra_compartment_numbers: list[str] = Field(default_factory=list)
    updated_by_user_id: uuid.UUID
    landmarks: list[FormCLandmark] = Field(default_factory=list)
    bordering_villages: list[FormCBorderingVillage] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=now_ms)
    updated_at: datetime = Field(default_factory=now_ms)


class FormAFamilyMember(Part):
    """Item 10: other members of the family with age (children and adult dependents)."""

    id: uuid.UUID = Field(default_factory=new_id)
    seq: int
    name: str
    age: int | None = None
    relation: str | None = None


class FormAClaimItem(Part):
    """
    A claimed item under Form A "Nature of claim on land" (items 1-7).

    No entry means the item is not claimed.
    """

    id: uuid.UUID = Field(default_factory=new_id)
    claim_code: FormAClaim  # one entry per item
    extent_ha: Dec2 | None = None
    details: str


class FormA(Part):
    """
    The Form A draft for an IFR case: Claim Form for Rights to Forest Land [Rule 11(1)(a)].
    Items 5-8 (village, GP, tehsil, district) come from the village registry.
    """

    claimant_names: list[str] = Field(default_factory=list)  # item 1
    spouse_name: str | None = None  # item 2
    father_mother_name: str | None = None  # item 3
    address: str | None = None  # item 4
    is_scheduled_tribe: bool | None = None  # item 9(a)
    is_otfd: bool | None = None  # item 9(b)
    spouse_is_scheduled_tribe: bool | None = None  # item 9 note
    other_information: str | None = None  # claim item 9
    updated_by_user_id: uuid.UUID
    family_members: list[FormAFamilyMember] = Field(default_factory=list)
    claims: list[FormAClaimItem] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=now_ms)
    updated_at: datetime = Field(default_factory=now_ms)


class ClaimCase(TimestampedDoc):
    """
    One claim. IFR, CR and CFR cases share this collection (Spec §2.1), so cases in a
    village share the same Gram Sabha meeting, quorum record and evidence pool.
    Community (CR/CFR) cases are owned by the Gram Sabha, not an individual.
    """

    COLLECTION = "claim_case"

    gram_sabha_id: uuid.UUID
    claim_type: ClaimType
    state: CaseState = CaseState.DRAFT
    created_by_user_id: uuid.UUID
    # Furthest level the case has reached (0 draft, 1 Gram Sabha, 2 SDO, 3 district,
    # 4 title). Officials see a case once it has reached their level, even if returned.
    reached_stage: int = 0
    # Acknowledgement in writing of every claim received [Rule 11(3)], issued on filing.
    # The serial is unique within the Gram Sabha's own register.
    ack_serial: str | None = None
    acknowledged_on: date | None = None
    # The call for claims it was filed under, and whether it came within the window.
    claim_call_id: uuid.UUID | None = None
    filed_within_window: bool | None = None
    # The form of this claim (only the one matching claim_type is ever set).
    form_a: FormA | None = None
    form_b: FormB | None = None
    form_c: FormC | None = None
    evidence_entries: list[ClaimEvidenceEntry] = Field(default_factory=list)


class WorkflowEvent(Doc):
    """
    Append-only history of every action on a case: who, in which role, what, remarks.
    """

    COLLECTION = "workflow_event"
    APPEND_ONLY = True

    case_id: uuid.UUID
    action: WorkflowAction
    from_state: CaseState
    to_state: CaseState
    # Empty for the automatic expiry, which no person performs.
    actor_user_id: uuid.UUID | None = None
    actor_role: Role | None = None
    actor_name: str  # as it was at the time
    remarks: str | None = None
    created_at: datetime = Field(default_factory=now_ms)
