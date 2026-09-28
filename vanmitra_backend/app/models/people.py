"""Village, Gram Sabha, members and app users (Stage 0)."""

import uuid
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, IdMixin, TimestampMixin
from .enums import ConsolidationStatus, Gender, MemberCategory, Role


def _pg_enum(enum_cls: type, name: str) -> Enum:
    """Store the enum's lowercase values, not its Python names."""
    return Enum(enum_cls, name=name, values_callable=lambda e: [m.value for m in e])


class Village(IdMixin, TimestampMixin, Base):
    """Village or hamlet. Hamlets point at their parent village [Rule 2A]."""

    __tablename__ = "village"

    lgd_code: Mapped[str | None] = mapped_column(String(20), unique=True)
    name_mr: Mapped[str] = mapped_column(String(200))
    name_en: Mapped[str] = mapped_column(String(200))
    gram_panchayat: Mapped[str] = mapped_column(String(200))
    taluka: Mapped[str] = mapped_column(String(100))  # drives the SDLC jurisdiction
    district: Mapped[str] = mapped_column(String(100))  # drives the DLC jurisdiction
    state: Mapped[str] = mapped_column(String(100), default="Maharashtra")
    parent_village_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("village.id"))
    consolidation_status: Mapped[ConsolidationStatus] = mapped_column(
        _pg_enum(ConsolidationStatus, "consolidation_status"),
        default=ConsolidationStatus.RECOGNISED,
    )

    parent: Mapped["Village | None"] = relationship(remote_side="Village.id")
    gram_sabha: Mapped["GramSabha | None"] = relationship(back_populates="village")


class GramSabha(IdMixin, TimestampMixin, Base):
    """The Gram Sabha of a village: owner of the CFR claim [Sec 6(1)]."""

    __tablename__ = "gram_sabha"

    village_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("village.id"), unique=True)
    # Head of this Gram Sabha's hash chain (PROJECT_PLAN rule R8). Set from Stage 2.
    chain_head_hash: Mapped[str | None] = mapped_column(String(64))

    village: Mapped[Village] = relationship(back_populates="gram_sabha")
    members: Mapped[list["GsMember"]] = relationship(back_populates="gram_sabha")


class GsMember(IdMixin, TimestampMixin, Base):
    """
    Gram Sabha member. Gender and category feed three legal computations:
    FRC composition [Rule 3(1)], quorum [Rule 4(2)] and the Form C member sheet.
    Whether a member is a claimant is per case (case_claimant, Stage 2).
    """

    __tablename__ = "gs_member"

    gram_sabha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gram_sabha.id"), index=True)
    name: Mapped[str] = mapped_column(String(200))
    gender: Mapped[Gender] = mapped_column(_pg_enum(Gender, "gender"))
    category: Mapped[MemberCategory] = mapped_column(_pg_enum(MemberCategory, "member_category"))
    active: Mapped[bool] = mapped_column(Boolean, default=True)

    gram_sabha: Mapped[GramSabha] = relationship(back_populates="members")


class AppUser(IdMixin, TimestampMixin, Base):
    """A person who logs in. Roles are per village, in user_role."""

    __tablename__ = "app_user"

    phone: Mapped[str] = mapped_column(String(15), unique=True)
    pin_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(200))
    gs_member_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("gs_member.id"))
    # Back-office implementation team only; grants no access to case content.
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    roles: Mapped[list["UserRole"]] = relationship(back_populates="user")


class UserRole(IdMixin, Base):
    """A role held by a user in one village, with validity dates (transfers keep history)."""

    __tablename__ = "user_role"
    __table_args__ = (
        UniqueConstraint("user_id", "village_id", "role", "valid_from", name="uq_user_role_grant"),
        CheckConstraint("valid_to IS NULL OR valid_to >= valid_from", name="valid_range"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"), index=True)
    village_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("village.id"), index=True)
    role: Mapped[Role] = mapped_column(_pg_enum(Role, "app_role"))
    valid_from: Mapped[date] = mapped_column(Date, server_default=func.current_date())
    valid_to: Mapped[date | None] = mapped_column(Date)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[AppUser] = relationship(back_populates="roles")
    village: Mapped[Village] = relationship()

    def is_active_on(self, day: date) -> bool:
        return self.valid_from <= day and (self.valid_to is None or day <= self.valid_to)
