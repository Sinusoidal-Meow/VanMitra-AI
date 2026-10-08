"""
Call for claims, acknowledgement, media, the evidence ledger with verification and
recusal, letters, readiness and the hash chain, against the test database.
The tests in this module run in order and share one CFR case.
"""

import uuid
from datetime import date, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.domain.dates import add_months
from app.models import AppUser, Gender, GramSabha, GsMember, MemberCategory, Role
from app.models.procedure import Evidence, LedgerEntry, Recusal
from app.mongo import AppendOnlyError

from .conftest import StoreMaker, auth_headers, make_user, make_village, new_case

GS, GS_CLAIMANT, VILLAGER, OUTSIDER = "9600000001", "9600000002", "9600000003", "9600000004"
TODAY = date.today()
PDF = b"%PDF-1.4 test scan of a 7/12 extract"

FORM_C: dict[str, Any] = {
    "area_description": "Customary forest north of the village up to the ridge",
    "approx_area_ha": 120.5,
    "landmarks": [
        {"side": "east", "kind": "stream", "name": "Nala"},
        {"side": "west", "kind": "road", "name": "Road"},
        {"side": "north", "kind": "hill", "name": "Ridge"},
        {"side": "south", "kind": "pond", "name": "Talav"},
    ],
    "khasra_compartment_numbers": ["210"],
    "bordering_villages": [{"name": "Kurlod", "shares_resources": True}],
    "evidence": [{"rule_ref": "13(2)(a)", "description": "Nistar patrak"}],
}


@pytest.fixture(scope="module")
def ctx(session_factory: StoreMaker) -> dict[str, Any]:
    with session_factory() as db:
        village = make_village(db, "EvidenceVillage")
        other = make_village(db, "EvidenceOther")
        make_user(db, GS, Role.GRAM_SABHA, village=village)
        claimant_user = make_user(db, GS_CLAIMANT, Role.GRAM_SABHA, village=village)
        make_user(db, VILLAGER, Role.VILLAGER, village=village)
        make_user(db, OUTSIDER, Role.GRAM_SABHA, village=other)
        gs = db.find_one(GramSabha, {"village_id": village.id})
        assert gs is not None
        elder = GsMember(
            gram_sabha_id=gs.id, name="Elder", gender=Gender.MALE,
            category=MemberCategory.ST, active=True,
        )  # fmt: skip
        claimant = GsMember(
            gram_sabha_id=gs.id, name="Claimant", gender=Gender.FEMALE,
            category=MemberCategory.ST, active=True,
        )  # fmt: skip
        db.add_all([elder, claimant])
        claimant_user.gs_member_id = claimant.id
        db.commit()
        return {
            "village": village.id,
            "gs": gs.id,
            "elder": str(elder.id),
            "claimant": str(claimant.id),
        }


def _gs(client: TestClient) -> dict[str, str]:
    return auth_headers(client, GS)


def test_call_for_claims_and_extension(db_client: TestClient, ctx: dict[str, Any]) -> None:
    url = f"/api/v1/villages/{ctx['village']}/claim-calls"
    called = TODAY - timedelta(days=10)
    body = {"called_on": called.isoformat(), "place_of_filing": "Gram Panchayat office"}
    assert (
        db_client.post(url, json=body, headers=auth_headers(db_client, VILLAGER)).status_code == 403
    )
    res = db_client.post(url, json=body, headers=_gs(db_client))
    assert res.status_code == 201, res.text
    call = res.json()
    assert call["window_ends_on"] == add_months(called, 3).isoformat()
    assert call["is_open"] is True

    early = {"extended_to": called.isoformat(), "reason": "More time needed",
             "resolution_ref": "GS res 4/2026"}  # fmt: skip
    bad = db_client.post(f"{url}/current/extend", json=early, headers=_gs(db_client))
    assert bad.status_code == 409 and bad.json()["rule"] == "Rule 11(1)(a)"
    later = {**early, "extended_to": add_months(called, 4).isoformat()}
    ok = db_client.post(f"{url}/current/extend", json=later, headers=_gs(db_client))
    assert ok.status_code == 200, ok.text
    assert ok.json()["closes_on"] == later["extended_to"]
    current = db_client.get(f"{url}/current", headers=auth_headers(db_client, VILLAGER))
    assert current.json()["id"] == call["id"]


