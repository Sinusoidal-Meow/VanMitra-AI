"""
Fixtures for tests against a real PostgreSQL + PostGIS database.

Every test here is skipped unless VANMITRA_TEST_DATABASE_URL points at a THROWAWAY
database: the session fixture migrates it up once, and back down to empty at the end.
CI provides one (.github/workflows/backend-ci.yml).
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


def make_village(db: Session, name_en: str) -> Village:
    village = Village(
        name_mr=name_en,
        name_en=name_en,
        gram_panchayat=name_en,
        taluka="Jawhar",
        district="Palghar",
        state="Maharashtra",
    )
    db.add(village)
    db.flush()
    db.add(GramSabha(village_id=village.id))
    db.flush()
    return village


def make_user(db: Session, phone: str, grants: list[tuple[uuid.UUID, Role]]) -> AppUser:
    user = AppUser(phone=phone, name=f"User {phone}", pin_hash=hash_pin(TEST_PIN))
    db.add(user)
    db.flush()
    db.add_all(UserRole(user_id=user.id, village_id=v, role=r) for v, r in grants)
    db.flush()
    return user


def auth_headers(client: TestClient, phone: str) -> dict[str, str]:
    res = client.post("/api/v1/auth/login", json={"phone": phone, "pin": TEST_PIN})
    assert res.status_code == 200, res.text
    return {"Authorization": f"Bearer {res.json()['access_token']}"}
