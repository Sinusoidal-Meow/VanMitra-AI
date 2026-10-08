"""
Phone push messages through Firebase Cloud Messaging (FCM, HTTP v1).

`deliver(db, notifications)` sends each in-app notification to every phone of its user,
in the language that phone asked for. It is called after the notifications are saved;
a push that fails is logged and never undoes anything (the message stays in the app).
Phones Firebase no longer knows (app removed, token expired) are forgotten.

Without VANMITRA_FCM_CREDENTIALS_FILE (the Firebase service-account key) nothing is sent.
"""

import logging
from collections.abc import Sequence
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

from ..config import get_settings
from ..db import Store
from ..models.notifications import DeviceToken, Notification

log = logging.getLogger(__name__)

SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
TIMEOUT_S = 10


@dataclass(frozen=True)
class PushMessage:
    token: str
    title: str
    body: str
    data: dict[str, str]


def message_for(device: DeviceToken, n: Notification) -> PushMessage:
    """The push for one phone: Marathi unless the phone asked for English."""
    english = device.language == "en"
    return PushMessage(
        token=device.token,
        title=n.title_en if english else n.title_mr,
        body=n.body_en if english else n.body_mr,
        data={
            "notification_id": str(n.id),
            "case_id": str(n.case_id) if n.case_id else "",
            "kind": n.kind,
        },
    )


def fcm_payload(msg: PushMessage) -> dict[str, Any]:
    return {
        "message": {
            "token": msg.token,
            "notification": {"title": msg.title, "body": msg.body},
            "data": msg.data,
            "android": {"priority": "high", "notification": {"channel_id": "vanmitra_claims"}},
        }
    }


@lru_cache
def _credentials() -> service_account.Credentials | None:
    path = get_settings().fcm_credentials_file
    if not path:
        return None
    creds: service_account.Credentials = service_account.Credentials.from_service_account_file(  # type: ignore[no-untyped-call]
        path, scopes=[SCOPE]
    )
    return creds


class _Sender:
    """Posts messages to FCM. Replaced in tests."""

    def __call__(self, msg: PushMessage) -> str:
        """'sent', 'gone' (token unknown to Firebase: forget it) or 'failed'."""
        creds = _credentials()
        if creds is None:
            return "failed"
        if not creds.valid:
            creds.refresh(Request())  # type: ignore[no-untyped-call]
        res = requests.post(
            f"https://fcm.googleapis.com/v1/projects/{creds.project_id}/messages:send",
            json=fcm_payload(msg),
            headers={"Authorization": f"Bearer {creds.token}"},
            timeout=TIMEOUT_S,
        )
        if res.ok:
            return "sent"
        if res.status_code == 404 or "UNREGISTERED" in res.text:
            return "gone"
        log.warning("push failed (%s): %s", res.status_code, res.text[:300])
        return "failed"


send = _Sender()


def enabled() -> bool:
    return bool(get_settings().fcm_credentials_file)


def deliver(db: Store, notifications: Sequence[Notification]) -> int:
    """Push each notification to its user's phones; returns how many pushes were sent."""
    if not notifications or not enabled():
        return 0
    sent = 0
    for n in notifications:
        for device in db.find(DeviceToken, {"user_id": n.user_id}):
            try:
                outcome = send(message_for(device, n))
            except Exception:  # noqa: BLE001 - a push never breaks the caller
                log.exception("push to a phone failed")
                continue
            if outcome == "sent":
                sent += 1
            elif outcome == "gone":
                db.delete(device)
    db.commit()
    return sent
