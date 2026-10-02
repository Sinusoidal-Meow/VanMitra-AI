"""Roles are held within a jurisdiction: village, taluka (SDO) or district."""

import uuid
from datetime import date

from app.auth.principal import Principal, RoleGrant, VillageRef, active_grants
from app.models import Role

OZHAR = VillageRef(uuid.uuid4(), taluka="Jawhar", district="Palghar")
KHARONDA = VillageRef(uuid.uuid4(), taluka="Jawhar", district="Palghar")
DAHANU_VILLAGE = VillageRef(uuid.uuid4(), taluka="Dahanu", district="Palghar")
NASHIK_VILLAGE = VillageRef(uuid.uuid4(), taluka="Kalwan", district="Nashik")
TODAY = date(2026, 10, 3)


def _p(*grants: RoleGrant, is_admin: bool = False) -> Principal:
    return Principal(user_id=uuid.uuid4(), is_admin=is_admin, grants=frozenset(grants))


def test_village_roles_cover_one_village() -> None:
    p = _p(RoleGrant(Role.GRAM_SABHA, village_id=OZHAR.id))
    assert p.has(OZHAR, [Role.GRAM_SABHA])
    assert not p.has(KHARONDA)


def test_sdo_covers_the_whole_taluka_only() -> None:
    p = _p(RoleGrant(Role.SDO, taluka="Jawhar", district="Palghar"))
    assert p.has(OZHAR) and p.has(KHARONDA)
    assert not p.has(DAHANU_VILLAGE)
    assert not p.has(NASHIK_VILLAGE)


def test_sdo_jurisdiction_ignores_case_and_spaces() -> None:
    p = _p(RoleGrant(Role.SDO, taluka=" jawhar ", district="PALGHAR"))
    assert p.has(OZHAR)


def test_district_officers_cover_the_district() -> None:
    p = _p(RoleGrant(Role.COLLECTOR, district="Palghar"))
    assert p.has(OZHAR) and p.has(DAHANU_VILLAGE)
    assert not p.has(NASHIK_VILLAGE)


def test_roles_for_combines_grants() -> None:
    p = _p(
        RoleGrant(Role.VILLAGER, village_id=OZHAR.id),
        RoleGrant(Role.GRAM_SABHA, village_id=KHARONDA.id),
    )
    assert p.roles_for(OZHAR) == {Role.VILLAGER}
    assert p.roles_for(KHARONDA) == {Role.GRAM_SABHA}


def test_admin_does_not_bypass_jurisdiction() -> None:
    assert not _p(is_admin=True).has(OZHAR)


def test_active_grants_respects_validity_dates() -> None:
    rows = [
        (Role.SDO, None, "Jawhar", "Palghar", date(2026, 1, 1), None),  # active
        (Role.DFO, None, None, "Palghar", date(2025, 1, 1), date(2026, 6, 30)),  # ended
        (Role.VILLAGER, OZHAR.id, None, None, date(2026, 11, 1), None),  # future
    ]
    assert active_grants(rows, TODAY) == frozenset({RoleGrant(Role.SDO, None, "Jawhar", "Palghar")})


def test_role_levels() -> None:
    assert Role.VILLAGER.level == Role.GRAM_SABHA.level == "village"
    assert Role.SDO.level == "subdivision"
    assert {r.level for r in (Role.COLLECTOR, Role.DFO, Role.TRIBAL_WELFARE_OFFICER)} == {
        "district"
    }
