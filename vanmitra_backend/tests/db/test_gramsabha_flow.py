"""
Field verification, meetings, attendance, quorum, resolutions and the Gram Sabha
approval guard for a CFR claim (BR-03, BR-04, BR-07, BR-09). Tests run in order and
share one case.
"""

from datetime import date, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.models import AppUser, Role

from .conftest import StoreMaker, auth_headers, make_user, make_village, new_case

GS, GS_CLAIMANT = "9800000001", "9800000002"
TODAY = date.today()
RING = [[71.0, 18.0], [71.01, 18.0], [71.01, 18.01], [71.0, 18.01]]
SQUARE = {"type": "Polygon", "coordinates": [RING]}
NO_ONE = "00000000-0000-0000-0000-000000000000"


@pytest.fixture(scope="module")
def ctx(session_factory: StoreMaker) -> dict[str, Any]:
    with session_factory() as db:
        village = make_village(db, "MeetingVillage")
        make_user(db, GS, Role.GRAM_SABHA, village=village)
        claimant_user = make_user(db, GS_CLAIMANT, Role.GRAM_SABHA, village=village)
        db.commit()
        return {"village": village.id, "claimant_user": claimant_user.id}


def _h(client: TestClient, phone: str = GS) -> dict[str, str]:
    return auth_headers(client, phone)


def _put(client: TestClient, url: str, body: dict[str, Any]) -> Any:
    return client.put(url, json=body, headers=_h(client))


def _post(client: TestClient, url: str, body: dict[str, Any] | None = None, who: str = GS) -> Any:
    return client.post(url, json=body, headers=_h(client, who))


def test_setup_roster_and_case(db_client: TestClient, ctx: dict[str, Any]) -> None:
    base = f"/api/v1/villages/{ctx['village']}"
    people = [
        ("A", "female", "st"),
        ("B", "female", "st"),
        ("C", "male", "st"),
        ("D", "male", "otfd"),
        ("E", "male", "st"),
        ("F", "male", "other"),
    ]
    ids = []
    for name, gender, cat in people:
        res = _post(db_client, f"{base}/members", {"name": name, "gender": gender, "category": cat})
        assert res.status_code == 201, res.text
        ids.append(res.json()["id"])
    ctx["members"] = ids
    case_id = new_case(db_client, ctx["village"], GS, "cfr")
    ctx["case"] = case_id
    # members A and E are the claimants of this case
    res = _put(db_client, f"/api/v1/cases/{case_id}/claimants", {"member_ids": [ids[0], ids[4]]})
    assert res.status_code == 200, res.text
    form_c = {
        "area_description": "Customary forest",
        "landmarks": [{"side": "east", "kind": "stream", "name": "Nala"}],
    }
    _put(db_client, f"/api/v1/cases/{case_id}/form-c", form_c)
    two_segments = {"polygon": SQUARE, "segment_breaks": [0, 2]}
    res = _post(db_client, f"/api/v1/cases/{case_id}/boundary", two_segments)
    assert res.status_code == 201, res.text
    assert _post(db_client, f"/api/v1/cases/{case_id}/submit").status_code == 200


def test_guard_lists_everything_missing(db_client: TestClient, ctx: dict[str, Any]) -> None:
    check = db_client.get(f"/api/v1/cases/{ctx['case']}/approval-check", headers=_h(db_client))
    assert check.json()["ready"] is False
    assert {i["id"]: i["ok"] for i in check.json()["items"]} == {
        "resolution": False,
        "boundary": False,
        "verification": False,
        "disputes": True,
    }
    res = _post(db_client, f"/api/v1/cases/{ctx['case']}/approve")
    assert res.status_code == 409
    assert res.json()["error"] == "GS_PREREQUISITES_MISSING"
    assert len(res.json()["details"]["missing"]) == 3


