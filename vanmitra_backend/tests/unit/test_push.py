"""Push message wording and shape (no database, no Firebase)."""

import uuid

from app.models.notifications import DeviceToken, Notification
from app.services.push import fcm_payload, message_for

NOTE = Notification(
    user_id=uuid.uuid4(),
    case_id=uuid.uuid4(),
    kind="claim_expired",
    title_en="Claim closed",
    body_en="Please file a new claim.",
    title_mr="दावा बंद",
    body_mr="कृपया नवीन दावा दाखल करा.",
)


def _device(language: str) -> DeviceToken:
    return DeviceToken(user_id=NOTE.user_id, token="t" * 40, language=language)


def test_marathi_by_default_english_when_asked() -> None:
    assert message_for(_device("mr"), NOTE).title == "दावा बंद"
    english = message_for(_device("en"), NOTE)
    assert (english.title, english.body) == ("Claim closed", "Please file a new claim.")


def test_payload_carries_the_claim_for_the_app() -> None:
    payload = fcm_payload(message_for(_device("mr"), NOTE))["message"]
    assert payload["token"] == "t" * 40
    assert payload["notification"]["body"] == "कृपया नवीन दावा दाखल करा."
    assert payload["data"] == {
        "notification_id": str(NOTE.id),
        "case_id": str(NOTE.case_id),
        "kind": "claim_expired",
    }
    assert all(isinstance(v, str) for v in payload["data"].values())  # FCM needs strings
