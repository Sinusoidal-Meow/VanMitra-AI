"""
The statutory procedure around a claim (BACKEND_PLAN.md §3): the Forest Rights
Committee, claimants per case, and (in later sections of this module) the claim
call, evidence ledger, boundary, verification, meetings and resolutions.
"""

import uuid
from datetime import date, datetime
from typing import Any

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, IdMixin, TimestampMixin
from .enums import EvidenceKind, EvidenceRule, LetterTemplate
from .people import GsMember, pg_enum


class Frc(IdMixin, TimestampMixin, Base):
    """
    A Forest Rights Committee constituted by the Gram Sabha [Rule 3]. A new
    constitution supersedes the previous one (is_current); history is kept.
    """

    __tablename__ = "frc"

    gram_sabha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gram_sabha.id"), index=True)
    constituted_on: Mapped[date] = mapped_column(Date)
    # Gram Sabha resolution that elected the FRC (number / date, as written on paper).
    resolution_ref: Mapped[str | None] = mapped_column(String(200))
    # Rule 3(1): the chairperson and secretary are intimated to the SDLC.
    sdlc_intimated_on: Mapped[date | None] = mapped_column(Date)
    # The arithmetic as it was on the day (members, ST, women, required), never recomputed.
    composition_proof: Mapped[dict[str, Any]] = mapped_column(JSONB)
    is_current: Mapped[bool] = mapped_column(Boolean, default=True)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))

    members: Mapped[list["FrcMember"]] = relationship(
        back_populates="frc", cascade="all, delete-orphan"
    )


class FrcMember(IdMixin, Base):
    __tablename__ = "frc_member"
    __table_args__ = (UniqueConstraint("frc_id", "gs_member_id", name="uq_frc_member_member"),)

    frc_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("frc.id"), index=True)
    gs_member_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gs_member.id"))
    is_chair: Mapped[bool] = mapped_column(Boolean, default=False)
    is_secretary: Mapped[bool] = mapped_column(Boolean, default=False)

    frc: Mapped[Frc] = relationship(back_populates="members")
    member: Mapped[GsMember] = relationship()


class CaseClaimant(IdMixin, Base):
    """
    Gram Sabha members who are claimants in a case. Drives recusal [Rule 3(3)], the
    elder-statement block [Rule 13(1)(i)] and quorum test 3 [Rule 4(2)].
    """

    __tablename__ = "case_claimant"
    __table_args__ = (UniqueConstraint("case_id", "gs_member_id", name="uq_case_claimant_member"),)

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    gs_member_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gs_member.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    member: Mapped[GsMember] = relationship()


class Recusal(IdMixin, Base):
    """An FRC member stepping away from verifying a claim they are party to [Rule 3(3)]."""

    __tablename__ = "recusal"
    __table_args__ = (UniqueConstraint("case_id", "gs_member_id", name="uq_recusal_member"),)

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    gs_member_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gs_member.id"))
    reason: Mapped[str] = mapped_column(Text)
    recorded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ClaimCall(IdMixin, TimestampMixin, Base):
    """
    The call for claims by the Gram Sabha [Rule 11(1)(a)]: a three-month window,
    extendable only with written reasons and a resolution; and the date fixed for
    initiating the determination of the community forest resource [Rule 11(1)(b)].
    """

    __tablename__ = "claim_call"

    gram_sabha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gram_sabha.id"), index=True)
    called_on: Mapped[date] = mapped_column(Date)
    window_ends_on: Mapped[date] = mapped_column(Date)
    place_of_filing: Mapped[str] = mapped_column(String(300))
    notice_displayed_on: Mapped[date | None] = mapped_column(Date)
    cfr_determination_on: Mapped[date | None] = mapped_column(Date)
    extended_to: Mapped[date | None] = mapped_column(Date)
    extension_reason: Mapped[str | None] = mapped_column(Text)
    extension_resolution_ref: Mapped[str | None] = mapped_column(String(200))
    is_current: Mapped[bool] = mapped_column(Boolean, default=True)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))

    @property
    def closes_on(self) -> date:
        return self.extended_to or self.window_ends_on


