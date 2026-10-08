"""Form C draft and member roster against the test database (see tests/db/conftest.py)."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import get_settings
from app.domain.form_c import DEFAULT_RESOLUTION_STATEMENT
from app.models import Gender, GramSabha, GsMember, MemberCategory, Role

from .conftest import StoreMaker, auth_headers, make_user, make_village, new_case

VILLAGER, GS, OUTSIDER = "9300000001", "9300000003", "9300000004"

FULL_FORM_C: dict[str, Any] = {
    "area_description": "Customary forest east and south of Ozar up to the Nagdevta stream",
    "approx_area_ha": 318.4,
    "landmarks": [
        {"side": "east", "kind": "stream", "name": "Nagdevta nala"},
        {"side": "west", "kind": "sacred_place", "name": "Waghoba devasthan"},
        {"side": "north", "kind": "road", "name": "Jawhar road"},
        {"side": "south", "kind": "pond", "name": "Mothe talav"},
        {"side": "within", "kind": "sacred_grove", "name": "Devrai"},
    ],
    "khasra_compartment_numbers": ["156", "157", "157"],
    "bordering_villages": [{"name": "Chambharshet", "shares_resources": True}],
    "evidence": [
        {"rule_ref": "13(1)(a)", "description": "7/12 extract, survey no. 110"},
        {"rule_ref": "13(1)(i)", "description": "Statement of elders (not claimants)"},
        {"rule_ref": "13(2)(a)", "description": "Nistar patrak of the village"},
    ],
}


@pytest.fixture(scope="module")
def villages(session_factory: StoreMaker) -> dict[str, uuid.UUID]:
    with session_factory() as db:
        ozar = make_village(db, "FormCVillage")
        other = make_village(db, "FormCOther")
        make_user(db, VILLAGER, Role.VILLAGER, village=ozar)
        make_user(db, GS, Role.GRAM_SABHA, village=ozar)
        make_user(db, OUTSIDER, Role.GRAM_SABHA, village=other)
        gs = db.find_one(GramSabha, {"village_id": ozar.id})
        assert gs is not None
        db.add_all(
            [
                GsMember(
                    gram_sabha_id=gs.id,
                    name="Seed ST",
                    gender=Gender.FEMALE,
                    category=MemberCategory.ST,
                    active=True,
                ),
                GsMember(
                    gram_sabha_id=gs.id,
                    name="Seed OTFD",
                    gender=Gender.MALE,
                    category=MemberCategory.OTFD,
                    active=True,
                ),
            ]
        )
        db.commit()
        return {"ozar": ozar.id, "other": other.id}


def test_only_the_gram_sabha_opens_form_c(
    db_client: TestClient, villages: dict[str, uuid.UUID], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(get_settings(), "villager_opens_form_c", False)
    res = db_client.post(
        f"/api/v1/villages/{villages['ozar']}/cases",
        json={"claim_type": "cfr"},
        headers=auth_headers(db_client, VILLAGER),
    )
    assert res.status_code == 403
    assert res.json()["error"] == "NOT_ALLOWED_TO_OPEN_FORM"


def test_village_user_opens_form_c_while_testing(
    db_client: TestClient, villages: dict[str, uuid.UUID], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(get_settings(), "villager_opens_form_c", True)
    res = db_client.post(
        f"/api/v1/villages/{villages['ozar']}/cases",
        json={"claim_type": "cfr"},
        headers=auth_headers(db_client, VILLAGER),
    )
    assert res.status_code == 201
    assert res.json()["claim_type"] == "cfr"


def test_roster_is_kept_by_the_gram_sabha(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    url = f"/api/v1/villages/{villages['ozar']}/members"
    gs = auth_headers(db_client, GS)
    member = {"name": "Sita", "gender": "female", "category": "st"}
    res = db_client.post(url, json=member, headers=gs)
    assert res.status_code == 201, res.text
    villager = auth_headers(db_client, VILLAGER)
    assert db_client.get(url, headers=villager).status_code == 200
    assert db_client.post(url, json=member, headers=villager).status_code == 403
    assert db_client.get(url, headers=auth_headers(db_client, OUTSIDER)).status_code == 403
    off = db_client.patch(f"/api/v1/members/{res.json()['id']}", json={"active": False}, headers=gs)
    assert off.json()["active"] is False


def test_gram_sabha_fills_form_c(db_client: TestClient, villages: dict[str, uuid.UUID]) -> None:
    case_id = new_case(db_client, villages["ozar"], GS, "cfr")
    headers = auth_headers(db_client, GS)
    fresh = db_client.get(f"/api/v1/cases/{case_id}/form-c", headers=headers).json()
    assert fresh["resolution_statement"] == DEFAULT_RESOLUTION_STATEMENT
    assert fresh["member_sheet"]["st"] >= 1 and fresh["member_sheet"]["otfd"] >= 1
    for _ in range(2):  # re-saving must not trip the (case_id, seq) constraints
        res = db_client.put(f"/api/v1/cases/{case_id}/form-c", json=FULL_FORM_C, headers=headers)
        assert res.status_code == 200, res.text
    form = res.json()
    assert form["khasra_compartment_numbers"] == ["156", "157"]
    assert form["completeness"]["done"] == form["completeness"]["total"] == 8


def test_blank_statement_falls_back_to_the_printed_one(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = new_case(db_client, villages["ozar"], GS, "cfr")
    res = db_client.put(
        f"/api/v1/cases/{case_id}/form-c",
        json={"resolution_statement": None},
        headers=auth_headers(db_client, GS),
    )
    assert res.json()["resolution_statement"] == DEFAULT_RESOLUTION_STATEMENT
