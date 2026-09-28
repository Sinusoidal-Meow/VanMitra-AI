"""End-to-end auth against the test database (see tests/db/conftest.py)."""

import uuid
from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session, sessionmaker

from app.auth.security import hash_pin
from app.models import AppUser, Role, UserRole

from .conftest import TEST_PIN, make_village


@pytest.fixture(scope="module")
def seeded(session_factory: sessionmaker[Session]) -> dict[str, uuid.UUID]:
    with session_factory() as db:
        village = make_village(db, "AuthVillage")
        user = AppUser(phone="9100000002", name="FRC Test", pin_hash=hash_pin(TEST_PIN))
        inactive = AppUser(
            phone="9100000009", name="Gone", pin_hash=hash_pin(TEST_PIN), is_active=False
        )
        db.add_all([user, inactive])
        db.flush()
        db.add_all(
            [
                UserRole(user_id=user.id, village_id=village.id, role=Role.FRC_MEMBER),
                UserRole(  # expired grant: must not appear in /me
                    user_id=user.id,
                    village_id=village.id,
                    role=Role.GS_SECRETARY,
                    valid_from=date.today() - timedelta(days=400),
                    valid_to=date.today() - timedelta(days=30),
                ),
            ]
        )
        db.commit()
        return {"village": village.id, "user": user.id}


def _login(client: TestClient, phone: str = "9100000002", pin: str = TEST_PIN):  # type: ignore[no-untyped-def]
    return client.post("/api/v1/auth/login", json={"phone": phone, "pin": pin})


def test_login_and_me(db_client: TestClient, seeded: dict[str, uuid.UUID]) -> None:
    res = _login(db_client)
    assert res.status_code == 200, res.text
    tokens = res.json()
    me = db_client.get("/api/v1/me", headers={"Authorization": f"Bearer {tokens['access_token']}"})
    assert me.status_code == 200, me.text
    body = me.json()
    assert body["id"] == str(seeded["user"])
    assert [(r["village_id"], r["role"]) for r in body["roles"]] == [
        (str(seeded["village"]), "frc_member")
    ]


def test_wrong_pin_and_unknown_phone_look_the_same(
    db_client: TestClient, seeded: dict[str, uuid.UUID]
) -> None:
    wrong_pin = _login(db_client, pin="000000")
    unknown = _login(db_client, phone="9999999999")
    assert wrong_pin.status_code == unknown.status_code == 401
    assert wrong_pin.json() == unknown.json()


def test_inactive_user_cannot_log_in(db_client: TestClient, seeded: dict[str, uuid.UUID]) -> None:
    assert _login(db_client, phone="9100000009").status_code == 401


def test_refresh_issues_new_pair(db_client: TestClient, seeded: dict[str, uuid.UUID]) -> None:
    refresh_token = _login(db_client).json()["refresh_token"]
    res = db_client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert res.status_code == 200
    assert res.json()["access_token"]


def test_access_token_rejected_by_refresh(
    db_client: TestClient, seeded: dict[str, uuid.UUID]
) -> None:
    access = _login(db_client).json()["access_token"]
    res = db_client.post("/api/v1/auth/refresh", json={"refresh_token": access})
    assert res.status_code == 401