class Media(IdMixin, Base):
    """An uploaded file (scan, photo, audio). The bytes live in storage, keyed by sha256."""

    __tablename__ = "media"

    sha256: Mapped[str] = mapped_column(String(64), index=True)
    mime: Mapped[str] = mapped_column(String(100))
    size_bytes: Mapped[int] = mapped_column(Integer)
    original_name: Mapped[str | None] = mapped_column(String(300))
    storage_key: Mapped[str] = mapped_column(String(300))
    uploaded_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))
    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    gps_lat: Mapped[float | None] = mapped_column(Float)
    gps_lon: Mapped[float | None] = mapped_column(Float)
    gps_accuracy_m: Mapped[float | None] = mapped_column(Float)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Evidence(IdMixin, Base):
    """
    The evidence ledger (append-only, hash-chained). Every item is tagged with its
    Rule 13 sub-clause. A correction is a new row that supersedes the old one.
    """

    __tablename__ = "evidence"

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    rule_ref: Mapped[EvidenceRule] = mapped_column(pg_enum(EvidenceRule, "evidence_rule"))
    kind: Mapped[EvidenceKind] = mapped_column(pg_enum(EvidenceKind, "evidence_kind"))
    description: Mapped[str] = mapped_column(Text)
    media_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("media.id"))
    source_office: Mapped[str | None] = mapped_column(String(200))
    ref_no: Mapped[str | None] = mapped_column(String(100))
    doc_date: Mapped[date | None] = mapped_column(Date)
    gps_lat: Mapped[float | None] = mapped_column(Float)
    gps_lon: Mapped[float | None] = mapped_column(Float)
    gps_accuracy_m: Mapped[float | None] = mapped_column(Float)
    is_substitutable: Mapped[bool] = mapped_column(Boolean)
    # Rule 13(1)(i): the elder (not a claimant), the transcript, the signed sheet.
    elder_member_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("gs_member.id"))
    transcript: Mapped[str | None] = mapped_column(Text)
    signed_scan_media_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("media.id"))
    supersedes_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("evidence.id"))
    correction_reason: Mapped[str | None] = mapped_column(Text)
    added_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class EvidenceVerification(IdMixin, Base):
    """The FRC / Gram Sabha attesting an evidence item (append-only, hash-chained)."""

    __tablename__ = "evidence_verification"

    evidence_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("evidence.id"), index=True)
    verified_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))
    verified_by_name: Mapped[str] = mapped_column(String(200))
    remarks: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class LedgerEntry(IdMixin, Base):
    """
    One link of the hash chain of a Gram Sabha (Spec 6.8):
        record_hash(n) = SHA256( canonical_json(payload(n)) || record_hash(n-1) )
    """

    __tablename__ = "ledger_entry"
    __table_args__ = (UniqueConstraint("gram_sabha_id", "seq", name="uq_ledger_entry_seq"),)

    gram_sabha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gram_sabha.id"), index=True)
    seq: Mapped[int] = mapped_column(Integer)
    entity: Mapped[str] = mapped_column(String(50))
    entity_id: Mapped[uuid.UUID] = mapped_column()
    prev_hash: Mapped[str] = mapped_column(String(64))
    record_hash: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Correspondence(IdMixin, TimestampMixin, Base):
    """
    A tracked outgoing letter (G2 intimations, G5/G6 requests, G7 site-visit notice,
    G18 survey request): addressee, dispatch, reminder, response.
    """

    __tablename__ = "correspondence"

    gram_sabha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gram_sabha.id"), index=True)
    case_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("claim_case.id"), index=True)
    template: Mapped[LetterTemplate] = mapped_column(pg_enum(LetterTemplate, "letter_template"))
    addressee: Mapped[str] = mapped_column(String(300))
    subject: Mapped[str] = mapped_column(String(300))
    body: Mapped[str | None] = mapped_column(Text)
    neighbour_village: Mapped[str | None] = mapped_column(String(200))  # G2 adjoining GS
    records_requested: Mapped[list[str]] = mapped_column(
        ARRAY(String(300)), server_default=text("'{}'")
    )
    dispatched_on: Mapped[date | None] = mapped_column(Date)
    reminder_on: Mapped[date | None] = mapped_column(Date)
    response_received_on: Mapped[date | None] = mapped_column(Date)
    outcome: Mapped[str | None] = mapped_column(Text)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))


