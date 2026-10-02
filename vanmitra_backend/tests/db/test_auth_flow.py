"""Registration, login, /me with jurisdiction, admin-created officials."""

import uuid
from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session, sessionmaker

from app.auth.security import hash_pin
from app.models import AppUser, Role, UserRole

from .conftest import TEST_PIN, auth_headers, make_user, make_village


@pytest.fixture(scope="module")
def seeded(session_factory: sessionmaker[Session]) -> dict[str, uuid.UUID]:
    with session_factory() as db:
        village = make_village(db, "AuthVillage")
        user = AppUser(phone="9100000002", name="GS Test", pin_hash=hash_pin(TEST_PIN))
        inactive = AppUser(
            phone="9100000009", name="Gone", pin_hash=hash_pin(TEST_PIN), is_active=False
        )
        db.add_all([user, inactive])
        db.flush()
        db.add_all(
            [
                UserRole(user_id=user.id, village_id=village.id, role=Role.GRAM_SABHA),
                UserRole(  # expired grant: must not appear in /me
                    user_id=user.id,
                    village_id=village.id,
                    role=Role.VILLAGER,
                    valid_from=date.today() - timedelta(days=400),
                    valid_to=date.today() - timedelta(days=30),
                ),
            ]
        )
        make_user(db, "9100000004", None)  # admin
        make_user(db, "9100000005", Role.SDO, taluka="Jawhar", district="Palghar")
        db.commit()
        return {"village": village.id, "user": user.id}


def _login(client: TestClient, phone: str = "9100000002", pin: str = TEST_PIN):  # type: ignore[no-untyped-def]
    return client.post("/api/v1/auth/login", json={"phone": phone, "pin": pin})


def test_login_and_me(db_client: TestClient, seeded: dict[str, uuid.UUID]) -> None:
    tokens = _login(db_client).json()
    me = db_client.get("/api/v1/me", headers={"Authorization": f"Bearer {tokens['access_token']}"})
    assert me.status_code == 200, me.text
    roles = me.json()["roles"]
    assert [(r["role"], r["level"], r["village_id"]) for r in roles] == [
        ("gram_sabha", "village", str(seeded["village"]))
    ]


def test_sdo_me_shows_taluka(db_client: TestClient, seeded: dict[str, uuid.UUID]) -> None:
    me = db_client.get("/api/v1/me", headers=auth_headers(db_client, "9100000005")).json()
    assert me["roles"][0]["level"] == "subdivision"
    assert (me["roles"][0]["taluka"], me["roles"][0]["district"]) == ("Jawhar", "Palghar")


def test_wrong_pin_and_unknown_phone_look_the_same(
    db_client: TestClient, seeded: dict[str, uuid.UUID]
) -> None:
    wrong_pin = _login(db_client, pin="000000")
    unknown = _login(db_client, phone="9999999999")
    assert wrong_pin.status_code == unknown.status_code == 401
    assert wrong_pin.json() == unknown.json()


def test_inactive_user_cannot_log_in(db_client: TestClient, seeded: dict[str, uuid.UUID]) -> None:
    assert _login(db_client, phone="9100000009").status_code == 401


def test_refresh(db_client: TestClient, seeded: dict[str, uuid.UUID]) -> None:
    tokens = _login(db_client).json()
    res = db_client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert res.status_code == 200
    bad = db_client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["access_token"]})
    assert bad.status_code == 401


def test_villager_registers_and_picks_village(
    db_client: TestClient, seeded: dict[str, uuid.UUID]
) -> None:
    villages = db_client.get("/api/v1/public/villages").json()
    assert str(seeded["village"]) in [v["id"] for v in villages]
    body = {
        "name": "New Claimant",
        "phone": "9100000020",
        "pin": "112233",
        "village_id": str(seeded["village"]),
    }
    res = db_client.post("/api/v1/auth/register", json=body)
    assert res.status_code == 201, res.text
    me = db_client.get(
        "/api/v1/me", headers={"Authorization": f"Bearer {res.json()['access_token']}"}
    ).json()
    assert [r["role"] for r in me["roles"]] == ["villager"]
    again = db_client.post("/api/v1/auth/register", json=body)
    assert again.status_code == 409


def test_register_needs_a_real_village(db_client: TestClient, seeded: dict[str, uuid.UUID]) -> None:
    res = db_client.post(
        "/api/v1/auth/register",
        json={"name": "X", "phone": "9100000021", "pin": "112233", "village_id": str(uuid.uuid4())},
    )
    assert res.status_code == 422


def test_admin_creates_officials_with_jurisdiction(
    db_client: TestClient, seeded: dict[str, uuid.UUID]
) -> None:
    admin = auth_headers(db_client, "9100000004")
    ok = db_client.post(
        "/api/v1/admin/users",
        json={"name": "DFO", "phone": "9100000030", "pin": "445566", "role": "dfo",
              "district": "Palghar"},
        headers=admin,
    )  # fmt: skip
    assert ok.status_code == 201, ok.text
    assert ok.json()["district"] == "Palghar"
    missing = db_client.post(
        "/api/v1/admin/users",
        json={"name": "SDO", "phone": "9100000031", "pin": "445566", "role": "sdo",
              "district": "Palghar"},
        headers=admin,
    )  # fmt: skip
    assert missing.status_code == 422
    assert missing.json()["error"] == "TALUKA_AND_DISTRICT_REQUIRED"
    not_admin = db_client.post(
        "/api/v1/admin/users",
        json={"name": "X", "phone": "9100000032", "pin": "445566", "role": "collector",
              "district": "Palghar"},
        headers=auth_headers(db_client, "9100000005"),
    )  # fmt: skip
    assert not_admin.status_code == 403
