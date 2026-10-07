"""
Fixtures for tests against a real MongoDB database.

Every test here is skipped unless VANMITRA_TEST_MONGODB_URI points at a THROWAWAY
database for integration tests.
"""

import os
import uuid
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.auth.security import hash_pin
from app.db import Store, ensure_indexes, get_client, get_db
from app.main import create_app
from app.models import AppUser, GramSabha, Role, UserRole, Village

TEST_MONGODB_URI = os.environ.get("VANMITRA_TEST_MONGODB_URI")
TEST_PIN = "123456"


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        if "tests/db/" in item.nodeid.replace("\\", "/"):
            item.add_marker(pytest.mark.db)
            if not TEST_MONGODB_URI:
                item.add_marker(pytest.mark.skip(reason="VANMITRA_TEST_MONGODB_URI not set"))


class _StoreMaker:
    def __init__(self, database):
        self._database = database

    def __call__(self) -> Store:
        return Store(self._database)


@pytest.fixture(scope="session")
def mongo_test_db():
    assert TEST_MONGODB_URI
    db_name = os.environ.get("VANMITRA_TEST_MONGODB_DB", "vanmitra_test")
    client = get_client()
    db = client[db_name]
    ensure_indexes(db)
    try:
        yield db
    finally:
        client.drop_database(db_name)


@pytest.fixture(scope="session")
def session_factory(mongo_test_db):
    yield _StoreMaker(mongo_test_db)


@pytest.fixture
def db_client(mongo_test_db) -> TestClient:
    app = create_app()

    def _get_db() -> Iterator[Store]:
        with Store(mongo_test_db) as s:
            yield s

    app.dependency_overrides[get_db] = _get_db
    return TestClient(app)


def make_village(
    db: Store, name_en: str, taluka: str = "Jawhar", district: str = "Palghar"
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
    db.add(GramSabha(village_id=village.id))
    db.commit()
    return village


def make_user(
    db: Store,
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
    db.commit()
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


_site = {"n": 0}


def complete_cfr_prerequisites(
    client: TestClient, village_id: uuid.UUID, phone: str, case_id: str
) -> None:
    """
    Do what the Gram Sabha must do before it may forward a CFR claim in `gs_review`: map
    and approve the boundary, close the field verification and pass the resolution.
    Only the public API is used. Each call places its boundary on fresh ground.
    """
    gs = auth_headers(client, phone)
    base = f"/api/v1/villages/{village_id}"
    for name, gender in (("Asha", "female"), ("Bhiwa", "male"), ("Chandra", "female")):
        client.post(
            f"{base}/members",
            json={"name": name, "gender": gender, "category": "st"},
            headers=gs,
        )
    roster = [m["id"] for m in client.get(f"{base}/members", headers=gs).json() if m["active"]]

    _site["n"] += 1
    x = 70.0 + _site["n"] * 0.05
    square = {
        "type": "Polygon",
        "coordinates": [[[x, 19.0], [x + 0.01, 19.0], [x + 0.01, 19.01], [x, 19.01]]],
    }
    res = client.post(f"/api/v1/cases/{case_id}/boundary", json={"polygon": square}, headers=gs)
    assert res.status_code == 201, res.text
    mark = {"segment_seq": 0, "kind": "stream", "name": "Nala", "lon": x, "lat": 19.0}
    assert (
        client.post(
            f"/api/v1/cases/{case_id}/boundary/landmarks", json=mark, headers=gs
        ).status_code
        == 201
    )

    media = client.post(
        "/api/v1/media",
        files={"file": ("sheet.pdf", b"%PDF-1.4 signed sheet", "application/pdf")},
        headers=gs,
    )
    assert media.status_code == 201, media.text
    ver = {
        "visit_on": "2026-09-01",
        "observations": "Boundary walked with the elders",
        "presence": [
            {"name": "RFO", "department": "forest"},
            {"name": "Talathi", "department": "revenue"},
        ],
        "forest_signed": True,
        "revenue_signed": True,
        "signed_scan_media_id": media.json()["id"],
    }
    res = client.post(f"/api/v1/cases/{case_id}/verification", json=ver, headers=gs)
    assert res.status_code == 201, res.text

    res = client.post(
        f"{base}/meetings",
        json={"held_on": "2026-09-10", "place": "Gram Panchayat", "agenda": "CFR claim"},
        headers=gs,
    )
    assert res.status_code == 201, res.text
    meeting = res.json()["id"]
    res = client.put(
        f"/api/v1/meetings/{meeting}/attendance", json={"present_member_ids": roster}, headers=gs
    )
    assert res.status_code == 200, res.text
    res = client.post(
        f"/api/v1/meetings/{meeting}/resolutions",
        json={
            "case_id": case_id,
            "decision_text": "Approved",
            "votes_for": len(roster),
            "votes_against": 0,
        },
        headers=gs,
    )
    assert res.status_code == 201, res.text