class VerificationProceeding(IdMixin, Base):
    """
    The site visit with the Forest and Revenue officials [Rule 12(1), 12A(1)(2)] (BR-07).
    Append-only and hash-chained; a repeat visit is a new row with the next attempt_no.
    Each department either signed or its absence is recorded against an intimation.
    """

    __tablename__ = "verification_proceeding"
    __table_args__ = (UniqueConstraint("case_id", "attempt_no", name="uq_verification_attempt"),)

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    attempt_no: Mapped[int] = mapped_column(Integer)
    visit_on: Mapped[date] = mapped_column(Date)
    intimation_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("correspondence.id"))
    observations: Mapped[str] = mapped_column(Text)
    # [{"name", "designation", "department": "forest" | "revenue" | "frc" | "other"}]
    presence: Mapped[list[dict[str, Any]]] = mapped_column(JSONB)
    forest_signed: Mapped[bool] = mapped_column(Boolean)
    forest_absence_recorded: Mapped[bool] = mapped_column(Boolean)
    revenue_signed: Mapped[bool] = mapped_column(Boolean)
    revenue_absence_recorded: Mapped[bool] = mapped_column(Boolean)
    signed_scan_media_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("media.id"))
    recorded_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class GsMeeting(IdMixin, Base):
    """A Gram Sabha meeting: notice, place, agenda and the roll of members present."""

    __tablename__ = "gs_meeting"

    gram_sabha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gram_sabha.id"), index=True)
    held_on: Mapped[date] = mapped_column(Date)
    place: Mapped[str] = mapped_column(String(300))
    notice_on: Mapped[date | None] = mapped_column(Date)
    agenda: Mapped[str] = mapped_column(Text)
    registered_count: Mapped[int] = mapped_column(Integer)  # active roster on the day
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    attendance: Mapped[list["Attendance"]] = relationship(cascade="all, delete-orphan")


class Attendance(IdMixin, Base):
    """The manual attendance register is the legal record (face match is only a helper)."""

    __tablename__ = "attendance"
    __table_args__ = (UniqueConstraint("meeting_id", "gs_member_id", name="uq_attendance_member"),)

    meeting_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gs_meeting.id"), index=True)
    gs_member_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gs_member.id"))
    present: Mapped[bool] = mapped_column(Boolean)
    method: Mapped[str] = mapped_column(String(20), default="manual")


class Resolution(IdMixin, Base):
    """
    A Gram Sabha resolution on a claim [Sec 6(1), Rule 12(1)(g)] (BR-03). Append-only and
    hash-chained. It stores the quorum arithmetic of the day. For a CFR claim it also
    approves the current boundary, which freezes it.
    """

    __tablename__ = "resolution"
    __table_args__ = (UniqueConstraint("gram_sabha_id", "number", name="uq_resolution_number"),)

    gram_sabha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gram_sabha.id"), index=True)
    meeting_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gs_meeting.id"), index=True)
    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    number: Mapped[str] = mapped_column(String(40))
    decision_text: Mapped[str] = mapped_column(Text)
    votes_for: Mapped[int] = mapped_column(Integer)
    votes_against: Mapped[int] = mapped_column(Integer)
    boundary_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("cfr_boundary.id"))
    quorum_proof: Mapped[dict[str, Any]] = mapped_column(JSONB)
    signed_scan_media_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("media.id"))
    supersedes_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("resolution.id"))
    correction_reason: Mapped[str | None] = mapped_column(Text)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class TitleFollowup(IdMixin, Base):
    """
    After the title is issued: the certified copy of the title [Rule 8(i)], the survey
    request, and the entry in the record of rights [Rule 12A(9)]. A case cannot be
    closed without the certified copy and the record entry (BR-13).
    """

    __tablename__ = "title_followup"

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), unique=True)
    certified_copy_media_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("media.id"))
    certified_copy_on: Mapped[date | None] = mapped_column(Date)
    survey_letter_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("correspondence.id"))
    survey_done_on: Mapped[date | None] = mapped_column(Date)
    record_entry_on: Mapped[date | None] = mapped_column(Date)
    record_entry_ref: Mapped[str | None] = mapped_column(String(200))
    record_entry_media_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("media.id"))
    closed_on: Mapped[date | None] = mapped_column(Date)
    updated_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
