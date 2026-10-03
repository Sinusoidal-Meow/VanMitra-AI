"""
G-series documents, legal clocks and the record after the title (BR-13), against the
test database. The tests run in order and share one CFR case taken to title_issued.
"""

from datetime import date
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session, sessionmaker

from app.models import Role

from .conftest import (
    auth_headers,
    complete_cfr_prerequisites,
    make_user,
    make_village,
    new_case,
)

GS, SDO, COLLECTOR, DFO, DTWO, VILLAGER = (
    "9900000001",
    "9900000002",
    "9900000003",
    "9900000004",
    "9900000005",
    "9900000006",
)
TODAY = date.today()


@pytest.fixture(scope="module")
def ctx(session_factory: sessionmaker[Session]) -> dict[str, Any]:
    with session_factory() as db:
        village = make_village(db, "FollowupVillage")
        make_user(db, GS, Role.GRAM_SABHA, village=village)
        make_user(db, VILLAGER, Role.VILLAGER, village=village)
        make_user(db, SDO, Role.SDO, taluka="Jawhar", district="Palghar")
        make_user(db, COLLECTOR, Role.COLLECTOR, district="Palghar")
        make_user(db, DFO, Role.DFO, district="Palghar")
        make_user(db, DTWO, Role.TRIBAL_WELFARE_OFFICER, district="Palghar")
        db.commit()
        return {"village": village.id}


def _h(client: TestClient, phone: str = GS) -> dict[str, str]:
    return auth_headers(client, phone)


def _get(client: TestClient, url: str, who: str = GS) -> Any:
    return client.get(url, headers=_h(client, who))


def _post(client: TestClient, url: str, body: dict[str, Any] | None = None, who: str = GS) -> Any:
    return client.post(url, json=body, headers=_h(client, who))


