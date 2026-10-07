"""
The claim path against the test database:
villager → Gram Sabha → SDO → handed over to the district website (title draft ready).
Either reviewer can send the claim back to the villager with remarks; the villager has
60 days to resubmit.
"""

import uuid
from datetime import timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.orm import Session, sessionmaker

from app.domain.dates import today_ist
from app.models import Role

from .conftest import (
    auth_headers,
    complete_cfr_prerequisites,
    make_user,
    make_village,
    new_case,
)

VILLAGER, GS, SDO, SDO_OTHER = "9400000001", "9400000002", "9400000003", "9400000004"

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


def _get(client: TestClient, case_id: str, phone: str) -> Any:
    return client.get(f"/api/v1/cases/{case_id}", headers=auth_headers(client, phone))


def test_full_path_hands_over_to_the_district(
    db_client: TestClient, ids: dict[str, uuid.UUID]
) -> None:
    case_id = _filed_form_a(db_client, ids["village"])

    # SDO cannot see it yet; Gram Sabha has it in its queue
    assert _get(db_client, case_id, SDO).status_code == 404
    queue = db_client.get("/api/v1/review/queue", headers=auth_headers(db_client, GS)).json()
    assert case_id in [c["id"] for c in queue]

    assert _act(db_client, case_id, GS, "approve").json()["state"] == "sdo_review"
    # an SDO of another taluka can neither see nor act
    assert _act(db_client, case_id, SDO_OTHER, "approve").status_code == 404
    handed = _act(db_client, case_id, SDO, "approve").json()
    assert handed["state"] == "district_review"
    assert handed["allowed_actions"] == []

    # nothing more happens here: the district website takes it from now
    again = _act(db_client, case_id, SDO, "return", "Second thoughts")
    assert again.status_code == 409 and again.json()["error"] == "HANDED_TO_DISTRICT"

    # the title draft is ready for the district committee to sign
    title = db_client.get(
        f"/api/v1/cases/{case_id}/title-draft", headers=auth_headers(db_client, VILLAGER)
    ).json()
    assert title["annexure"].startswith("Annexure II")
    assert title["status"].startswith("draft")
    assert title["fields"]["1_holders_including_spouse"] == ["Ramu Bhoye", "Sita Bhoye"]
    assert title["fields"]["10_area_ha"] == 1.25
    assert [s["designation"] for s in title["signatories"]] == [
        "Tribal Welfare Divisional Officer (TWDO)",
        "Forest Divisional Officer (FDO)",
        "Deputy Collector",
    ]
    assert not any(s["signed_at"] for s in title["signatories"])

    history = db_client.get(
        f"/api/v1/cases/{case_id}/history", headers=auth_headers(db_client, VILLAGER)
    ).json()
    assert [(h["action"], h["actor_role"]) for h in history] == [
        ("submit", "villager"),
        ("approve", "gram_sabha"),
        ("approve", "sdo"),
    ]


def test_sdo_sends_the_claim_back_to_the_villager(
    db_client: TestClient, ids: dict[str, uuid.UUID]
) -> None:
    case_id = _filed_form_a(db_client, ids["village"])
    _act(db_client, case_id, GS, "approve")
    assert _act(db_client, case_id, SDO, "return").status_code == 422  # a remark is required
    back = _act(db_client, case_id, SDO, "return", "The photo of the field is not clear")
    assert back.json()["state"] == "draft"

    seen = _get(db_client, case_id, VILLAGER).json()
    returned = seen["returned"]
    assert returned["by_role"] == "sdo"
    assert returned["remarks"] == "The photo of the field is not clear"
    assert returned["returned_on"] == today_ist().isoformat()
    assert returned["resubmit_by"] == (today_ist() + timedelta(days=60)).isoformat()
    assert returned["days_left"] == 60
    assert seen["allowed_actions"] == ["submit"]

    # the villager corrects the form and resubmits; it starts again at the Gram Sabha
    put = db_client.put(
        f"/api/v1/cases/{case_id}/form-a", json=FORM_A, headers=auth_headers(db_client, VILLAGER)
    )
    assert put.status_code == 200
    resubmitted = _act(db_client, case_id, VILLAGER, "submit").json()
    assert resubmitted["state"] == "gs_review"
    assert resubmitted["returned"] is None


def test_gram_sabha_sends_the_claim_back_to_the_villager(
    db_client: TestClient, ids: dict[str, uuid.UUID]
) -> None:
    case_id = _filed_form_a(db_client, ids["village"])
    back = _act(db_client, case_id, GS, "return", "Please attach the voter ID")
    assert back.json()["state"] == "draft"
    assert back.json()["returned"]["by_role"] == "gram_sabha"
    assert _act(db_client, case_id, VILLAGER, "submit").json()["state"] == "gs_review"


def test_resubmission_after_sixty_days_is_refused(
    db_client: TestClient, ids: dict[str, uuid.UUID], session_factory: sessionmaker[Session]
) -> None:
    case_id = _filed_form_a(db_client, ids["village"])
    _act(db_client, case_id, GS, "return", "Photos are missing")
    # move this claim's history 61 days into the past (the history is append-only, so the
    # guard is lifted for this one change in the throwaway test database)
    with session_factory() as db:
        db.execute(text("ALTER TABLE workflow_event DISABLE TRIGGER workflow_event_append_only"))
        db.execute(
            text(
                "UPDATE workflow_event SET created_at = created_at - interval '61 days' "
                "WHERE case_id = :c"
            ),
            {"c": case_id},
        )
        db.execute(text("ALTER TABLE workflow_event ENABLE TRIGGER workflow_event_append_only"))
        db.commit()
    seen = _get(db_client, case_id, VILLAGER).json()
    assert seen["returned"]["days_left"] == 0
    assert seen["allowed_actions"] == []
    late = _act(db_client, case_id, VILLAGER, "submit")
    assert late.status_code == 409 and late.json()["error"] == "RESUBMIT_WINDOW_PASSED"


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
    # BR-04: it cannot forward its own claim without resolution, boundary and verification
    blocked = _act(db_client, case_id, GS, "approve")
    assert blocked.status_code == 409 and blocked.json()["error"] == "GS_PREREQUISITES_MISSING"
    complete_cfr_prerequisites(db_client, ids["village"], GS, case_id)
    # the Gram Sabha (as reviewer) forwards its own claim to the SDO
    assert _act(db_client, case_id, GS, "approve").json()["state"] == "sdo_review"
    assert _act(db_client, case_id, SDO, "approve").json()["state"] == "district_review"
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
    title = db_client.get(
        f"/api/v1/cases/{case_id}/title-draft", headers=auth_headers(db_client, VILLAGER)
    ).json()
    assert title["annexure"].startswith("Annexure III")
    assert title["status"].startswith("draft")
    [boundary] = title["fields"]["9_boundaries"]
    assert boundary["survey_compartment_numbers"] == ["156", "157"]
    assert (boundary["east"], boundary["south"]) == ("Maraban", "Talav")
