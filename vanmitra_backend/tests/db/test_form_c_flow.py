"""Form C draft and member roster end to end (see tests/db/conftest.py)."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session, sessionmaker

from app.domain.form_c import DEFAULT_RESOLUTION_STATEMENT
from app.models import Gender, GramSabha, GsMember, MemberCategory, Role

from .conftest import auth_headers, make_user, make_village

FACILITATOR, FRC, SECRETARY, OUTSIDER = "9300000001", "9300000002", "9300000003", "9300000004"

FULL_FORM_C: dict[str, Any] = {
    "area_description": "Customary forest east and south of Ozar up to the Nagdevta stream",
    "approx_area_ha": 318.4,
    "pastoral_seasonal_use": False,
    "landmarks": [
        {"side": "east", "kind": "stream", "name": "Nagdevta nala"},
        {"side": "west", "kind": "sacred_place", "name": "Waghoba devasthan"},
        {"side": "north", "kind": "road", "name": "Jawhar road"},
        {"side": "south", "kind": "pond", "name": "Mothe talav"},
        {"side": "within", "kind": "sacred_grove", "name": "Devrai", "description": "Old grove"},
    ],
    "khasra_compartment_numbers": ["156", "157", "157"],
    "bordering_villages": [
        {"name": "Chambharshet", "shares_resources": True, "sharing_details": "Shared grazing"},
    ],
    "evidence": [
        {"rule_ref": "13(1)(a)", "description": "7/12 extract, survey no. 110"},
        {"rule_ref": "13(1)(i)", "description": "Statement of elders (not claimants)"},
        {"rule_ref": "13(2)(a)", "description": "Nistar patrak of the village"},
    ],
}


@pytest.fixture(scope="module")
def villages(session_factory: sessionmaker[Session]) -> dict[str, uuid.UUID]:
    with session_factory() as db:
        ozar = make_village(db, "FormCVillage")
        other = make_village(db, "FormCOther")
        make_user(db, FACILITATOR, [(ozar.id, Role.FACILITATOR)])
        make_user(db, FRC, [(ozar.id, Role.FRC_MEMBER)])
        make_user(db, SECRETARY, [(ozar.id, Role.GS_SECRETARY)])
        make_user(db, OUTSIDER, [(other.id, Role.GS_SECRETARY)])
        gs = db.query(GramSabha).filter_by(village_id=ozar.id).one()
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


def _new_cfr_case(client: TestClient, village_id: uuid.UUID, phone: str) -> str:
    res = client.post(
        f"/api/v1/villages/{village_id}/cases",
        json={"claim_type": "cfr"},
        headers=auth_headers(client, phone),
    )
    assert res.status_code == 201, res.text
    assert res.json()["claim_type"] == "cfr"
    return str(res.json()["id"])


def test_roster_is_kept_by_the_secretary(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    url = f"/api/v1/villages/{villages['ozar']}/members"
    sec = auth_headers(db_client, SECRETARY)
    for name, gender, cat in [("Sita Bhoye", "female", "st"), ("Ramu Kadu", "male", "otfd")]:
        res = db_client.post(
            url, json={"name": name, "gender": gender, "category": cat}, headers=sec
        )
        assert res.status_code == 201, res.text
    # FRC can read but not add
    frc = auth_headers(db_client, FRC)
    assert db_client.get(url, headers=frc).status_code == 200
    denied = db_client.post(
        url, json={"name": "X", "gender": "male", "category": "st"}, headers=frc
    )
    assert denied.status_code == 403
    # another village's secretary cannot touch this roster
    outsider = auth_headers(db_client, OUTSIDER)
    assert db_client.get(url, headers=outsider).status_code == 403


def test_member_can_be_deactivated_not_deleted(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    sec = auth_headers(db_client, SECRETARY)
    url = f"/api/v1/villages/{villages['ozar']}/members"
    created = db_client.post(
        url, json={"name": "Moved Away", "gender": "male", "category": "other"}, headers=sec
    ).json()
    res = db_client.patch(f"/api/v1/members/{created['id']}", json={"active": False}, headers=sec)
    assert res.status_code == 200
    assert res.json()["active"] is False
    assert created["id"] not in [m["id"] for m in db_client.get(url, headers=sec).json()]
    everyone = db_client.get(url, params={"include_inactive": True}, headers=sec).json()
    assert created["id"] in [m["id"] for m in everyone]


def test_new_form_c_has_default_statement_and_member_sheet(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = _new_cfr_case(db_client, villages["ozar"], FACILITATOR)
    res = db_client.get(f"/api/v1/cases/{case_id}/form-c", headers=auth_headers(db_client, FRC))
    assert res.status_code == 200, res.text
    form = res.json()
    assert form["resolution_statement"] == DEFAULT_RESOLUTION_STATEMENT
    assert form["header"]["district"] == "Palghar"
    sheet = form["member_sheet"]
    assert sheet["total"] >= 2 and sheet["st"] >= 1 and sheet["otfd"] >= 1
    assert form["completeness"]["total"] == 8


def test_frc_fills_form_c(db_client: TestClient, villages: dict[str, uuid.UUID]) -> None:
    case_id = _new_cfr_case(db_client, villages["ozar"], FRC)
    headers = auth_headers(db_client, FRC)
    for _ in range(2):  # saving twice must not trip the (case_id, seq) constraints
        res = db_client.put(f"/api/v1/cases/{case_id}/form-c", json=FULL_FORM_C, headers=headers)
        assert res.status_code == 200, res.text
    form = res.json()
    assert [lm["side"] for lm in form["landmarks"]] == ["east", "west", "north", "south", "within"]
    assert form["khasra_compartment_numbers"] == ["156", "157"]  # de-duplicated, order kept
    assert form["approx_area_ha"] == 318.4
    assert form["bordering_villages"][0]["shares_resources"] is True
    assert [e["seq"] for e in form["evidence"]] == [1, 2, 3]
    assert form["completeness"]["done"] == form["completeness"]["total"] == 8


def test_blank_statement_falls_back_to_the_printed_one(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = _new_cfr_case(db_client, villages["ozar"], FRC)
    res = db_client.put(
        f"/api/v1/cases/{case_id}/form-c",
        json={"resolution_statement": None},
        headers=auth_headers(db_client, FRC),
    )
    assert res.json()["resolution_statement"] == DEFAULT_RESOLUTION_STATEMENT


def test_secretary_reads_but_cannot_edit_form_c(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = _new_cfr_case(db_client, villages["ozar"], FRC)
    sec = auth_headers(db_client, SECRETARY)
    assert db_client.get(f"/api/v1/cases/{case_id}/form-c", headers=sec).status_code == 200
    put = db_client.put(f"/api/v1/cases/{case_id}/form-c", json=FULL_FORM_C, headers=sec)
    assert put.status_code == 403


def test_form_b_and_form_c_endpoints_do_not_mix(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = _new_cfr_case(db_client, villages["ozar"], FRC)
    res = db_client.get(f"/api/v1/cases/{case_id}/form-b", headers=auth_headers(db_client, FRC))
    assert res.status_code == 409
    assert res.json()["error"] == "NOT_A_FORM_B_CASE"
