"""
The messages for the logged-in user, newest first, with how many are unread. Each has
its text in English and Marathi; the app shows the language the user chose.
"""

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter
from pydantic import BaseModel
from sqlalchemy import func, select

from ...auth.deps import CurrentUser, DbSession
from ...errors import ApiError
from ...models.notifications import Notification

router = APIRouter(tags=["notifications"])

MAX_LISTED = 100


class NotificationOut(BaseModel):
    id: uuid.UUID
    case_id: uuid.UUID | None
    kind: str
    title_en: str
    body_en: str
    title_mr: str
    body_mr: str
    created_at: datetime
    read: bool


class NotificationsOut(BaseModel):
    unread: int
    items: list[NotificationOut]


def _out(n: Notification) -> NotificationOut:
    return NotificationOut(
        id=n.id,
        case_id=n.case_id,
        kind=n.kind,
        title_en=n.title_en,
        body_en=n.body_en,
        title_mr=n.title_mr,
        body_mr=n.body_mr,
        created_at=n.created_at,
        read=n.read_at is not None,
    )


def _unread(db: DbSession, user_id: uuid.UUID) -> int:
    return (
        db.scalar(
            select(func.count())
            .select_from(Notification)
            .where(Notification.user_id == user_id, Notification.read_at.is_(None))
        )
        or 0
    )


@router.get("/notifications", response_model=NotificationsOut)
def my_notifications(db: DbSession, user: CurrentUser) -> NotificationsOut:
    rows = db.scalars(
        select(Notification)
        .where(Notification.user_id == user.id)
        .order_by(Notification.created_at.desc())
        .limit(MAX_LISTED)
    )
    return NotificationsOut(unread=_unread(db, user.id), items=[_out(n) for n in rows])


@router.post("/notifications/{notification_id}/read", response_model=NotificationOut)
def mark_read(notification_id: uuid.UUID, db: DbSession, user: CurrentUser) -> NotificationOut:
    n = db.get(Notification, notification_id)
    if n is None or n.user_id != user.id:
        raise ApiError(404, "NOTIFICATION_NOT_FOUND", "notification.not_found")
    if n.read_at is None:
        n.read_at = datetime.now(UTC)
        db.commit()
    return _out(n)


@router.post("/notifications/read-all", response_model=NotificationsOut)
def mark_all_read(db: DbSession, user: CurrentUser) -> NotificationsOut:
    now = datetime.now(UTC)
    for n in db.scalars(
        select(Notification).where(Notification.user_id == user.id, Notification.read_at.is_(None))
    ):
        n.read_at = now
    db.commit()
    return my_notifications(db, user)
