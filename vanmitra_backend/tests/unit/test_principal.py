import uuid
from datetime import date

import pytest

from app.auth.deps import require_village_role
from app.auth.principal import Principal, RoleGrant, active_grants
from app.errors import ApiError
from app.models import Role

OZHAR = uuid.uuid4()
OTHER = uuid.uuid4()
TODAY = date(2026, 9, 28)


def _principal(*grants: RoleGrant, is_admin: bool = False) -> Principal:
    return Principal(user_id=uuid.uuid4(), is_admin=is_admin, grants=frozenset(grants))


def test_role_is_scoped_to_its_village() -> None:
    p = _principal(RoleGrant(OZHAR, Role.FRC_MEMBER))
    assert p.has(OZHAR, [Role.FRC_MEMBER])
    assert p.has(OZHAR)
    assert not p.has(OTHER)
    assert not p.has(OTHER, [Role.FRC_MEMBER])


def test_wrong_role_in_right_village() -> None:
    p = _principal(RoleGrant(OZHAR, Role.FACILITATOR))
    assert not p.has(OZHAR, [Role.GS_SECRETARY, Role.FRC_MEMBER])


def test_one_person_can_hold_several_roles() -> None:
    p = _principal(RoleGrant(OZHAR, Role.FRC_MEMBER), RoleGrant(OZHAR, Role.GS_SECRETARY))
    assert p.roles_in(OZHAR) == {Role.FRC_MEMBER, Role.GS_SECRETARY}


def test_active_grants_respects_validity_dates() -> None:
    rows = [
        (OZHAR, Role.FRC_MEMBER, date(2026, 1, 1), None),  # open-ended: active
        (OZHAR, Role.GS_SECRETARY, date(2025, 1, 1), date(2026, 6, 30)),  # ended: inactive
        (OTHER, Role.FACILITATOR, date(2026, 10, 1), None),  # starts later: inactive
        (OTHER, Role.FRC_MEMBER, date(2026, 9, 1), TODAY),  # ends today: active
    ]
    assert active_grants(rows, TODAY) == frozenset(
        {RoleGrant(OZHAR, Role.FRC_MEMBER), RoleGrant(OTHER, Role.FRC_MEMBER)}
    )


def test_require_village_role_allows_and_denies() -> None:
    check = require_village_role(Role.GS_SECRETARY)
    secretary = _principal(RoleGrant(OZHAR, Role.GS_SECRETARY))
    assert check(OZHAR, secretary) is secretary
    with pytest.raises(ApiError) as exc:
        check(OTHER, secretary)
    assert exc.value.status_code == 403


def test_admin_does_not_bypass_village_roles() -> None:
    """PROJECT_PLAN §3: admin is back-office only, with no access to case content."""
    admin = _principal(is_admin=True)
    with pytest.raises(ApiError):
        require_village_role()(OZHAR, admin)