def test_verification_rules(db_client: TestClient, ctx: dict[str, Any]) -> None:
    url = f"/api/v1/cases/{ctx['case']}/verification"
    media = db_client.post(
        "/api/v1/media",
        files={"file": ("s.pdf", b"%PDF signed", "application/pdf")},
        headers=_h(db_client),
    )
    body: dict[str, Any] = {
        "visit_on": (TODAY - timedelta(days=5)).isoformat(),
        "observations": "Walked the boundary",
        "presence": [{"name": "RFO Patil", "designation": "RFO", "department": "forest"}],
        "forest_signed": True,
        "signed_scan_media_id": media.json()["id"],
    }
    # Revenue neither signed nor recorded absent: the proceeding is not complete (BR-07)
    first = _post(db_client, url, body)
    assert first.status_code == 201
    assert first.json()["complete"] is False
    assert first.json()["attempt_no"] == 1
    no_sheet = {**body, "revenue_signed": True, "signed_scan_media_id": None}
    assert _post(db_client, url, no_sheet).json()["error"] == "SIGNED_SHEET_MISSING"
    both = {**body, "revenue_signed": True, "revenue_absence_recorded": True}
    assert _post(db_client, url, both).json()["error"] == "SIGNED_AND_ABSENT"

    # an absence needs a dispatched G7 intimation sent before the visit
    absent = {**body, "revenue_absence_recorded": True}
    missing = _post(db_client, url, absent)
    assert missing.status_code == 409
    assert missing.json()["rule"] == "Rule 12A(1)(2)"
    letters = f"/api/v1/villages/{ctx['village']}/letters"
    g7 = _post(
        db_client,
        letters,
        {"template": "g7_site_visit", "addressee": "Talathi", "subject": "Site visit"},
    ).json()
    unsent = _post(db_client, url, {**absent, "intimation_id": g7["id"]})
    assert unsent.json()["error"] == "INTIMATION_REQUIRED"
    sent_on = (TODAY - timedelta(days=15)).isoformat()
    _post(db_client, f"/api/v1/letters/{g7['id']}/dispatch", {"dispatched_on": sent_on})
    second = _post(db_client, url, {**absent, "intimation_id": g7["id"]})
    assert second.status_code == 201, second.text
    assert second.json()["attempt_no"] == 2
    assert second.json()["complete"] is True
    assert second.json()["finality_note"] is True  # absent on the second visit [Rule 12A(2)]
    assert len(db_client.get(url, headers=_h(db_client)).json()) == 2


def test_claimant_cannot_decide_own_claim(
    db_client: TestClient, ctx: dict[str, Any], session_factory: StoreMaker
) -> None:
    with session_factory() as db:
        user = db.get(AppUser, ctx["claimant_user"])
        assert user is not None
        user.gs_member_id = ctx["members"][0]
        db.commit()
    body = {
        "visit_on": TODAY.isoformat(),
        "observations": "x",
        "presence": [{"name": "x", "department": "frc"}],
    }
    res = _post(db_client, f"/api/v1/cases/{ctx['case']}/verification", body, GS_CLAIMANT)
    assert res.status_code == 409
    assert res.json()["rule"] == "Rule 3(3)"


def test_meeting_attendance_and_quorum(db_client: TestClient, ctx: dict[str, Any]) -> None:
    base = f"/api/v1/villages/{ctx['village']}/meetings"
    meeting = {"held_on": TODAY.isoformat(), "place": "Gram Panchayat", "agenda": "CFR claim"}
    late_notice = {**meeting, "notice_on": (TODAY + timedelta(days=1)).isoformat()}
    assert _post(db_client, base, late_notice).json()["error"] == "NOTICE_AFTER_MEETING"
    res = _post(db_client, base, {**meeting, "notice_on": (TODAY - timedelta(days=7)).isoformat()})
    assert res.status_code == 201, res.text
    assert res.json()["registered_count"] == 6
    assert res.json()["attendance_recorded"] is False
    ctx["meeting"] = res.json()["id"]
    m = ctx["members"]
    url = f"/api/v1/meetings/{ctx['meeting']}"

    # B (a woman), C and D present: 3 of 6, 1 woman; neither claimant is there
    res = _put(db_client, f"{url}/attendance", {"present_member_ids": [m[1], m[2], m[3]]})
    assert res.status_code == 200
    assert res.json()["present_count"] == 3
    assert res.json()["women_present"] == 1
    q = db_client.get(f"{url}/quorum?case_id={ctx['case']}", headers=_h(db_client)).json()
    assert q["t1"] and q["t2"] and not q["t3"] and not q["passed"]
    assert (q["claimants_total"], q["claimants_present"]) == (2, 0)
    assert db_client.get(f"{url}/quorum", headers=_h(db_client)).json()["passed"] is True
    stranger = _put(db_client, f"{url}/attendance", {"present_member_ids": [NO_ONE]})
    assert stranger.json()["error"] == "MEMBER_NOT_IN_ROSTER"


