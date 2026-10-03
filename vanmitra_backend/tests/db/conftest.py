"""
Fixtures for tests against a real PostgreSQL + PostGIS database.

Every test here is skipped unless VANMITRA_TEST_DATABASE_URL points at a THROWAWAY
database: the session fixture migrates it up once, and back down to empty at the end.
"""

import os
import uuid
from collections.abc import Iterator
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
TEST_PIN = "123456"


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        if "tests/db/" in item.nodeid.replace("\\", "/"):
            item.add_marker(pytest.mark.db)
            if not TEST_DB_URL:
                item.add_marker(pytest.mark.skip(reason="VANMITRA_TEST_DATABASE_URL not set"))


@pytest.fixture(scope="session")
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


@pytest.fixture
def db_client(session_factory: sessionmaker[Session]) -> TestClient:
    app = create_app()

    def _get_db() -> Iterator[Session]:
        with session_factory() as s:
            yield s

    app.dependency_overrides[get_db] = _get_db
    return TestClient(app)


def make_village(
    db: Session, name_en: str, taluka: str = "Jawhar", district: str = "Palghar"
) -> Village:
    village = Village(
        name_mr=name_en,
        name_en=name_en,
        gram_panchayat=name_en,
        taluka=taluka,
        district=district,
        state="Maharashtra",
    )
    db.add(village)
    db.flush()
    db.add(GramSabha(village_id=village.id))
    db.flush()
    return village


def make_user(
    db: Session,
    phone: str,
    role: Role | None,
    *,
    village: Village | None = None,
    taluka: str | None = None,
    district: str | None = None,
) -> AppUser:
    """A user with one role. role=None makes an admin."""
    user = AppUser(
        phone=phone, name=f"User {phone}", pin_hash=hash_pin(TEST_PIN), is_admin=role is None
    )
    db.add(user)
    db.flush()
    if role is not None:
        db.add(
            UserRole(
                user_id=user.id,
                role=role,
                village_id=village.id if village else None,
                taluka=taluka,
                district=district,
            )
        )
        db.flush()
    return user


def auth_headers(client: TestClient, phone: str) -> dict[str, str]:
    res = client.post("/api/v1/auth/login", json={"phone": phone, "pin": TEST_PIN})
    assert res.status_code == 200, res.text
    return {"Authorization": f"Bearer {res.json()['access_token']}"}


def new_case(client: TestClient, village_id: uuid.UUID, phone: str, claim_type: str) -> str:
    res = client.post(
        f"/api/v1/villages/{village_id}/cases",
        json={"claim_type": claim_type},
        headers=auth_headers(client, phone),
    )
    assert res.status_code == 201, res.text
    return str(res.json()["id"])
