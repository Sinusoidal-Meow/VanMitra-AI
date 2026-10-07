"""FastAPI dependencies: current user, principal, role and jurisdiction checks."""

import uuid
from collections.abc import Callable
from datetime import date
from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from ..db import Store, get_db
from ..errors import ApiError
from ..models import AppUser, Role, UserRole, Village
from .principal import Principal, VillageRef, active_grants
from .security import decode_token

_bearer = HTTPBearer(auto_error=False)

DbSession = Annotated[Store, Depends(get_db)]


def get_current_user(
    db: DbSession,
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> AppUser:
    if creds is None:
        raise ApiError(401, "NOT_AUTHENTICATED", "auth.required")
    user_id = decode_token(creds.credentials, "access")
    user = db.get(AppUser, user_id)
    if user is None or not user.is_active:
        raise ApiError(401, "NOT_AUTHENTICATED", "auth.required")
    return user


CurrentUser = Annotated[AppUser, Depends(get_current_user)]


def get_principal(db: DbSession, user: CurrentUser) -> Principal:
    grants = db.find(UserRole, {"user_id": user.id})
    return Principal(
        user_id=user.id,
        name=user.name,
        is_admin=user.is_admin,
        grants=active_grants(
            (
                (g.role, g.village_id, g.taluka, g.district, g.valid_from, g.valid_to)
                for g in grants
            ),
            date.today(),
        ),
    )


CurrentPrincipal = Annotated[Principal, Depends(get_principal)]


def village_ref(village: Village) -> VillageRef:
    return VillageRef(id=village.id, taluka=village.taluka, district=village.district)


def require_village_role(*roles: Role) -> Callable[..., tuple[Principal, Village]]:
    """
    Dependency for routes with a `village_id` path parameter. Returns (principal, village).
    With no roles given, any role whose jurisdiction covers the village is enough.
    """

    def dependency(
        village_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
    ) -> tuple[Principal, Village]:
        village = db.get(Village, village_id)
        if village is None:
            raise ApiError(404, "VILLAGE_NOT_FOUND", "village.not_found")
        if not principal.has(village_ref(village), roles or None):
            raise ApiError(
                403,
                "FORBIDDEN",
                "auth.forbidden_in_village",
                {"village_id": village_id, "required_roles": [r.value for r in roles]},
            )
        return principal, village

    return dependency


def require_admin(principal: CurrentPrincipal) -> Principal:
    """Back-office endpoints only (accounts, master data). Never for case content."""
    if not principal.is_admin:
        raise ApiError(403, "FORBIDDEN", "auth.admin_only")
    return principal
