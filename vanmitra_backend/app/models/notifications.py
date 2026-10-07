"""
Messages shown to a user inside the app (and, later, sent as a phone push message).
Each is addressed to one user. The text is stored in English and Marathi as it was
written at the time.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base, IdMixin


class Notification(IdMixin, Base):
    __tablename__ = "notification"

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"), index=True)
    case_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("claim_case.id"), index=True)
    kind: Mapped[str] = mapped_column(String(40))  # e.g. "claim_expired"
    title_en: Mapped[str] = mapped_column(String(200))
    body_en: Mapped[str] = mapped_column(Text)
    title_mr: Mapped[str] = mapped_column(String(200))
    body_mr: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