def test_documents_before_the_work_is_done(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case = new_case(db_client, ctx["village"], GS, "cfr")
    ctx["case"] = case
    base = f"/api/v1/cases/{case}/documents"
    assert _get(db_client, f"{base}/g99").json()["error"] == "UNKNOWN_DOCUMENT"
    assert _get(db_client, f"{base}/g4").json()["error"] == "NOT_YET_FILED"
    assert _get(db_client, f"{base}/g10").json()["error"] == "NO_BOUNDARY"
    assert _get(db_client, f"{base}/g13").json()["error"] == "NO_RESOLUTION"
    assert _get(db_client, f"{base}/g12").json()["error"] == "MEETING_REQUIRED"
    assert _get(db_client, f"{base}/g17").json()["error"] == "DISPUTE_REQUIRED"
    assert _get(db_client, f"{base}/g8").status_code == 200  # empty: "no visit recorded yet"
    assert _get(db_client, f"{base}/g4", VILLAGER).status_code == 404  # not their case


def test_the_map_sheet_needs_a_landmark_per_segment(
    db_client: TestClient, ctx: dict[str, Any]
) -> None:
    case = ctx["case"]
    ring = [[72.0, 19.0], [72.01, 19.0], [72.01, 19.01], [72.0, 19.01]]
    two_segments = {"polygon": {"type": "Polygon", "coordinates": [ring]}, "segment_breaks": [0, 2]}
    assert _post(db_client, f"/api/v1/cases/{case}/boundary", two_segments).status_code == 201
    landmark = {"segment_seq": 0, "kind": "stream", "name": "Nala", "lon": 72.005, "lat": 19.0}
    _post(db_client, f"/api/v1/cases/{case}/boundary/landmarks", landmark)
    sheet = _get(db_client, f"/api/v1/cases/{case}/documents/g10")
    assert sheet.status_code == 409
    assert sheet.json()["error"] == "LANDMARK_PER_SEGMENT"  # BR-08
    landmark = {"segment_seq": 1, "kind": "road", "name": "Road", "lon": 72.005, "lat": 19.01}
    _post(db_client, f"/api/v1/cases/{case}/boundary/landmarks", landmark)
    sheet = _get(db_client, f"/api/v1/cases/{case}/documents/g10?lang=mr")
    assert sheet.status_code == 200
    assert sheet.headers["content-type"].startswith("text/html")
    assert "<svg" in sheet.text and "Nala" in sheet.text and "SHA-256" in sheet.text
    assert "सामूहिक वन संसाधन नकाशा" in sheet.text
    g9 = _get(db_client, f"/api/v1/cases/{case}/documents/g9")
    assert g9.status_code == 200 and "Segments and landmarks" in g9.text


def test_filing_and_the_gram_sabha_documents(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case = ctx["case"]
    form_c = {"area_description": "Forest", "bordering_villages": [{"name": "Kurlod"}]}
    db_client.put(f"/api/v1/cases/{case}/form-c", json=form_c, headers=_h(db_client))
    assert _post(db_client, f"/api/v1/cases/{case}/submit").status_code == 200
    g4 = _get(db_client, f"/api/v1/cases/{case}/documents/g4")
    assert g4.status_code == 200 and "FOL/" in g4.text
    complete_cfr_prerequisites(db_client, ctx["village"], GS, case)
    base = f"/api/v1/cases/{case}/documents"
    assert "Field verification proceeding" in _get(db_client, f"{base}/g8").text
    g13 = _get(db_client, f"{base}/g13")
    assert g13.status_code == 200 and "Resolution no." in g13.text and "complete" in g13.text
    meeting = _get(db_client, f"/api/v1/villages/{ctx['village']}/meetings").json()[0]["id"]
    g12 = _get(db_client, f"{base}/g12?meeting_id={meeting}")
    assert g12.status_code == 200 and "Quorum complete" in g12.text
    ctx["g7"] = _post(
        db_client,
        f"/api/v1/villages/{ctx['village']}/letters",
        {"template": "g7_site_visit", "addressee": "RFO <Jawhar>", "subject": "Site visit"},
    ).json()["id"]
    letter = _get(db_client, f"/api/v1/letters/{ctx['g7']}/document")
    assert letter.status_code == 200 and "RFO &lt;Jawhar&gt;" in letter.text


def test_clocks_after_the_resolution(db_client: TestClient, ctx: dict[str, Any]) -> None:
    clocks = {c["kind"]: c for c in _get(db_client, f"/api/v1/cases/{ctx['case']}/timeline").json()}
    petition = clocks["petition_against_resolution"]
    assert petition["rule"] == "Sec 6(2), Rule 14(1)"
    assert petition["status"] == "running" and petition["days_remaining"] == 60
    assert "record_update" not in clocks


def test_title_then_record_entry_then_close(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case = ctx["case"]
    url = f"/api/v1/cases/{case}/post-title"
    assert _get(db_client, url).json()["can_close"] is False
    early = db_client.put(url, json={"record_entry_on": TODAY.isoformat()}, headers=_h(db_client))
    assert early.json()["error"] == "TITLE_NOT_ISSUED"

    assert _post(db_client, f"/api/v1/cases/{case}/approve").json()["state"] == "sdo_review"
    _post(db_client, f"/api/v1/cases/{case}/approve", who=SDO)
    for officer in (COLLECTOR, DFO, DTWO):
        res = _post(db_client, f"/api/v1/cases/{case}/approve", who=officer)
        assert res.status_code == 200, res.text
    assert res.json()["state"] == "title_issued"

    state = _get(db_client, url).json()
    assert state["survey_pending"] is True
    assert state["missing"] == ["certified_copy", "record_entry"]
    refused = _post(db_client, f"/api/v1/cases/{case}/close")
    assert refused.status_code == 409 and refused.json()["error"] == "CANNOT_CLOSE"  # BR-13
    villager = db_client.put(url, json={}, headers=_h(db_client, VILLAGER))
    assert villager.status_code in (403, 404)

    scan = db_client.post(
        "/api/v1/media",
        files={"file": ("title.pdf", b"%PDF certified copy", "application/pdf")},
        headers=_h(db_client, SDO),
    )
    step = {"certified_copy_media_id": scan.json()["id"], "certified_copy_on": TODAY.isoformat()}
    res = db_client.put(url, json=step, headers=_h(db_client, SDO))
    assert res.status_code == 200, res.text
    assert res.json()["missing"] == ["record_entry"]
    assert _post(db_client, f"/api/v1/cases/{case}/close", who=SDO).status_code == 409
    entry = {"record_entry_on": TODAY.isoformat(), "record_entry_ref": "7/12 mutation 441"}
    res = db_client.put(url, json=entry, headers=_h(db_client, SDO))
    assert res.json()["can_close"] is True
    closed = _post(db_client, f"/api/v1/cases/{case}/close", who=SDO)
    assert closed.status_code == 200 and closed.json()["closed_on"] == TODAY.isoformat()
    again = db_client.put(
        url, json={"survey_done_on": TODAY.isoformat()}, headers=_h(db_client, SDO)
    )
    assert again.json()["error"] == "CASE_CLOSED"

    clocks = {c["kind"]: c for c in _get(db_client, f"/api/v1/cases/{case}/timeline").json()}
    assert clocks["record_update"]["status"] == "met"
