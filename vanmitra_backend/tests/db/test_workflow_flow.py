"""
The whole Module 3 path against the test database:
village user → Gram Sabha → SDO → Collector + DFO + Tribal Welfare Officer → title draft.
"""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session, sessionmaker

from app.models import Role

from .conftest import auth_headers, make_user, make_village, new_case

VILLAGER, GS, SDO, SDO_OTHER = "9400000001", "9400000002", "9400000003", "9400000004"
COLLECTOR, DFO, DTWO, COLLECTOR_OTHER = "9400000005", "9400000006", "9400000007", "9400000008"

FORM_A: dict[str, Any] = {
    "claimant_names": ["Ramu Bhoye"],
    "spouse_name": "Sita Bhoye",
    "father_mother_name": "Kashinath Bhoye",
    "address": "Pada 2, Ozhar",
    "is_scheduled_tribe": True,
    "is_otfd": False,
    "family_members": [{"name": "Ganesh", "age": 12, "relation": "son"}],
    "claims": {
        "self_cultivation": {"extent_ha": 1.2, "details": "Field north of the pada since 1995"},
        "habitation": {"extent_ha": 0.05, "details": "House plot"},
    },
    "evidence": [
        {"rule_ref": "13(1)(b)", "description": "Voter ID"},
        {"rule_ref": "13(1)(i)", "description": "Statement of two elders"},
    ],
}


@pytest.fixture(scope="module")
def ids(session_factory: sessionmaker[Session]) -> dict[str, uuid.UUID]:
    with session_factory() as db:
        ozhar = make_village(db, "FlowVillage", taluka="Jawhar", district="Palghar")
        make_user(db, VILLAGER, Role.VILLAGER, village=ozhar)
        make_user(db, GS, Role.GRAM_SABHA, village=ozhar)
        make_user(db, SDO, Role.SDO, taluka="Jawhar", district="Palghar")
        make_user(db, SDO_OTHER, Role.SDO, taluka="Dahanu", district="Palghar")
        make_user(db, COLLECTOR, Role.COLLECTOR, district="Palghar")
        make_user(db, DFO, Role.DFO, district="Palghar")
        make_user(db, DTWO, Role.TRIBAL_WELFARE_OFFICER, district="Palghar")
        make_user(db, COLLECTOR_OTHER, Role.COLLECTOR, district="Nashik")
        db.commit()
        return {"village": ozhar.id}


def _act(client: TestClient, case_id: str, phone: str, action: str, remarks: str | None = None):  # type: ignore[no-untyped-def]
    body = {"remarks": remarks} if remarks else None
    return client.post(
        f"/api/v1/cases/{case_id}/{action}", json=body, headers=auth_headers(client, phone)
    )


def _filed_form_a(client: TestClient, village_id: uuid.UUID) -> str:
    case_id = new_case(client, village_id, VILLAGER, "ifr")
    put = client.put(
        f"/api/v1/cases/{case_id}/form-a", json=FORM_A, headers=auth_headers(client, VILLAGER)
    )
    assert put.status_code == 200, put.text
    assert put.json()["total_extent_ha"] == 1.25
    assert _act(client, case_id, VILLAGER, "submit").json()["state"] == "gs_review"
    return case_id


def test_full_path_to_title_draft(db_client: TestClient, ids: dict[str, uuid.UUID]) -> None:
    case_id = _filed_form_a(db_client, ids["village"])

    # SDO cannot see it yet; Gram Sabha has it in its queue
    sdo_view = db_client.get(f"/api/v1/cases/{case_id}", headers=auth_headers(db_client, SDO))
    assert sdo_view.status_code == 404
    queue = db_client.get("/api/v1/review/queue", headers=auth_headers(db_client, GS)).json()
    assert case_id in [c["id"] for c in queue]

    assert _act(db_client, case_id, GS, "approve").json()["state"] == "sdo_review"
    # an SDO of another taluka can neither see nor act
    assert _act(db_client, case_id, SDO_OTHER, "approve").status_code == 404
    assert _act(db_client, case_id, SDO, "approve").json()["state"] == "district_review"

    # title draft is previewable at the district, not yet issued
    preview = db_client.get(
        f"/api/v1/cases/{case_id}/title-draft", headers=auth_headers(db_client, DFO)
    )
    assert preview.status_code == 200, preview.text
    assert preview.json()["annexure"].startswith("Annexure II")
    assert preview.json()["status"].startswith("draft")

    # other district's collector sees nothing
    assert _act(db_client, case_id, COLLECTOR_OTHER, "approve").status_code == 404

    r1 = _act(db_client, case_id, DFO, "approve").json()
    assert r1["state"] == "district_review" and r1["district_approvals"] == ["dfo"]
    assert _act(db_client, case_id, DFO, "approve").status_code == 409  # not twice
    r2 = _act(db_client, case_id, DTWO, "approve").json()
    assert r2["state"] == "district_review"
    r3 = _act(db_client, case_id, COLLECTOR, "approve").json()
    assert r3["state"] == "title_issued"

    title = db_client.get(
        f"/api/v1/cases/{case_id}/title-draft", headers=auth_headers(db_client, VILLAGER)
    ).json()
    assert title["status"] == "issued"
    assert title["fields"]["1_holders_including_spouse"] == ["Ramu Bhoye", "Sita Bhoye"]
    assert title["fields"]["10_area_ha"] == 1.25
    assert [s["role"] for s in title["signatories"]] == [
        "dfo",
        "tribal_welfare_officer",
        "collector",
    ]
    assert all(s["signed_at"] for s in title["signatories"])

    history = db_client.get(
        f"/api/v1/cases/{case_id}/history", headers=auth_headers(db_client, VILLAGER)
    ).json()
    assert [(h["action"], h["actor_role"]) for h in history] == [
        ("submit", "villager"),
        ("approve", "gram_sabha"),
        ("approve", "sdo"),
        ("approve", "dfo"),
        ("approve", "tribal_welfare_officer"),
        ("approve", "collector"),
    ]


