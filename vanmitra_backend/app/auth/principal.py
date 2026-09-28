"""
Who is calling, and what they may do where.

Access is always role + village: holding `frc_member` in Ozhar grants nothing in
any other village. Admin is back-office only and does NOT bypass these checks
(PROJECT_PLAN §3: admin cannot edit case content).
"""

import uuid
from collections.abc import Iterable
from dataclasses import dataclass, field
from datetime import date

from ..models import Role


@dataclass(frozen=True)
class RoleGrant:
    village_id: uuid.UUID
    role: Role


@dataclass(frozen=True)
class Principal:
    user_id: uuid.UUID
    is_admin: bool = False
    grants: frozenset[RoleGrant] = field(default_factory=frozenset)

    def village_ids(self) -> set[uuid.UUID]:
        return {g.village_id for g in self.grants}

    def roles_in(self, village_id: uuid.UUID) -> set[Role]:
        return {g.role for g in self.grants if g.village_id == village_id}

    def has(self, village_id: uuid.UUID, roles: Iterable[Role] | None = None) -> bool:
        """True if the user holds any of `roles` (or any role at all) in the village."""
        held = self.roles_in(village_id)
        if roles is None:
            return bool(held)
        return bool(held & set(roles))


def active_grants(
    rows: Iterable[tuple[uuid.UUID, Role, date, date | None]], today: date
) -> frozenset[RoleGrant]:
    """Keep only grants valid today. Rows are (village_id, role, valid_from, valid_to)."""
    return frozenset(
        RoleGrant(village_id, role)
        for village_id, role, valid_from, valid_to in rows
        if valid_from <= today and (valid_to is None or today <= valid_to)
    )
