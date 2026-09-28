"""Form B draft end to end against the test database (see tests/db/conftest.py)."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session, sessionmaker

from app.models import CaseState, ClaimCase, Role

from .conftest import auth_headers, make_user, make_village

FACILITATOR, FRC, SECRETARY, OUTSIDER = "9200000001", "9200000002", "9200000003", "9200000004"

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
        make_user(db, FACILITATOR, [(ozhar.id, Role.FACILITATOR)])
        make_user(db, FRC, [(ozhar.id, Role.FRC_MEMBER)])
        make_user(db, SECRETARY, [(ozhar.id, Role.GS_SECRETARY)])
        make_user(db, OUTSIDER, [(other.id, Role.FRC_MEMBER)])
        db.commit()
        return {"ozhar": ozhar.id, "other": other.id}


def _create_case(client: TestClient, village_id: uuid.UUID, phone: str) -> str:
    res = client.post(
        f"/api/v1/villages/{village_id}/cases",
        json={"claim_type": "cr"},
        headers=auth_headers(client, phone),
    )
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["state"] == "draft"
    assert body["claim_type"] == "cr"
    return str(body["id"])


def test_new_form_b_is_empty_with_header_from_registry(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = _create_case(db_client, villages["ozhar"], FACILITATOR)
    res = db_client.get(f"/api/v1/cases/{case_id}/form-b", headers=auth_headers(db_client, FRC))
    assert res.status_code == 200, res.text
    form = res.json()
    assert form["editable"] is True
    assert form["header"]["taluka"] == "Jawhar"
    assert form["header"]["district"] == "Palghar"
    assert [r["code"] for r in form["rights"]] == [
        "nistar",
        "minor_forest_produce",
        "water_bodies",
        "grazing",
        "nomadic_pastoral_access",
        "habitat",
        "biodiversity_knowledge",
        "other_traditional",
    ]
    assert not any(r["claimed"] for r in form["rights"])
    # Only B-3 (village details from the registry) is complete on a new draft.
    assert (form["completeness"]["done"], form["completeness"]["total"]) == (1, 5)


def test_frc_fills_form_b(db_client: TestClient, villages: dict[str, uuid.UUID]) -> None:
    case_id = _create_case(db_client, villages["ozhar"], FRC)
    res = db_client.put(
        f"/api/v1/cases/{case_id}/form-b",
        json=FULL_FORM_B,
        headers=auth_headers(db_client, FRC),
    )
    assert res.status_code == 200, res.text
    form = res.json()
    claimed = [r["code"] for r in form["rights"] if r["claimed"]]
    assert claimed == ["nistar", "minor_forest_produce", "grazing"]  # printed-form order
    grazing = next(r for r in form["rights"] if r["code"] == "grazing")
    assert grazing["section"] == "Section 3(1)(d)"
    assert grazing["items"] == ["Gairan"]
    assert [(e["seq"], e["rule_ref"]) for e in form["evidence"]] == [
        (1, "13(1)(a)"),
        (2, "13(1)(i)"),
    ]
    assert form["completeness"]["done"] == form["completeness"]["total"] == 5

    # A second PUT replaces rights and evidence instead of appending.
    smaller = {**FULL_FORM_B, "rights": {"habitat": {"details": "Hamlet site"}}, "evidence": []}
    res = db_client.put(
        f"/api/v1/cases/{case_id}/form-b", json=smaller, headers=auth_headers(db_client, FRC)
    )
    form = res.json()
    assert [r["code"] for r in form["rights"] if r["claimed"]] == ["habitat"]
    assert form["evidence"] == []
    b5 = next(i for i in form["completeness"]["items"] if i["id"] == "B-5")
    assert b5["ok"] is False
    assert b5["rule"] == "Rule 11(1)(a), Rule 13(3)"


def test_saving_the_same_form_twice(db_client: TestClient, villages: dict[str, uuid.UUID]) -> None:
    """Re-submitting existing rights/evidence must not trip the unique constraints."""
    case_id = _create_case(db_client, villages["ozhar"], FRC)
    headers = auth_headers(db_client, FRC)
    for _ in range(2):
        res = db_client.put(f"/api/v1/cases/{case_id}/form-b", json=FULL_FORM_B, headers=headers)
        assert res.status_code == 200, res.text
    assert len([r for r in res.json()["rights"] if r["claimed"]]) == 3
    assert len(res.json()["evidence"]) == 2


def test_secretary_reads_but_cannot_edit_or_create(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = _create_case(db_client, villages["ozhar"], FACILITATOR)
    headers = auth_headers(db_client, SECRETARY)
    assert db_client.get(f"/api/v1/cases/{case_id}/form-b", headers=headers).status_code == 200
    put = db_client.put(f"/api/v1/cases/{case_id}/form-b", json=FULL_FORM_B, headers=headers)
    assert put.status_code == 403
    create = db_client.post(
        f"/api/v1/villages/{villages['ozhar']}/cases", json={"claim_type": "cr"}, headers=headers
    )
    assert create.status_code == 403


def test_other_village_cannot_see_the_case(
    db_client: TestClient, villages: dict[str, uuid.UUID]
) -> None:
    case_id = _create_case(db_client, villages["ozhar"], FACILITATOR)
    headers = auth_headers(db_client, OUTSIDER)
    res = db_client.get(f"/api/v1/cases/{case_id}/form-b", headers=headers)
    assert res.status_code == 404
    assert res.json()["error"] == "CASE_NOT_FOUND"
    listing = db_client.get(f"/api/v1/villages/{villages['ozhar']}/cases", headers=headers)
    assert listing.status_code == 403


def test_only_cr_cases_for_now(db_client: TestClient, villages: dict[str, uuid.UUID]) -> None:
    res = db_client.post(
        f"/api/v1/villages/{villages['ozhar']}/cases",
        json={"claim_type": "cfr"},
        headers=auth_headers(db_client, FRC),
    )
    assert res.status_code == 422
    assert res.json()["error"] == "CLAIM_TYPE_NOT_AVAILABLE"


def test_form_b_locked_after_draft(
    db_client: TestClient,
    villages: dict[str, uuid.UUID],
    session_factory: sessionmaker[Session],
) -> None:
    case_id = _create_case(db_client, villages["ozhar"], FRC)
    with session_factory() as db:  # simulate a later workflow state
        case = db.get(ClaimCase, uuid.UUID(case_id))
        assert case is not None
        case.state = CaseState.GS_RESOLVED
        db.commit()
    res = db_client.put(
        f"/api/v1/cases/{case_id}/form-b", json=FULL_FORM_B, headers=auth_headers(db_client, FRC)
    )
    assert res.status_code == 409
    assert res.json()["error"] == "CASE_NOT_EDITABLE"


def test_list_cases_in_village(db_client: TestClient, villages: dict[str, uuid.UUID]) -> None:
    case_id = _create_case(db_client, villages["ozhar"], FACILITATOR)
    res = db_client.get(
        f"/api/v1/villages/{villages['ozhar']}/cases", headers=auth_headers(db_client, SECRETARY)
    )
    assert res.status_code == 200
    assert case_id in [c["id"] for c in res.json()]
