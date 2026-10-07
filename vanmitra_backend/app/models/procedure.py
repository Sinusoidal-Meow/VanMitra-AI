"""
The statutory procedure around a claim (BACKEND_PLAN.md §3): the Forest Rights
Committee, claimants per case, the claim call, evidence ledger, letters, verification,
meetings and resolutions, and the record after the title.
"""

import uuid
from datetime import date, datetime
from typing import Any

from pydantic import Field

from .base import Doc, Part, TimestampedDoc, new_id, now_ms
from .enums import EvidenceKind, EvidenceRule, LetterTemplate


class FrcMember(Part):
    gs_member_id: uuid.UUID  # once per committee
    is_chair: bool = False
    is_secretary: bool = False


class Frc(TimestampedDoc):
    """
    A Forest Rights Committee constituted by the Gram Sabha [Rule 3]. A new
    constitution supersedes the previous one (is_current); history is kept.
    """

    COLLECTION = "frc"

    gram_sabha_id: uuid.UUID
    constituted_on: date
    # Gram Sabha resolution that elected the FRC (number / date, as written on paper).
    resolution_ref: str | None = None
    # Rule 3(1): the chairperson and secretary are intimated to the SDLC.
    sdlc_intimated_on: date | None = None
    # The arithmetic as it was on the day (members, ST, women, required), never recomputed.
    composition_proof: dict[str, Any]
    is_current: bool = True
    created_by_user_id: uuid.UUID
    members: list[FrcMember] = Field(default_factory=list)


class CaseClaimant(Doc):
    """
    Gram Sabha members who are claimants in a case (once each). Drives recusal
    [Rule 3(3)], the elder-statement block [Rule 13(1)(i)] and quorum test 3 [Rule 4(2)].
    """

    COLLECTION = "case_claimant"

    case_id: uuid.UUID
    gs_member_id: uuid.UUID
    created_at: datetime = Field(default_factory=now_ms)


class Recusal(Doc):
    """An FRC member stepping away from verifying a claim they are party to [Rule 3(3)]."""

    COLLECTION = "recusal"

    case_id: uuid.UUID
    gs_member_id: uuid.UUID  # once per case
    reason: str
    recorded_at: datetime = Field(default_factory=now_ms)


class ClaimCall(TimestampedDoc):
    """
    The call for claims by the Gram Sabha [Rule 11(1)(a)]: a three-month window,
    extendable only with written reasons and a resolution; and the date fixed for
    initiating the determination of the community forest resource [Rule 11(1)(b)].
    """

    COLLECTION = "claim_call"

    gram_sabha_id: uuid.UUID
    called_on: date
    window_ends_on: date
    place_of_filing: str
    notice_displayed_on: date | None = None
    cfr_determination_on: date | None = None
    extended_to: date | None = None
    extension_reason: str | None = None
    extension_resolution_ref: str | None = None
    is_current: bool = True
    created_by_user_id: uuid.UUID

    @property
    def closes_on(self) -> date:
        return self.extended_to or self.window_ends_on


class Media(Doc):
    """An uploaded file (scan, photo, audio). The bytes live in storage, keyed by sha256."""

    COLLECTION = "media"

    sha256: str
    mime: str
    size_bytes: int
    original_name: str | None = None
    storage_key: str
    uploaded_by_user_id: uuid.UUID
    captured_at: datetime | None = None
    gps_lat: float | None = None
    gps_lon: float | None = None
    gps_accuracy_m: float | None = None
    created_at: datetime = Field(default_factory=now_ms)


class Evidence(Doc):
    """
    The evidence ledger (append-only, hash-chained). Every item is tagged with its
    Rule 13 sub-clause. A correction is a new record that supersedes the old one.
    """

    COLLECTION = "evidence"
    APPEND_ONLY = True

    case_id: uuid.UUID
    rule_ref: EvidenceRule
    kind: EvidenceKind
    description: str
    media_id: uuid.UUID | None = None
    source_office: str | None = None
    ref_no: str | None = None
    doc_date: date | None = None
    gps_lat: float | None = None
    gps_lon: float | None = None
    gps_accuracy_m: float | None = None
    is_substitutable: bool
    # Rule 13(1)(i): the elder (not a claimant), the transcript, the signed sheet.
    elder_member_id: uuid.UUID | None = None
    transcript: str | None = None
    signed_scan_media_id: uuid.UUID | None = None
    supersedes_id: uuid.UUID | None = None
    correction_reason: str | None = None
    added_by_user_id: uuid.UUID
    created_at: datetime = Field(default_factory=now_ms)


class EvidenceVerification(Doc):
    """The FRC / Gram Sabha attesting an evidence item (append-only, hash-chained)."""

    COLLECTION = "evidence_verification"
    APPEND_ONLY = True

    evidence_id: uuid.UUID
    verified_by_user_id: uuid.UUID
    verified_by_name: str
    remarks: str | None = None
    created_at: datetime = Field(default_factory=now_ms)


