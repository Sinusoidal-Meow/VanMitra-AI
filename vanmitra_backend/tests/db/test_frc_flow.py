"""Village registry, FRC constitution and claimants against the test database."""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.models import Gender, GramSabha, GsMember, MemberCategory, Role

from .conftest import StoreMaker, auth_headers, make_user, make_village, new_case

ADMIN, GS, VILLAGER, SDO = "9500000004", "9500000003", "9500000001", "9500000005"


@pytest.fixture(scope="module")
def ctx(session_factory: StoreMaker) -> dict[str, Any]:
    with session_factory() as db:
        village = make_village(db, "FrcVillage")
        make_user(db, ADMIN, None)
        make_user(db, GS, Role.GRAM_SABHA, village=village)
        make_user(db, VILLAGER, Role.VILLAGER, village=village)
        make_user(db, SDO, Role.SDO, taluka="Jawhar", district="Palghar")
        gs = db.find_one(GramSabha, {"village_id": village.id})
        assert gs is not None
        roster: list[GsMember] = []
        # 6 ST women, 6 ST men, 3 OTFD men, 1 OTHER woman
        for i, (gender, cat) in enumerate(
            [(Gender.FEMALE, MemberCategory.ST)] * 6
            + [(Gender.MALE, MemberCategory.ST)] * 6
            + [(Gender.MALE, MemberCategory.OTFD)] * 3
            + [(Gender.FEMALE, MemberCategory.OTHER)]
        ):
            m = GsMember(
                gram_sabha_id=gs.id, name=f"Member {i}", gender=gender, category=cat, active=True
            )
            db.add(m)
            roster.append(m)
        db.commit()
        return {"village": village.id, "members": [m.id for m in roster]}


def _frc_body(ids: list[uuid.UUID]) -> dict[str, Any]:
    return {
        "constituted_on": "2026-08-15",
        "resolution_ref": "GS resolution 3/2026",
        "member_ids": [str(i) for i in ids],
        "chair_id": str(ids[0]),
        "secretary_id": str(ids[1]),
    }


def test_admin_registers_village_and_hamlet(db_client: TestClient, ctx: dict[str, Any]) -> None:
    admin = auth_headers(db_client, ADMIN)
    village = db_client.post(
        "/api/v1/admin/villages",
        json={"name_mr": "चांभारशेत", "name_en": "Chambharshet", "gram_panchayat": "Chambharshet",
              "taluka": "Jawhar", "district": "Palghar", "lgd_code": "551999"},
        headers=admin,
    )  # fmt: skip
    assert village.status_code == 201, village.text
    assert village.json()["gram_sabha_id"]
    hamlet = db_client.post(
        "/api/v1/admin/villages",
        json={"name_mr": "पाडा", "name_en": "Pada 1", "gram_panchayat": "Chambharshet",
              "taluka": "Jawhar", "district": "Palghar", "consolidation_status": "listed",
              "parent_village_id": village.json()["id"]},
        headers=admin,
    )  # fmt: skip
    assert hamlet.status_code == 201, hamlet.text
    dup = db_client.post(
        "/api/v1/admin/villages",
        json={"name_mr": "x", "name_en": "x", "gram_panchayat": "x", "taluka": "Jawhar",
              "district": "Palghar", "lgd_code": "551999"},
        headers=admin,
    )  # fmt: skip
    assert dup.status_code == 409
    # the SDO of Jawhar sees the hamlet list of the new village
    listed = db_client.get(
        f"/api/v1/villages/{village.json()['id']}/hamlets", headers=auth_headers(db_client, SDO)
    )
    assert [h["name_en"] for h in listed.json()] == ["Pada 1"]
    assert db_client.post(
        "/api/v1/admin/villages", json={}, headers=auth_headers(db_client, GS)
    ).status_code in (403, 422)


def test_frc_check_and_constitution(db_client: TestClient, ctx: dict[str, Any]) -> None:
    gs = auth_headers(db_client, GS)
    url = f"/api/v1/villages/{ctx['village']}/frc"
    members: list[uuid.UUID] = ctx["members"]

    # 6 ST women + 4 ST men = 10, all ST, 6 women: valid
    good = members[0:6] + members[6:10]
    check = db_client.post(f"{url}/check", json=_frc_body(good), headers=gs)
    assert check.status_code == 200 and check.json()["ok"] is True

    # 3 OTFD men + OTHER woman + 6 ST men: 6 ST of 10 < 7 required, 1 woman < 4
    bad = members[12:16] + members[6:12]
    refused = db_client.post(url, json=_frc_body(bad), headers=gs)
    assert refused.status_code == 409
    body = refused.json()
    assert body["rule"] == "Rule 3(1)"
    assert {"frc.too_few_st", "frc.too_few_women"} <= set(body["details"]["failures"])

    created = db_client.post(url, json=_frc_body(good), headers=gs)
    assert created.status_code == 201, created.text
    frc = created.json()
    assert frc["is_current"] and frc["composition"]["members"] == 10
    assert frc["members"][0]["is_chair"] is True

    intimated = db_client.post(
        f"{url}/intimation", json={"sdlc_intimated_on": "2026-08-20"}, headers=gs
    )
    assert intimated.json()["sdlc_intimated_on"] == "2026-08-20"

    # a second constitution supersedes the first
    again = db_client.post(url, json=_frc_body(members[0:6] + members[6:11]), headers=gs)
    assert again.status_code == 201
    history = db_client.get(f"{url}/history", headers=gs).json()
    assert [h["is_current"] for h in history] == [True, False]

    # the villager can read the FRC but not constitute one
    assert db_client.get(url, headers=auth_headers(db_client, VILLAGER)).status_code == 200
    assert (
        db_client.post(
            url, json=_frc_body(good), headers=auth_headers(db_client, VILLAGER)
        ).status_code
        == 403
    )


def test_frc_members_must_be_on_the_roster(db_client: TestClient, ctx: dict[str, Any]) -> None:
    body = _frc_body(ctx["members"][0:9] + [uuid.uuid4()])
    res = db_client.post(
        f"/api/v1/villages/{ctx['village']}/frc", json=body, headers=auth_headers(db_client, GS)
    )
    assert res.status_code == 422
    assert res.json()["error"] == "FRC_MEMBER_NOT_IN_ROSTER"


def test_claimants_are_roster_members(db_client: TestClient, ctx: dict[str, Any]) -> None:
    case_id = new_case(db_client, ctx["village"], VILLAGER, "ifr")
    me = auth_headers(db_client, VILLAGER)
    ids = [str(i) for i in ctx["members"][0:2]]
    res = db_client.put(f"/api/v1/cases/{case_id}/claimants", json={"member_ids": ids}, headers=me)
    assert res.status_code == 200, res.text
    assert len(res.json()) == 2
    stranger = db_client.put(
        f"/api/v1/cases/{case_id}/claimants", json={"member_ids": [str(uuid.uuid4())]}, headers=me
    )
    assert stranger.status_code == 422
    assert len(db_client.get(f"/api/v1/cases/{case_id}/claimants", headers=me).json()) == 2
