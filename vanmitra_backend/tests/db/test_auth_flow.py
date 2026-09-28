"""
End-to-end auth against a real PostgreSQL + PostGIS database.

Skipped unless VANMITRA_TEST_DATABASE_URL points at a THROWAWAY database: the
fixture runs every migration up, and back down to empty, around the tests.
CI provides one (.github/workflows/backend-ci.yml).
"""

import os
import uuid
from collections.abc import Iterator
from datetime import date, timedelta
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.auth.security import hash_pin
from app.db import get_db
from app.main import create_app
from app.models import AppUser, GramSabha, Role, UserRole, Village

TEST_DB_URL = os.environ.get("VANMITRA_TEST_DATABASE_URL")
BACKEND_DIR = Path(__file__).resolve().parents[2]

pytestmark = [
    pytest.mark.db,
    pytest.mark.skipif(not TEST_DB_URL, reason="VANMITRA_TEST_DATABASE_URL not set"),
]


@pytest.fixture(scope="module")
def session_factory() -> Iterator[sessionmaker[Session]]:
    assert TEST_DB_URL
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", TEST_DB_URL)
    command.upgrade(cfg, "head")
    engine = create_engine(TEST_DB_URL)
    try:
        yield sessionmaker(bind=engine, expire_on_commit=False)
    finally:
        engine.dispose()
        command.downgrade(cfg, "base")


@pytest.fixture(scope="module")
def seeded(session_factory: sessionmaker[Session]) -> dict[str, uuid.UUID]:
    with session_factory() as db:
        village = Village(
            name_mr="ओझर",
            name_en="Ozhar",
            gram_panchayat="Ozhar",
            taluka="Jawhar",
            district="Palghar",
            state="Maharashtra",
        )
        db.add(village)
        db.flush()
        db.add(GramSabha(village_id=village.id))
        user = AppUser(phone="9000000002", name="FRC Test", pin_hash=hash_pin("123456"))
        inactive = AppUser(
            phone="9000000009", name="Gone", pin_hash=hash_pin("123456"), is_active=False
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


@pytest.fixture
def db_client(session_factory: sessionmaker[Session]) -> TestClient:
    app = create_app()

    def _get_db() -> Iterator[Session]:
        with session_factory() as s:
            yield s

    app.dependency_overrides[get_db] = _get_db
    return TestClient(app)


def _login(client: TestClient, phone: str = "9000000002", pin: str = "123456"):  # type: ignore[no-untyped-def]
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
    assert _login(db_client, phone="9000000009").status_code == 401


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