class LedgerEntry(Doc):
    """
    One link of the hash chain of a Gram Sabha (Spec 6.8), seq unique per Gram Sabha:
        record_hash(n) = SHA256( canonical_json(payload(n)) || record_hash(n-1) )
    """

    COLLECTION = "ledger_entry"
    APPEND_ONLY = True

    gram_sabha_id: uuid.UUID
    seq: int
    entity: str  # the collection of the chained record
    entity_id: uuid.UUID
    prev_hash: str
    record_hash: str
    created_at: datetime = Field(default_factory=now_ms)


class Correspondence(TimestampedDoc):
    """
    A tracked outgoing letter (G2 intimations, G5/G6 requests, G7 site-visit notice,
    G18 survey request): addressee, dispatch, reminder, response.
    """

    COLLECTION = "correspondence"

    gram_sabha_id: uuid.UUID
    case_id: uuid.UUID | None = None
    template: LetterTemplate
    addressee: str
    subject: str
    body: str | None = None
    neighbour_village: str | None = None  # G2 adjoining GS
    records_requested: list[str] = Field(default_factory=list)
    dispatched_on: date | None = None
    reminder_on: date | None = None
    response_received_on: date | None = None
    outcome: str | None = None
    created_by_user_id: uuid.UUID


class VerificationProceeding(Doc):
    """
    The site visit with the Forest and Revenue officials [Rule 12(1), 12A(1)(2)] (BR-07).
    Append-only and hash-chained; a repeat visit is a new record with the next attempt_no
    (unique per case). Each department either signed or its absence is recorded.
    """

    COLLECTION = "verification_proceeding"
    APPEND_ONLY = True

    case_id: uuid.UUID
    attempt_no: int
    visit_on: date
    intimation_id: uuid.UUID | None = None
    observations: str
    # [{"name", "designation", "department": "forest" | "revenue" | "frc" | "other"}]
    presence: list[dict[str, Any]]
    forest_signed: bool
    forest_absence_recorded: bool
    revenue_signed: bool
    revenue_absence_recorded: bool
    signed_scan_media_id: uuid.UUID | None = None
    recorded_by_user_id: uuid.UUID
    created_at: datetime = Field(default_factory=now_ms)


class Attendance(Part):
    """The manual attendance register is the legal record (face match is only a helper)."""

    id: uuid.UUID = Field(default_factory=new_id)
    gs_member_id: uuid.UUID  # once per meeting
    present: bool
    method: str = "manual"


class GsMeeting(Doc):
    """A Gram Sabha meeting: notice, place, agenda and the roll of members present."""

    COLLECTION = "gs_meeting"

    gram_sabha_id: uuid.UUID
    held_on: date
    place: str
    notice_on: date | None = None
    agenda: str
    registered_count: int  # active roster on the day
    created_by_user_id: uuid.UUID
    created_at: datetime = Field(default_factory=now_ms)
    attendance: list[Attendance] = Field(default_factory=list)


class Resolution(Doc):
    """
    A Gram Sabha resolution on a claim [Sec 6(1), Rule 12(1)(g)] (BR-03). Append-only and
    hash-chained; number unique per Gram Sabha. It stores the quorum arithmetic of the
    day. For a CFR claim it also approves the current boundary, which freezes it.
    """

    COLLECTION = "resolution"
    APPEND_ONLY = True

    gram_sabha_id: uuid.UUID
    meeting_id: uuid.UUID
    case_id: uuid.UUID
    number: str
    decision_text: str
    votes_for: int
    votes_against: int
    boundary_id: uuid.UUID | None = None
    quorum_proof: dict[str, Any]
    signed_scan_media_id: uuid.UUID | None = None
    supersedes_id: uuid.UUID | None = None
    correction_reason: str | None = None
    created_by_user_id: uuid.UUID
    created_at: datetime = Field(default_factory=now_ms)


class TitleFollowup(Doc):
    """
    After the title is issued: the certified copy of the title [Rule 8(i)], the survey
    request, and the entry in the record of rights [Rule 12A(9)]. One per case. A case
    cannot be closed without the certified copy and the record entry (BR-13).
    """

    COLLECTION = "title_followup"

    case_id: uuid.UUID
    certified_copy_media_id: uuid.UUID | None = None
    certified_copy_on: date | None = None
    survey_letter_id: uuid.UUID | None = None
    survey_done_on: date | None = None
    record_entry_on: date | None = None
    record_entry_ref: str | None = None
    record_entry_media_id: uuid.UUID | None = None
    closed_on: date | None = None
    updated_by_user_id: uuid.UUID
    updated_at: datetime = Field(default_factory=now_ms)
