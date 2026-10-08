"""
Boundary versions, landmarks, use zones, walks and overlap disputes against the test
database (PostGIS). The tests in this module run in order and share two CFR cases in
neighbouring villages whose claims overlap.
"""

import uuid
from datetime import date, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.models import ClaimCase, Role

from .conftest import StoreMaker, auth_headers, make_user, make_village, new_case

GS_A, GS_B, VILLAGER_A, GS_C = "9700000001", "9700000002", "9700000003", "9700000004"
TODAY = date.today()


def square(x0: float, y0: float, x1: float, y1: float) -> dict[str, Any]:
    return {"type": "Polygon", "coordinates": [[[x0, y0], [x1, y0], [x1, y1], [x0, y1]]]}


A_SQUARE = square(73.20, 19.90, 73.21, 19.91)  # about 116 ha
B_SQUARE = square(73.205, 19.90, 73.215, 19.91)  # overlaps the east half of A
LANDMARKS = [
    (0, "stream", "Nagdevta nala", 73.205, 19.90),
    (1, "hill", "Waghoba dongar", 73.21, 19.905),
    (2, "road", "Jawhar road", 73.205, 19.91),
    (3, "sacred_place", "Devrai", 73.20, 19.905),
]


@pytest.fixture(scope="module")
def ctx(session_factory: StoreMaker) -> dict[str, Any]:
    with session_factory() as db:
        a = make_village(db, "BoundaryA")
        b = make_village(db, "BoundaryB")
        make_user(db, GS_A, Role.GRAM_SABHA, village=a)
        make_user(db, GS_B, Role.GRAM_SABHA, village=b)
        make_user(db, VILLAGER_A, Role.VILLAGER, village=a)
        db.commit()
        return {"a": a.id, "b": b.id}


def _h(client: TestClient, phone: str) -> dict[str, str]:
    return auth_headers(client, phone)


def test_invalid_shapes_are_refused(db_client: TestClient, ctx: dict[str, Any]) -> None:
    ctx["case_a"] = new_case(db_client, ctx["a"], GS_A, "cfr")
    url = f"/api/v1/cases/{ctx['case_a']}/boundary"
    crossed = [[73.2, 19.9], [73.21, 19.91], [73.21, 19.9], [73.2, 19.91]]
    bowtie = {"type": "Polygon", "coordinates": [crossed]}
    res = db_client.post(url, json={"polygon": bowtie}, headers=_h(db_client, GS_A))
    assert res.status_code == 422 and res.json()["error"] == "INVALID_GEOMETRY"
    short = {"type": "Polygon", "coordinates": [[[73.2, 19.9], [73.21, 19.9], [73.2, 19.9]]]}
    res = db_client.post(url, json={"polygon": short}, headers=_h(db_client, GS_A))
    assert res.status_code == 422
    bad_breaks = {"polygon": A_SQUARE, "segment_breaks": [0, 7]}
    assert db_client.post(url, json=bad_breaks, headers=_h(db_client, GS_A)).status_code == 422
    assert db_client.get(url, headers=_h(db_client, GS_A)).json()["error"] == "NO_BOUNDARY"


def test_boundary_with_four_segments(db_client: TestClient, ctx: dict[str, Any]) -> None:
    url = f"/api/v1/cases/{ctx['case_a']}/boundary"
    body = {"polygon": A_SQUARE, "segment_breaks": [0, 1, 2, 3],
            "vertex_accuracy_m": [4.0, 6.5, 22.0, None]}  # fmt: skip
    res = db_client.post(url, json=body, headers=_h(db_client, GS_A))
    assert res.status_code == 201, res.text
    b = res.json()
    assert b["version"] == 1 and b["status"] == "draft"
    assert 100 < float(b["area_ha"]) < 130
    assert len(b["segments"]) == 4 and b["segments_without_landmark"] == 4
    assert 1000 < b["segments"][0]["length_m"] < 1100  # 0.01° of longitude at 19.9° N
    assert b["accuracy_stats"]["over_limit"] == 1
    assert b["geometry"]["type"] == "Polygon"
    assert b["open_disputes"] == 0
    villager = db_client.post(url, json=body, headers=_h(db_client, VILLAGER_A))
    assert villager.status_code in (403, 404)


