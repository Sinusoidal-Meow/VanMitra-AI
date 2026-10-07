"""
Claims sent back and not resubmitted within 60 days are closed as expired, and only the
villager and the village's Gram Sabha are notified, inside the app. Against the test
database. The tests run in order.
"""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.orm import Session, sessionmaker

from app.models import Role
from app.services.expiry import expire_overdue

from .conftest import auth_headers, make_user, make_village, new_case

VILLAGER, GS, GS_2, SDO, OTHER_GS = (
    "9200000001",
    "9200000002",
    "9200000003",
    "9200000004",
    "9200000005",
)
FORM_A: dict[str, Any] = {
    "claimant_names": ["Ramu Bhoye"],
    "is_scheduled_tribe": True,
    "claims": {"habitation": {"extent_ha": 0.05, "details": "House plot"}},
}


@pytest.fixture(scope="module")
def ctx(session_factory: sessionmaker[Session]) -> dict[str, Any]:
    with session_factory() as db:
        village = make_village(db, "ExpiryVillage")
        other = make_village(db, "ExpiryOther")
        make_user(db, VILLAGER, Role.VILLAGER, village=village)
        make_user(db, GS, Role.GRAM_SABHA, village=village)
        make_user(db, GS_2, Role.GRAM_SABHA, village=village)
        make_user(db, SDO, Role.SDO, taluka="Jawhar", district="Palghar")
        make_user(db, OTHER_GS, Role.GRAM_SABHA, village=other)
        db.commit()
        return {"village": village.id}


def _h(client: TestClient, phone: str) -> dict[str, str]:
    return auth_headers(client, phone)


def _sent_back(client: TestClient, village_id: uuid.UUID) -> str:
    case_id = new_case(client, village_id, VILLAGER, "ifr")
    client.put(f"/api/v1/cases/{case_id}/form-a", json=FORM_A, headers=_h(client, VILLAGER))
    assert (
        client.post(f"/api/v1/cases/{case_id}/submit", headers=_h(client, VILLAGER)).status_code
        == 200
    )
    back = client.post(
        f"/api/v1/cases/{case_id}/return",
        json={"remarks": "Photos are missing"},
        headers=_h(client, GS),
    )
    assert back.json()["state"] == "draft"
    return case_id


def _age(session_factory: sessionmaker[Session], case_id: str, days: int) -> None:
    """Move a claim's history `days` into the past (the history is append-only, so the
    guard is lifted for this one change in the throwaway test database)."""
    with session_factory() as db:
        db.execute(text("ALTER TABLE workflow_event DISABLE TRIGGER workflow_event_append_only"))
        db.execute(
            text(
                "UPDATE workflow_event SET created_at = created_at - make_interval(days => :d) "
                "WHERE case_id = :c"
            ),
            {"d": days, "c": case_id},
        )
        db.execute(text("ALTER TABLE workflow_event ENABLE TRIGGER workflow_event_append_only"))
        db.commit()


def _inbox(client: TestClient, phone: str) -> Any:
    res = client.get("/api/v1/notifications", headers=_h(client, phone))
    assert res.status_code == 200, res.text
    return res.json()


def test_claim_expires_after_sixty_days(
    db_client: TestClient, ctx: dict[str, Any], session_factory: sessionmaker[Session]
) -> None:
    late = _sent_back(db_client, ctx["village"])
    in_time = _sent_back(db_client, ctx["village"])
    ctx["late"] = late
    _age(session_factory, late, 61)
    _age(session_factory, in_time, 59)

    with session_factory() as db:
        assert expire_overdue(db) >= 1  # other modules may leave old returned claims too
    with session_factory() as db:
        assert expire_overdue(db) == 0  # running again changes nothing

    seen = db_client.get(f"/api/v1/cases/{late}", headers=_h(db_client, VILLAGER)).json()
    assert seen["state"] == "expired" and seen["allowed_actions"] == []
    still = db_client.get(f"/api/v1/cases/{in_time}", headers=_h(db_client, VILLAGER)).json()
    assert still["state"] == "draft" and still["returned"]["days_left"] == 1

    history = db_client.get(f"/api/v1/cases/{late}/history", headers=_h(db_client, VILLAGER)).json()
    last = history[-1]
    assert (last["action"], last["to_state"]) == ("expire", "expired")
    assert last["actor_role"] is None and last["actor_name"] == "VanMitra (automatic)"
    resubmit = db_client.post(f"/api/v1/cases/{late}/submit", headers=_h(db_client, VILLAGER))
    assert resubmit.status_code == 409 and resubmit.json()["error"] == "CASE_CLOSED"


def test_only_the_villager_and_the_gram_sabha_are_told(
    db_client: TestClient, ctx: dict[str, Any]
) -> None:
    mine = _inbox(db_client, VILLAGER)
    assert mine["unread"] == 1
    [note] = mine["items"]
    assert note["kind"] == "claim_expired" and note["case_id"] == ctx["late"]
    assert "file a new claim" in note["body_en"] and "नवीन दावा" in note["body_mr"]

    for phone in (GS, GS_2):  # every Gram Sabha login of that village
        [gs_note] = _inbox(db_client, phone)["items"]
        assert "did nothing" in gs_note["body_en"]
    assert _inbox(db_client, SDO)["items"] == []
    assert _inbox(db_client, OTHER_GS)["items"] == []
    ctx["note"] = note["id"]


def test_reading_notifications(db_client: TestClient, ctx: dict[str, Any]) -> None:
    url = f"/api/v1/notifications/{ctx['note']}/read"
    assert db_client.post(url, headers=_h(db_client, GS)).status_code == 404  # not theirs
    read = db_client.post(url, headers=_h(db_client, VILLAGER))
    assert read.status_code == 200 and read.json()["read"] is True
    assert _inbox(db_client, VILLAGER)["unread"] == 0
    assert _inbox(db_client, GS)["unread"] == 1
    cleared = db_client.post("/api/v1/notifications/read-all", headers=_h(db_client, GS))
    assert cleared.json()["unread"] == 0


def test_gram_sabha_that_filed_its_own_claim_is_told_once(
    db_client: TestClient, ctx: dict[str, Any], session_factory: sessionmaker[Session]
) -> None:
    case_id = new_case(db_client, ctx["village"], GS, "cr")
    form_b = {"claimant_names": ["Ozhar community"], "rights": {"nistar": {"details": "Firewood"}}}
    db_client.put(f"/api/v1/cases/{case_id}/form-b", json=form_b, headers=_h(db_client, GS))
    assert (
        db_client.post(f"/api/v1/cases/{case_id}/submit", headers=_h(db_client, GS)).status_code
        == 200
    )
    db_client.post(
        f"/api/v1/cases/{case_id}/return",
        json={"remarks": "Map is missing"},
        headers=_h(db_client, GS),
    )
    before = len(_inbox(db_client, GS)["items"])
    _age(session_factory, case_id, 61)
    with session_factory() as db:
        assert expire_overdue(db) >= 1  # other modules may leave old returned claims too
    assert len(_inbox(db_client, GS)["items"]) == before + 1