def test_gram_sabha_opens_cfr_case(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case_id = new_case(db_client, ctx["village"], GS, "cfr")
    ctx["case"] = case_id
    res = db_client.put(f"/api/v1/cases/{case_id}/form-c", json=FORM_C, headers=_gs(db_client))
    assert res.status_code == 200, res.text
    claimants = db_client.put(
        f"/api/v1/cases/{case_id}/claimants",
        json={"member_ids": [ctx["claimant"]]},
        headers=_gs(db_client),
    )
    assert claimants.status_code == 200, claimants.text


def test_media_upload(db_client: TestClient, ctx: dict[str, Any]) -> None:
    gs = _gs(db_client)
    res = db_client.post(
        "/api/v1/media",
        files={"file": ("712.pdf", PDF, "application/pdf")},
        data={"gps_lat": "19.9", "gps_lon": "73.2"},
        headers=gs,
    )
    assert res.status_code == 201, res.text
    ctx["media"] = res.json()["id"]
    assert len(res.json()["sha256"]) == 64
    exe = db_client.post(
        "/api/v1/media", files={"file": ("x.exe", b"MZ", "application/x-msdownload")}, headers=gs
    )
    assert exe.status_code == 415
    empty = db_client.post(
        "/api/v1/media", files={"file": ("e.pdf", b"", "application/pdf")}, headers=gs
    )
    assert empty.status_code == 422
    got = db_client.get(f"/api/v1/media/{ctx['media']}/file", headers=gs)
    assert got.status_code == 200 and got.content == PDF
    # not the uploader and not attached to any case they can see
    other = db_client.get(
        f"/api/v1/media/{ctx['media']}", headers=auth_headers(db_client, OUTSIDER)
    )
    assert other.status_code == 404


def _add(client: TestClient, case_id: str, body: dict[str, Any]) -> Any:
    return client.post(f"/api/v1/cases/{case_id}/evidence", json=body, headers=_gs(client))


def test_evidence_while_drafting(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case_id = ctx["case"]
    items = [
        {"rule_ref": "13(1)(a)", "kind": "document_scan", "description": "7/12 extract",
         "media_id": ctx["media"], "source_office": "Talathi", "doc_date": "1980-05-01"},
        {"rule_ref": "13(1)(g)", "kind": "photo", "description": "Old village well"},
        {"rule_ref": "13(2)(a)", "kind": "document_scan", "description": "Nistar patrak"},
        {"rule_ref": "13(1)(c)", "kind": "gps_point", "description": "Bund corner",
         "gps_lat": 19.91, "gps_lon": 73.21},
    ]  # fmt: skip
    ids = []
    for body in items:
        res = _add(db_client, case_id, body)
        assert res.status_code == 201, res.text
        ids.append(res.json()["id"])
    ctx["evidence"] = ids
    assert res.json()["is_substitutable"] is False  # the GPS point (BR-06)

    no_coords = {"rule_ref": "13(1)(c)", "kind": "gps_point", "description": "x"}
    assert _add(db_client, case_id, no_coords).status_code == 422
    stranger_media = {**items[1], "media_id": str(uuid.uuid4())}
    assert _add(db_client, case_id, stranger_media).json()["error"] == "MEDIA_NOT_YOURS"

    elder_body = {
        "rule_ref": "13(1)(i)",
        "kind": "elder_statement",
        "description": "Statement of the elder",
        "transcript": "We have used this forest since our grandfathers' time",
        "elder_member_id": ctx["claimant"],
        "signed_scan_media_id": ctx["media"],
    }
    claimant_elder = _add(db_client, case_id, elder_body)
    assert claimant_elder.status_code == 409
    assert claimant_elder.json()["rule"] == "Rule 13(1)(i)"
    elder = _add(db_client, case_id, {**elder_body, "elder_member_id": ctx["elder"]})
    assert elder.status_code == 201, elder.text
    ctx["elder_evidence"] = elder.json()["id"]

    villager = db_client.post(
        f"/api/v1/cases/{case_id}/evidence",
        json=items[1],
        headers=auth_headers(db_client, VILLAGER),
    )
    assert villager.status_code in (403, 404)
    early = db_client.post(
        f"/api/v1/cases/{case_id}/evidence/{ids[0]}/verify", headers=_gs(db_client)
    )
    assert early.json()["error"] == "NOT_UNDER_GS_REVIEW"
    not_acked = db_client.get(f"/api/v1/cases/{case_id}/acknowledgement", headers=_gs(db_client))
    assert not_acked.status_code == 409


def test_filing_issues_the_acknowledgement(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case_id = ctx["case"]
    res = db_client.post(f"/api/v1/cases/{case_id}/submit", headers=_gs(db_client))
    assert res.status_code == 200, res.text
    ack = db_client.get(f"/api/v1/cases/{case_id}/acknowledgement", headers=_gs(db_client))
    assert ack.status_code == 200, ack.text
    body = ack.json()
    assert body["serial"] == f"EVI/{TODAY.year}/0001"
    assert body["form"] == "C"
    assert body["filed_within_window"] is True
    assert len(body["documents_received"]) == 5


def test_verification_and_recusal(
    db_client: TestClient, ctx: dict[str, Any], session_factory: StoreMaker
) -> None:
    case_id = ctx["case"]
    url = f"/api/v1/cases/{case_id}/evidence"
    for eid in [*ctx["evidence"], ctx["elder_evidence"]]:
        res = db_client.post(
            f"{url}/{eid}/verify", json={"remarks": "Seen"}, headers=_gs(db_client)
        )
        assert res.status_code == 200, res.text
        assert res.json()["verified"] is True
    again = db_client.post(f"{url}/{ctx['evidence'][0]}/verify", headers=_gs(db_client))
    assert again.json()["error"] == "ALREADY_VERIFIED"

    recused = db_client.post(
        f"{url}/{ctx['evidence'][0]}/verify", headers=auth_headers(db_client, GS_CLAIMANT)
    )
    assert recused.status_code == 409 and recused.json()["rule"] == "Rule 3(3)"
    with session_factory() as db:
        claimant_user = db.find_one(AppUser, {"phone": GS_CLAIMANT})
        assert claimant_user is not None
        assert db.exists(
            Recusal,
            {"case_id": uuid.UUID(case_id), "gs_member_id": claimant_user.gs_member_id},
        )


def test_correction_supersedes(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case_id = ctx["case"]
    url = f"/api/v1/cases/{case_id}/evidence"
    old = ctx["evidence"][1]
    fixed = db_client.post(
        f"{url}/{old}/correct",
        json={"rule_ref": "13(1)(g)", "kind": "photo", "description": "Old village well (1952)",
              "correction_reason": "Year of construction added"},
        headers=_gs(db_client),
    )  # fmt: skip
    assert fixed.status_code == 201, fixed.text
    assert fixed.json()["supersedes_id"] == old
    ids = {e["id"] for e in db_client.get(url, headers=_gs(db_client)).json()}
    assert old not in ids and fixed.json()["id"] in ids
    every = db_client.get(f"{url}?include_superseded=true", headers=_gs(db_client)).json()
    assert next(e for e in every if e["id"] == old)["superseded"] is True
    stale = db_client.post(f"{url}/{old}/verify", headers=_gs(db_client))
    assert stale.json()["error"] == "ALREADY_SUPERSEDED"
    twice = db_client.post(
        f"{url}/{old}/correct",
        json={"rule_ref": "13(1)(g)", "kind": "photo", "description": "x",
              "correction_reason": "Second try"},
        headers=_gs(db_client),
    )  # fmt: skip
    assert twice.status_code == 409


def test_letters_and_readiness(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case_id = ctx["case"]
    readiness_url = f"/api/v1/cases/{case_id}/readiness"
    got = db_client.get(readiness_url, headers=_gs(db_client)).json()
    before = {i["id"]: i["ok"] for i in got["items"]}
    # The 7/12 extract and the elder's statement are two verified Rule 13(1) items.
    assert before == {
        "R1": True, "R2": True, "R3": False, "R4": False, "R5": False,
        "R6": True, "R7": False, "R8": False, "R9": True, "R10": True,
    }  # fmt: skip

    letters = f"/api/v1/villages/{ctx['village']}/letters"
    missing = db_client.post(
        letters,
        json={"template": "g2_intimation_adjoining", "addressee": "Sarpanch", "subject": "x"},
        headers=_gs(db_client),
    )
    assert missing.json()["error"] == "NEIGHBOUR_VILLAGE_REQUIRED"
    letter = db_client.post(
        letters,
        json={"template": "g2_intimation_adjoining", "addressee": "Sarpanch, Kurlod",
              "subject": "Intimation of CFR claim", "case_id": case_id,
              "neighbour_village": "Kurlod"},
        headers=_gs(db_client),
    )  # fmt: skip
    assert letter.status_code == 201, letter.text
    lid = letter.json()["id"]
    early = db_client.post(
        f"/api/v1/letters/{lid}/response",
        json={"received_on": TODAY.isoformat(), "outcome": "No objection"},
        headers=_gs(db_client),
    )
    assert early.json()["error"] == "RESPONSE_BEFORE_DISPATCH"
    sent = db_client.post(
        f"/api/v1/letters/{lid}/dispatch",
        json={"dispatched_on": (TODAY - timedelta(days=40)).isoformat()},
        headers=_gs(db_client),
    )
    assert sent.json()["reminder_due"] is True
    assert db_client.post(
        f"/api/v1/letters/{lid}/dispatch",
        json={"dispatched_on": TODAY.isoformat()},
        headers=auth_headers(db_client, OUTSIDER),
    ).status_code == 404  # fmt: skip

    fixed = db_client.get(f"/api/v1/cases/{case_id}/evidence", headers=_gs(db_client)).json()
    photo = next(e for e in fixed if e["supersedes_id"])
    db_client.post(f"/api/v1/cases/{case_id}/evidence/{photo['id']}/verify", headers=_gs(db_client))
    after = db_client.get(readiness_url, headers=_gs(db_client)).json()
    oks = {i["id"] for i in after["items"] if i["ok"]}
    assert {"R1", "R2", "R6", "R8", "R9", "R10"} <= oks
    assert after["claim_type"] == "cfr"


def test_ledger_chain_and_append_only(
    db_client: TestClient, ctx: dict[str, Any], session_factory: StoreMaker
) -> None:
    url = f"/api/v1/villages/{ctx['village']}/ledger/verify"
    report = db_client.get(url, headers=_gs(db_client)).json()
    # 6 evidence rows, 6 verifications, 1 submit event
    assert report["ok"] is True and report["length"] == 13, report
    assert db_client.get(url, headers=auth_headers(db_client, OUTSIDER)).status_code == 403

    eid = uuid.UUID(ctx["evidence"][0])
    # The server refuses to change or delete protected records.
    with session_factory() as db:
        item = db.get(Evidence, eid)
        assert item is not None
        item.description = "x"
        with pytest.raises(AppendOnlyError):
            db.commit()
    with session_factory() as db:
        link = db.find_one(LedgerEntry, {"gram_sabha_id": ctx["gs"]})
        assert link is not None
        with pytest.raises(AppendOnlyError):
            db.delete(link)

    # An edit made directly in the database, outside the server, is caught by the chain.
    with session_factory() as db:
        db.collection(Evidence).update_one({"_id": eid}, {"$set": {"description": "forged"}})
    try:
        broken = db_client.get(url, headers=_gs(db_client)).json()
        assert broken["ok"] is False
        assert broken["reason"] == "record altered" and broken["broken_entity"] == "evidence"
    finally:
        with session_factory() as db:
            db.collection(Evidence).update_one(
                {"_id": eid}, {"$set": {"description": "7/12 extract"}}
            )
    assert db_client.get(url, headers=_gs(db_client)).json()["ok"] is True
