"""Claim call, acknowledgement, media, evidence ledger, letters, readiness and ledger check."""

import uuid
from datetime import date, datetime
from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

from ..models.enums import EvidenceKind, EvidenceRule, LetterTemplate
from .form_b import CompletenessOut

Text = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=4000)]
Line = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=300)]
Ref = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
Reason = Annotated[str, StringConstraints(strip_whitespace=True, min_length=5, max_length=4000)]


# ── Call for claims [Rule 11(1)] ───────────────────────────────────────────────


class ClaimCallCreate(BaseModel):
    called_on: date
    place_of_filing: Line = Field(examples=["Gram Panchayat office, Ozhar"])
    notice_displayed_on: date | None = None
    cfr_determination_on: date | None = Field(
        default=None, description="Date fixed for initiating CFR determination [Rule 11(1)(b)]"
    )


class ClaimCallExtend(BaseModel):
    extended_to: date
    reason: Reason = Field(description="Written reasons are required [Rule 11(1)(a)]")
    resolution_ref: Ref = Field(description="Gram Sabha resolution extending the period")


class ClaimCallDisplayed(BaseModel):
    notice_displayed_on: date


class ClaimCallOut(BaseModel):
    id: uuid.UUID
    called_on: date
    window_ends_on: date
    closes_on: date
    days_remaining: int
    is_open: bool
    place_of_filing: str
    notice_displayed_on: date | None
    cfr_determination_on: date | None
    extended_to: date | None
    extension_reason: str | None
    extension_resolution_ref: str | None
    is_current: bool


# ── Acknowledgement [Rule 11(3)] ──────────────────────────────────────────────


class AcknowledgementOut(BaseModel):
    """Data for the G4 acknowledgement receipt."""

    case_id: uuid.UUID
    serial: str
    acknowledged_on: date
    form: str
    claim_type: str
    claimant_label: str
    village: str
    gram_panchayat: str
    filed_within_window: bool | None
    documents_received: list[str]


# ── Media ──────────────────────────────────────────────────────────────────────


class MediaOut(BaseModel):
    id: uuid.UUID
    sha256: str
    mime: str
    size_bytes: int
    original_name: str | None
    captured_at: datetime | None
    gps_lat: float | None
    gps_lon: float | None
    gps_accuracy_m: float | None
    created_at: datetime


# ── Evidence ledger [Rule 13] ─────────────────────────────────────────────────


class EvidenceCreate(BaseModel):
    rule_ref: EvidenceRule
    kind: EvidenceKind
    description: Text
    media_id: uuid.UUID | None = None
    source_office: Ref | None = Field(default=None, examples=["Talathi, Ozhar sajja"])
    ref_no: Annotated[str, StringConstraints(strip_whitespace=True, max_length=100)] | None = None
    doc_date: date | None = None
    gps_lat: float | None = Field(default=None, ge=-90, le=90)
    gps_lon: float | None = Field(default=None, ge=-180, le=180)
    gps_accuracy_m: float | None = Field(default=None, ge=0)
    # Elder statement [Rule 13(1)(i)]
    elder_member_id: uuid.UUID | None = None
    transcript: Text | None = None
    signed_scan_media_id: uuid.UUID | None = None


class EvidenceCorrect(EvidenceCreate):
    correction_reason: Reason


class EvidenceVerify(BaseModel):
    remarks: Text | None = None


class VerificationOut(BaseModel):
    verified_by_name: str
    remarks: str | None
    at: datetime


class EvidenceOut(BaseModel):
    id: uuid.UUID
    rule_ref: EvidenceRule
    kind: EvidenceKind
    description: str
    media_id: uuid.UUID | None
    source_office: str | None
    ref_no: str | None
    doc_date: date | None
    gps_lat: float | None
    gps_lon: float | None
    gps_accuracy_m: float | None
    is_substitutable: bool
    elder_member_id: uuid.UUID | None
    transcript: str | None
    signed_scan_media_id: uuid.UUID | None
    supersedes_id: uuid.UUID | None
    superseded: bool
    correction_reason: str | None
    verified: bool
    verifications: list[VerificationOut]
    created_at: datetime


# ── Letters ───────────────────────────────────────────────────────────────────


class LetterCreate(BaseModel):
    template: LetterTemplate
    addressee: Line
    subject: Line
    body: Text | None = None
    case_id: uuid.UUID | None = None
    neighbour_village: Ref | None = Field(
        default=None, description="For G2 intimations to an adjoining Gram Sabha"
    )
    records_requested: list[Line] = Field(default_factory=list, max_length=50)


class LetterDispatch(BaseModel):
    dispatched_on: date
    reminder_after_days: int = Field(default=30, ge=1, le=365)


class LetterResponse(BaseModel):
    received_on: date
    outcome: Text


class LetterOut(BaseModel):
    id: uuid.UUID
    template: LetterTemplate
    addressee: str
    subject: str
    body: str | None
    case_id: uuid.UUID | None
    neighbour_village: str | None
    records_requested: list[str]
    dispatched_on: date | None
    reminder_on: date | None
    reminder_due: bool
    response_received_on: date | None
    outcome: str | None
    created_at: datetime


# ── Readiness and ledger ──────────────────────────────────────────────────────


class ReadinessOut(CompletenessOut):
    """Documentation completeness (R1-R10). Advisory; never a score (rule C2)."""

    case_id: uuid.UUID
    claim_type: str


class LedgerReportOut(BaseModel):
    ok: bool
    length: int
    head: str
    broken_at_seq: int | None
    broken_entity: str | None
    reason: str | None
