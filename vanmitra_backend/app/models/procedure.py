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
    ForeignKey,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, IdMixin, TimestampMixin
from .people import GsMember


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