def test_resolution_needs_quorum_and_a_majority(db_client: TestClient, ctx: dict[str, Any]) -> None:
    url = f"/api/v1/meetings/{ctx['meeting']}/resolutions"
    body = {
        "case_id": ctx["case"],
        "decision_text": "The claim and the map are approved",
        "votes_for": 3,
        "votes_against": 0,
    }
    failed = _post(db_client, url, body)
    assert failed.status_code == 409
    assert failed.json()["error"] == "QUORUM_FAILED"
    assert failed.json()["details"]["failures"] == ["quorum.t3_claimants"]

    m = ctx["members"]
    _put(
        db_client,
        f"/api/v1/meetings/{ctx['meeting']}/attendance",
        {"present_member_ids": [m[1], m[2], m[4]]},
    )
    too_many = _post(db_client, url, {**body, "votes_for": 3, "votes_against": 1})
    assert too_many.json()["error"] == "MORE_VOTES_THAN_PRESENT"
    lost = _post(db_client, url, {**body, "votes_for": 1, "votes_against": 2})
    assert lost.status_code == 409
    assert lost.json()["error"] == "MOTION_NOT_CARRIED"
    # the boundary still has segments without a landmark (BR-08)
    assert _post(db_client, url, body).json()["error"] == "LANDMARK_PER_SEGMENT"


def test_resolution_approves_and_freezes_the_boundary(
    db_client: TestClient, ctx: dict[str, Any]
) -> None:
    case = ctx["case"]
    for seq, lon, lat in ((0, 71.005, 18.0), (1, 71.005, 18.01)):
        landmark = {"segment_seq": seq, "kind": "stream", "name": f"L{seq}", "lon": lon, "lat": lat}
        res = _post(db_client, f"/api/v1/cases/{case}/boundary/landmarks", landmark)
        assert res.status_code == 201, res.text
    url = f"/api/v1/meetings/{ctx['meeting']}/resolutions"
    body = {
        "case_id": case,
        "decision_text": "The claim and the map are approved",
        "votes_for": 3,
        "votes_against": 0,
    }
    res = _post(db_client, url, body)
    assert res.status_code == 201, res.text
    r = res.json()
    assert r["number"] == f"1/{TODAY.year}"
    assert r["boundary_id"]
    assert r["quorum_proof"]["passed"] is True

    boundary = db_client.get(f"/api/v1/cases/{case}/boundary", headers=_h(db_client)).json()
    assert boundary["status"] == "gs_approved"
    assert len(boundary["sealed_hash"]) == 64
    late = {"segment_seq": 0, "kind": "well", "name": "late", "lon": 71.0, "lat": 18.0}
    frozen = _post(db_client, f"/api/v1/cases/{case}/boundary/landmarks", late)
    assert frozen.json()["error"] == "BOUNDARY_FROZEN"
    locked = _put(
        db_client, f"/api/v1/meetings/{ctx['meeting']}/attendance", {"present_member_ids": []}
    )
    assert locked.json()["error"] == "ATTENDANCE_LOCKED"
    listed = db_client.get(f"/api/v1/cases/{case}/resolutions", headers=_h(db_client)).json()
    assert len(listed) == 1


def test_guard_opens_and_readiness_follows(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case = ctx["case"]
    check = db_client.get(f"/api/v1/cases/{case}/approval-check", headers=_h(db_client)).json()
    assert check["ready"] is True, check
    ready = db_client.get(f"/api/v1/cases/{case}/readiness", headers=_h(db_client)).json()
    ok = {i["id"]: i["ok"] for i in ready["items"]}
    assert ok["R3"] and ok["R4"] and ok["R5"] and ok["R7"] and ok["R10"]
    res = _post(db_client, f"/api/v1/cases/{case}/approve")
    assert res.status_code == 200
    assert res.json()["state"] == "sdo_review"
    verify = f"/api/v1/villages/{ctx['village']}/ledger/verify"
    chain = db_client.get(verify, headers=_h(db_client)).json()
    assert chain["ok"] is True
    assert chain["length"] >= 4
