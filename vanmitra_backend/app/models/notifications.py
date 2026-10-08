"""
Messages shown to a user inside the app (and, later, sent as a phone push message).
Each is addressed to one user. The text is stored in English and Marathi as it was
written at the time.
"""

import uuid
from datetime import datetime

from pydantic import Field

from .base import Doc, now_ms


class Notification(Doc):
    COLLECTION = "notification"

    user_id: uuid.UUID
    case_id: uuid.UUID | None = None
    kind: str  # e.g. "claim_expired"
    title_en: str
    body_en: str
    title_mr: str
    body_mr: str
    created_at: datetime = Field(default_factory=now_ms)
    read_at: datetime | None = None


class DeviceToken(Doc):
    """
    A phone that may receive push messages for a user (Firebase Cloud Messaging token).
    A token belongs to one user at a time; it moves if another user signs in on it.
    """

    COLLECTION = "device_token"

    user_id: uuid.UUID
    token: str  # unique
    platform: str = "android"  # android | ios | web
    language: str = "mr"  # which text the push messages are sent in: mr | en
    created_at: datetime = Field(default_factory=now_ms)
    updated_at: datetime = Field(default_factory=now_ms)