def test_return_goes_down_and_restarts_district_round(
    db_client: TestClient, ids: dict[str, uuid.UUID]
) -> None:
    case_id = _filed_form_a(db_client, ids["village"])
    _act(db_client, case_id, GS, "approve")
    _act(db_client, case_id, SDO, "approve")
    _act(db_client, case_id, DFO, "approve")
    no_remarks = _act(db_client, case_id, COLLECTOR, "return")
    assert no_remarks.status_code == 422
    back = _act(db_client, case_id, COLLECTOR, "return", "Boundary of the field is unclear")
    assert back.json()["state"] == "sdo_review"
    # SDO still sees it after the return; re-forwards; the DFO must approve again
    again = _act(db_client, case_id, SDO, "approve").json()
    assert again["state"] == "district_review" and again["district_approvals"] == []


def test_gram_sabha_returns_to_claimant_who_can_edit_again(
    db_client: TestClient, ids: dict[str, uuid.UUID]
) -> None:
    case_id = _filed_form_a(db_client, ids["village"])
    back = _act(db_client, case_id, GS, "return", "Please attach the voter ID")
    assert back.json()["state"] == "draft"
    put = db_client.put(
        f"/api/v1/cases/{case_id}/form-a", json=FORM_A, headers=auth_headers(db_client, VILLAGER)
    )
    assert put.status_code == 200
    assert _act(db_client, case_id, VILLAGER, "submit").json()["state"] == "gs_review"


def test_reject_needs_reasons_and_is_final(
    db_client: TestClient, ids: dict[str, uuid.UUID]
) -> None:
    case_id = _filed_form_a(db_client, ids["village"])
    _act(db_client, case_id, GS, "approve")
    res = _act(db_client, case_id, SDO, "reject", "Land is outside the village boundary")
    assert res.json()["state"] == "rejected"
    assert res.json()["allowed_actions"] == []
    assert _act(db_client, case_id, SDO, "approve").status_code == 409


def test_wrong_level_cannot_act(db_client: TestClient, ids: dict[str, uuid.UUID]) -> None:
    case_id = _filed_form_a(db_client, ids["village"])
    # the claimant cannot approve their own claim at the Gram Sabha level
    assert _act(db_client, case_id, VILLAGER, "approve").status_code == 403
    mine = db_client.get("/api/v1/cases/mine", headers=auth_headers(db_client, VILLAGER)).json()
    assert case_id in [c["id"] for c in mine]


def test_form_c_by_gram_sabha_reaches_annexure_iv(
    db_client: TestClient, ids: dict[str, uuid.UUID]
) -> None:
    case_id = new_case(db_client, ids["village"], GS, "cfr")
    gs = auth_headers(db_client, GS)
    db_client.put(
        f"/api/v1/cases/{case_id}/form-c",
        json={
            "area_description": "Customary forest",
            "landmarks": [{"side": "east", "kind": "stream", "name": "Nala"}],
        },
        headers=gs,
    )
    assert _act(db_client, case_id, GS, "submit").json()["state"] == "gs_review"
    # the Gram Sabha (as reviewer) forwards its own claim to the SDO
    assert _act(db_client, case_id, GS, "approve").json()["state"] == "sdo_review"
    _act(db_client, case_id, SDO, "approve")
    for officer in (COLLECTOR, DFO, DTWO):
        _act(db_client, case_id, officer, "approve")
    title = db_client.get(f"/api/v1/cases/{case_id}/title-draft", headers=gs).json()
    assert title["annexure"].startswith("Annexure IV")
    assert title["fields"]["6_boundary_description"]["prominent_landmarks"]["east"] == ["Nala"]


def test_form_b_title_iii_carries_per_right_boundaries(
    db_client: TestClient, ids: dict[str, uuid.UUID]
) -> None:
    case_id = new_case(db_client, ids["village"], VILLAGER, "cr")
    body = {
        "claimant_names": ["Ozhar community"],
        "is_fdst_community": True,
        "is_otfd_community": False,
        "rights": {
            "minor_forest_produce": {
                "details": "Bamboo, mahua, tendu leaves",
                "survey_compartment_numbers": ["156", "157"],
                "total_area_ha": 748.23,
                "boundaries": {
                    "east": "Maraban",
                    "west": "Nagdevta",
                    "north": "Marodi",
                    "south": "Talav",
                },
            }
        },
    }
    put = db_client.put(
        f"/api/v1/cases/{case_id}/form-b", json=body, headers=auth_headers(db_client, VILLAGER)
    )
    assert put.status_code == 200, put.text
    _act(db_client, case_id, VILLAGER, "submit")
    _act(db_client, case_id, GS, "approve")
    _act(db_client, case_id, SDO, "approve")
    for officer in (DFO, DTWO, COLLECTOR):
        _act(db_client, case_id, officer, "approve")
    title = db_client.get(
        f"/api/v1/cases/{case_id}/title-draft", headers=auth_headers(db_client, VILLAGER)
    ).json()
    assert title["annexure"].startswith("Annexure III")
    assert title["status"] == "issued"
    [boundary] = title["fields"]["9_boundaries"]
    assert boundary["survey_compartment_numbers"] == ["156", "157"]
    assert (boundary["east"], boundary["south"]) == ("Maraban", "Talav")
