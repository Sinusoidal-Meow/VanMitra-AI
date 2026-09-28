"""Claim cases and the Form B draft (community rights)."""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, IdMixin, TimestampMixin
from .enums import CaseState, ClaimType, EvidenceRule, FormBRight
from .people import GramSabha, pg_enum


class ClaimCase(IdMixin, TimestampMixin, Base):
    """
    One claim. IFR, CR and CFR cases share this table (Spec §2.1), so cases in a
    village share the same Gram Sabha meeting, quorum record and evidence pool.
    Community (CR/CFR) cases are owned by the Gram Sabha, not an individual.
    """

    __tablename__ = "claim_case"

    gram_sabha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gram_sabha.id"), index=True)
    claim_type: Mapped[ClaimType] = mapped_column(pg_enum(ClaimType, "claim_type"))
    state: Mapped[CaseState] = mapped_column(
        pg_enum(CaseState, "case_state"), default=CaseState.DRAFT
    )
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))

    gram_sabha: Mapped[GramSabha] = relationship()
    form_b: Mapped["FormB | None"] = relationship(
        back_populates="case", cascade="all, delete-orphan", uselist=False
    )
    evidence_entries: Mapped[list["ClaimEvidenceEntry"]] = relationship(
        back_populates="case",
        cascade="all, delete-orphan",
        order_by="ClaimEvidenceEntry.seq",
    )


class FormB(TimestampMixin, Base):
    """The Form B draft for a CR case. Items 2-5 come from the village registry."""

    __tablename__ = "form_b"

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), primary_key=True)
    # Item 1. Empty while drafting; completeness reports it.
    claimant_names: Mapped[list[str]] = mapped_column(
        ARRAY(String(200)), server_default=text("'{}'")
    )
    # Items 1(a), 1(b). NULL = not answered yet.
    is_fdst_community: Mapped[bool | None] = mapped_column(Boolean)
    is_otfd_community: Mapped[bool | None] = mapped_column(Boolean)
    # Item 8.
    other_information: Mapped[str | None] = mapped_column(Text)
    updated_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))

    case: Mapped[ClaimCase] = relationship(back_populates="form_b")
    rights: Mapped[list["FormBRightClaim"]] = relationship(
        back_populates="form_b", cascade="all, delete-orphan"
    )


class FormBRightClaim(IdMixin, Base):
    """A claimed right from Form B "Nature of community rights enjoyed" (items 1-6).

    No row means the right is not claimed.
    """

    __tablename__ = "form_b_right"
    __table_args__ = (UniqueConstraint("case_id", "right_code", name="uq_form_b_right_code"),)

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("form_b.case_id"), index=True)
    right_code: Mapped[FormBRight] = mapped_column(pg_enum(FormBRight, "form_b_right_code"))
    # How the community enjoys the right, in the community's own words (any language).
    details: Mapped[str] = mapped_column(Text)
    # Optional named things: produce (mahua, tendu), ponds, grazing areas, local names.
    items: Mapped[list[str]] = mapped_column(ARRAY(String(200)), server_default=text("'{}'"))

    form_b: Mapped[FormB] = relationship(back_populates="rights")


class ClaimEvidenceEntry(IdMixin, Base):
    """
    A line of the form's "Evidence in support" list (Form B item 7 / Form C item 8),
    tagged with its Rule 13 sub-clause. The Stage 2 evidence ledger will link each
    entry to the captured, hash-chained artefact.
    """

    __tablename__ = "claim_evidence_entry"
    __table_args__ = (UniqueConstraint("case_id", "seq", name="uq_claim_evidence_entry_seq"),)

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    seq: Mapped[int] = mapped_column(Integer)  # 1-based order as printed
    rule_ref: Mapped[EvidenceRule] = mapped_column(pg_enum(EvidenceRule, "evidence_rule"))
    description: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    case: Mapped[ClaimCase] = relationship(back_populates="evidence_entries")
