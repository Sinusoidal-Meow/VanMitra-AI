"""
Who is calling, and what they may do where.

Every role is held within a jurisdiction:
- village roles (villager, gram_sabha) cover one village;
- the SDO covers every village of a taluka (sub-division) in a district.
The district level is a separate website and has no logins here.

Admin is back-office only and does NOT bypass these checks.
"""

import uuid
from collections.abc import Iterable
from dataclasses import dataclass, field
from datetime import date

from ..models import Role


def _norm(name: str | None) -> str:
    return (name or "").strip().casefold()


@dataclass(frozen=True)
class VillageRef:
    """The parts of a village that jurisdiction depends on."""

    id: uuid.UUID
    taluka: str
    district: str


@dataclass(frozen=True)
class RoleGrant:
    role: Role
    village_id: uuid.UUID | None = None
    taluka: str | None = None
    district: str | None = None

    def covers(self, village: VillageRef) -> bool:
        if self.role in (Role.VILLAGER, Role.GRAM_SABHA):
            return self.village_id == village.id
        if self.role is Role.SDO:
            return _norm(self.taluka) == _norm(village.taluka) and _norm(self.district) == _norm(
                village.district
            )
        return _norm(self.district) == _norm(village.district)


@dataclass(frozen=True)
class Principal:
    user_id: uuid.UUID
    name: str = ""
    is_admin: bool = False
    grants: frozenset[RoleGrant] = field(default_factory=frozenset)

    def roles_for(self, village: VillageRef) -> set[Role]:
        """Roles whose jurisdiction includes this village."""
        return {g.role for g in self.grants if g.covers(village)}

    def has(self, village: VillageRef, roles: Iterable[Role] | None = None) -> bool:
        """True if the user holds any of `roles` (or any role at all) covering the village."""
        held = self.roles_for(village)
        if roles is None:
            return bool(held)
        return bool(held & set(roles))

    @property
    def roles(self) -> set[Role]:
        return {g.role for g in self.grants}


def active_grants(
    rows: Iterable[tuple[Role, uuid.UUID | None, str | None, str | None, date, date | None]],
    today: date,
) -> frozenset[RoleGrant]:
    """Keep grants valid today. Rows: (role, village_id, taluka, district, valid_from, valid_to)."""
    return frozenset(
        RoleGrant(role, village_id, taluka, district)
        for role, village_id, taluka, district, valid_from, valid_to in rows
        if valid_from <= today and (valid_to is None or today <= valid_to)
    )
