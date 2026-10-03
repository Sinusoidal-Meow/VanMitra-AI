"""Field verification, Gram Sabha meetings, attendance, quorum and resolutions."""

import uuid
from datetime import date, datetime
from typing import Annotated, Any, Literal

from pydantic import BaseModel, Field, StringConstraints

Text = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=8000)]
Line = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=300)]


# ── Field verification [Rule 12(1), 12A(1)(2)] ────────────────────────────────


class Presence(BaseModel):
    name: Line
    designation: Line | None = None
    department: Literal["forest", "revenue", "frc", "other"]


class VerificationIn(BaseModel):
    visit_on: date
    observations: Text
    presence: list[Presence] = Field(min_length=1, max_length=100)
    intimation_id: uuid.UUID | None = Field(
        default=None, description="The G7 letter (dispatched) that intimated the visit"
    )
    forest_signed: bool = False
    forest_absence_recorded: bool = False
    revenue_signed: bool = False
    revenue_absence_recorded: bool = False
    signed_scan_media_id: uuid.UUID | None = None


class VerificationOut(BaseModel):
    id: uuid.UUID
    attempt_no: int
    visit_on: date
    intimation_id: uuid.UUID | None
    observations: str
    presence: list[Presence]
    forest_signed: bool
    forest_absence_recorded: bool
    revenue_signed: bool
    revenue_absence_recorded: bool
    signed_scan_media_id: uuid.UUID | None
    complete: bool
    finality_note: bool
    created_at: datetime


# ── Meetings, attendance, quorum ──────────────────────────────────────────────


class MeetingIn(BaseModel):
    held_on: date
    place: Line
    notice_on: date | None = None
    agenda: Text


class AttendanceIn(BaseModel):
    present_member_ids: list[uuid.UUID] = Field(max_length=5000)


class QuorumOut(BaseModel):
    registered: int
    present: int
    women_present: int
    claimants_total: int
    claimants_present: int
    required_present: int
    required_women: int
    required_claimants: int
    t1: bool
    t2: bool
    t3: bool
    passed: bool
    failures: list[str]


class MeetingOut(BaseModel):
    id: uuid.UUID
    held_on: date
    place: str
    notice_on: date | None
    agenda: str
    registered_count: int
    present_count: int
    women_present: int
    attendance_recorded: bool
    resolutions: int


class ResolutionIn(BaseModel):
    case_id: uuid.UUID
    decision_text: Text
    votes_for: int = Field(ge=0)
    votes_against: int = Field(ge=0)
    signed_scan_media_id: uuid.UUID | None = None


class ResolutionOut(BaseModel):
    id: uuid.UUID
    meeting_id: uuid.UUID
    case_id: uuid.UUID
    number: str
    decision_text: str
    votes_for: int
    votes_against: int
    boundary_id: uuid.UUID | None
    quorum_proof: dict[str, Any]
    signed_scan_media_id: uuid.UUID | None
    created_at: datetime


class ApprovalPrerequisite(BaseModel):
    id: str
    ok: bool
    rule: str
    message_key: str


class ApprovalCheckOut(BaseModel):
    """What the Gram Sabha still needs before it may forward a CFR claim (BR-04)."""

    case_id: uuid.UUID
    ready: bool
    items: list[ApprovalPrerequisite]