def test_landmark_per_segment(db_client: TestClient, ctx: dict[str, Any]) -> None:
    url = f"/api/v1/cases/{ctx['case_a']}/boundary/landmarks"
    for seq, kind, name, lon, lat in LANDMARKS:
        res = db_client.post(
            url,
            json={"segment_seq": seq, "kind": kind, "name": name, "lon": lon, "lat": lat},
            headers=_h(db_client, GS_A),
        )
        assert res.status_code == 201, res.text
        assert res.json()["distance_to_segment_m"] < 5
    far = db_client.post(
        url,
        json={"segment_seq": 9, "kind": "well", "name": "x", "lon": 73.2, "lat": 19.9},
        headers=_h(db_client, GS_A),
    )
    assert far.json()["error"] == "NO_SUCH_SEGMENT"
    b = db_client.get(f"/api/v1/cases/{ctx['case_a']}/boundary", headers=_h(db_client, GS_A))
    assert b.json()["segments_without_landmark"] == 0
    ready = db_client.get(f"/api/v1/cases/{ctx['case_a']}/readiness", headers=_h(db_client, GS_A))
    items = {i["id"]: i["ok"] for i in ready.json()["items"]}
    assert items["R4"] is True and items["R3"] is False and items["R10"] is True


def test_use_zone_and_walk(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case_url = f"/api/v1/cases/{ctx['case_a']}/boundary"
    zone = db_client.post(
        f"{case_url}/use-zones",
        json={"use_type": "grazing", "name": "Gurcharan", "season": "monsoon",
              "polygon": square(73.201, 19.901, 73.203, 19.903), "user_hamlets": ["Pada 1"]},
        headers=_h(db_client, GS_A),
    )  # fmt: skip
    assert zone.status_code == 201, zone.text
    assert zone.json()["within_boundary"] is True and float(zone.json()["area_ha"]) > 0

    walk = {
        "walked_on": (TODAY - timedelta(days=3)).isoformat(),
        "participants": [{"name": "Budhya Bhoye", "role": "elder"},
                         {"name": "Sita Wagh", "role": "frc"}],
        "trace": {"type": "LineString",
                  "coordinates": [[73.2, 19.9], [73.21, 19.9], [73.21, 19.91]]},
        "notes": "Walked from the nala to the road",
    }  # fmt: skip
    res = db_client.post(f"{case_url}/walks", json=walk, headers=_h(db_client, GS_A))
    assert res.status_code == 201, res.text
    assert res.json()["trace_length_m"] > 2000
    stranger = {**walk, "participants": [{"name": "X", "gs_member_id": str(uuid.uuid4())}]}
    bad = db_client.post(f"{case_url}/walks", json=stranger, headers=_h(db_client, GS_A))
    assert bad.json()["error"] == "PARTICIPANT_NOT_IN_ROSTER"
    assert len(db_client.get(f"{case_url}/walks", headers=_h(db_client, GS_A)).json()) == 1


def test_overlap_opens_a_dispute(db_client: TestClient, ctx: dict[str, Any]) -> None:
    ctx["case_b"] = new_case(db_client, ctx["b"], GS_B, "cfr")
    res = db_client.post(
        f"/api/v1/cases/{ctx['case_b']}/boundary",
        json={"polygon": B_SQUARE},
        headers=_h(db_client, GS_B),
    )
    assert res.status_code == 201, res.text
    assert res.json()["open_disputes"] == 1

    disputes = db_client.get(
        f"/api/v1/cases/{ctx['case_a']}/disputes", headers=_h(db_client, GS_A)
    ).json()
    assert len(disputes) == 1
    d = disputes[0]
    ctx["dispute"] = d["id"]
    assert d["is_open"] is True and d["neighbour_case_id"] == ctx["case_b"]
    assert "BoundaryB" in d["neighbour_village"]
    assert 50 < float(d["overlap_ha"]) < 65  # half of A
    assert d["overlap"]["type"] in ("Polygon", "MultiPolygon")

    # running the check from A's side finds the same dispute, not a second one
    again = db_client.post(
        f"/api/v1/cases/{ctx['case_a']}/boundary/conflicts/check", headers=_h(db_client, GS_A)
    )
    assert [x["id"] for x in again.json()] == [d["id"]]
    ready = db_client.get(f"/api/v1/cases/{ctx['case_a']}/readiness", headers=_h(db_client, GS_A))
    assert {i["id"]: i["ok"] for i in ready.json()["items"]}["R10"] is False


def test_joint_meeting_then_referral(db_client: TestClient, ctx: dict[str, Any]) -> None:
    base = f"/api/v1/cases/{ctx['case_a']}/disputes/{ctx['dispute']}"
    early = db_client.post(
        f"{base}/sdlc-referral",
        json={"referred_on": TODAY.isoformat(), "ref": "GS/2026/12"},
        headers=_h(db_client, GS_A),
    )
    assert early.status_code == 409 and early.json()["rule"] == "Rule 12(3)"
    meeting = db_client.post(
        f"{base}/joint-meeting",
        json={"held_on": TODAY.isoformat(), "outcome": "not_resolved",
              "findings": "Both villages graze the eastern slope; no agreement on the line"},
        headers=_h(db_client, GS_A),
    )  # fmt: skip
    assert meeting.status_code == 200, meeting.text
    assert meeting.json()["is_open"] is True  # not resolved: still blocks until referral

    # the neighbour's Gram Sabha reaches the same dispute through its own case
    b_side = f"/api/v1/cases/{ctx['case_b']}/disputes/{ctx['dispute']}/sdlc-referral"
    referred = db_client.post(
        b_side, json={"referred_on": TODAY.isoformat(), "ref": "GS/2026/12"},
        headers=_h(db_client, GS_B),
    )  # fmt: skip
    assert referred.status_code == 200, referred.text
    assert referred.json()["is_open"] is False
    twice = db_client.post(
        f"{base}/joint-meeting",
        json={"held_on": TODAY.isoformat(), "outcome": "agreed_shared", "findings": "Agreed"},
        headers=_h(db_client, GS_A),
    )
    assert twice.json()["error"] == "DISPUTE_REFERRED"
    ready = db_client.get(f"/api/v1/cases/{ctx['case_a']}/readiness", headers=_h(db_client, GS_A))
    assert {i["id"]: i["ok"] for i in ready.json()["items"]}["R10"] is True


def test_new_version_carries_landmarks_over(db_client: TestClient, ctx: dict[str, Any]) -> None:
    url = f"/api/v1/cases/{ctx['case_a']}/boundary"
    res = db_client.post(
        url, json={"polygon": A_SQUARE, "segment_breaks": [0, 2]}, headers=_h(db_client, GS_A)
    )
    assert res.status_code == 201, res.text
    b = res.json()
    assert b["version"] == 2 and len(b["segments"]) == 2
    assert sorted(lm["segment_seq"] for lm in b["landmarks"]) == [0, 1]
    assert len(b["use_zones"]) == 1
    versions = db_client.get(f"{url}/versions", headers=_h(db_client, GS_A)).json()
    assert [(v["version"], v["is_current"]) for v in versions] == [(1, False), (2, True)]
    lm = b["landmarks"][0]["id"]
    assert db_client.delete(f"{url}/landmarks/{lm}", headers=_h(db_client, GS_A)).status_code == 204


def test_a_claim_that_no_longer_stands_does_not_block_its_neighbour(
    db_client: TestClient, ctx: dict[str, Any], session_factory: StoreMaker
) -> None:
    with session_factory() as db:
        village_c = make_village(db, "BoundaryC")
        make_user(db, GS_C, Role.GRAM_SABHA, village=village_c)
        db.commit()
        village_c_id = village_c.id
    case_c = new_case(db_client, village_c_id, GS_C, "cfr")
    overlapping_a = square(73.20, 19.905, 73.21, 19.915)  # the north half of A
    res = db_client.post(
        f"/api/v1/cases/{case_c}/boundary",
        json={"polygon": overlapping_a},
        headers=_h(db_client, GS_C),
    )
    assert res.status_code == 201, res.text
    a_url = f"/api/v1/cases/{ctx['case_a']}"
    assert (
        db_client.get(f"{a_url}/boundary", headers=_h(db_client, GS_A)).json()["open_disputes"] == 1
    )

    # C's claim expires (the expiry itself is tested in test_expiry_flow)
    with session_factory() as db:
        db.collection(ClaimCase).update_one(
            {"_id": uuid.UUID(case_c)}, {"$set": {"state": "expired"}}
        )
    assert (
        db_client.get(f"{a_url}/boundary", headers=_h(db_client, GS_A)).json()["open_disputes"] == 0
    )
    with_c = [
        d
        for d in db_client.get(f"{a_url}/disputes", headers=_h(db_client, GS_A)).json()
        if d["neighbour_case_id"] == case_c
    ]
    assert with_c and not any(d["is_open"] for d in with_c)
    # and a fresh check does not open a new dispute with it
    check = db_client.post(f"{a_url}/boundary/conflicts/check", headers=_h(db_client, GS_A))
    assert not any(d["is_open"] for d in check.json())
