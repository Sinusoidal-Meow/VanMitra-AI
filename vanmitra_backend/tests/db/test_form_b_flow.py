"""Form B draft against the test database (see tests/db/conftest.py)."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session, sessionmaker

from app.models import Role

from .conftest import auth_headers, make_user, make_village, new_case

VILLAGER, VILLAGER2, GS, OUTSIDER = "9200000001", "9200000002", "9200000003", "9200000004"

FULL_FORM_B: dict[str, Any] = {
    "claimant_names": ["Ozhar Gram Sabha"],
    "is_fdst_community": True,
    "is_otfd_community": False,
    "rights": {
        # Given out of order on purpose: the response must follow the printed form.
        "grazing": {"details": "Cattle grazed on the eastern slope, Jun-Sep", "items": ["Gairan"]},
        "nistar": {"details": "Firewood and bamboo for houses", "items": []},
        "minor_forest_produce": {"details": "Mahua flowers and tendu leaves", "items": ["mahua"]},
    },
    "evidence": [
        {"rule_ref": "13(1)(a)", "description": "Nistar patrak, Revenue Dept."},
        {"rule_ref": "13(1)(i)", "description": "Statement of elder Shri K. (not a claimant)"},
    ],
    "other_information": "Shared grazing with the neighbouring village.",
}


@pytest.fixture(scope="module")
def villages(session_factory: sessionmaker[Session]) -> dict[str, uuid.UUID]:
    with session_factory() as db:
        ozhar = make_village(db, "FormBVillage")
        other = make_village(db, "OtherVillage")
        make_user(db, VILLAGER, Role.VILLAGER, village=ozhar)
        make_user(db, VILLAGER2, Role.VILLAGER, village=ozhar)
        make_user(db, GS, Role.GRAM_SABHA, village=ozhar)
        make_user(db, OUTSIDER, Role.GRAM_SABHA, village=other)
        db.commit()
        return {"ozhar": ozhar.id, "other": other.id}


def test_new_form_b_is_empty_with_header_from_registry(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = new_case(db_client, villages["ozhar"], VILLAGER, "cr")
    res = db_client.get(
        f"/api/v1/cases/{case_id}/form-b", headers=auth_headers(db_client, VILLAGER)
    )
    assert res.status_code == 200, res.text
    form = res.json()
    assert form["editable"] is True
    assert form["header"]["taluka"] == "Jawhar"
    assert [r["code"] for r in form["rights"]][:2] == ["nistar", "minor_forest_produce"]
    assert (form["completeness"]["done"], form["completeness"]["total"]) == (1, 5)


def test_claimant_fills_form_b_twice(db_client: TestClient, villages: dict[str, uuid.UUID]) -> None:
    case_id = new_case(db_client, villages["ozhar"], VILLAGER, "cr")
    headers = auth_headers(db_client, VILLAGER)
    for _ in range(2):  # re-saving must not trip the unique constraints
        res = db_client.put(f"/api/v1/cases/{case_id}/form-b", json=FULL_FORM_B, headers=headers)
        assert res.status_code == 200, res.text
    form = res.json()
    assert [r["code"] for r in form["rights"] if r["claimed"]] == [
        "nistar",
        "minor_forest_produce",
        "grazing",
    ]
    assert form["completeness"]["done"] == form["completeness"]["total"] == 5


def test_drafts_are_private_to_the_claimant(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = new_case(db_client, villages["ozhar"], VILLAGER, "cr")
    for phone in (VILLAGER2, GS, OUTSIDER):  # other villager, GS before filing, other village
        res = db_client.get(
            f"/api/v1/cases/{case_id}/form-b", headers=auth_headers(db_client, phone)
        )
        assert res.status_code == 404, phone


def test_gram_sabha_sees_after_filing_but_cannot_edit(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = new_case(db_client, villages["ozhar"], VILLAGER, "cr")
    db_client.put(
        f"/api/v1/cases/{case_id}/form-b",
        json=FULL_FORM_B,
        headers=auth_headers(db_client, VILLAGER),
    )
    sub = db_client.post(
        f"/api/v1/cases/{case_id}/submit", headers=auth_headers(db_client, VILLAGER)
    )
    assert sub.status_code == 200, sub.text
    gs = auth_headers(db_client, GS)
    got = db_client.get(f"/api/v1/cases/{case_id}/form-b", headers=gs)
    assert got.status_code == 200
    assert got.json()["editable"] is False
    put = db_client.put(f"/api/v1/cases/{case_id}/form-b", json=FULL_FORM_B, headers=gs)
    assert put.status_code == 403
    # and the claimant can no longer edit once filed
    again = db_client.put(
        f"/api/v1/cases/{case_id}/form-b",
        json=FULL_FORM_B,
        headers=auth_headers(db_client, VILLAGER),
    )
    assert again.status_code == 409
    assert again.json()["error"] == "CASE_NOT_EDITABLE"


def test_form_endpoints_do_not_mix(db_client: TestClient, villages: dict[str, uuid.UUID]) -> None:
    case_id = new_case(db_client, villages["ozhar"], VILLAGER, "cr")
    res = db_client.get(
        f"/api/v1/cases/{case_id}/form-a", headers=auth_headers(db_client, VILLAGER)
    )
    assert res.status_code == 409
    assert res.json()["error"] == "NOT_A_FORM_A_CASE"
