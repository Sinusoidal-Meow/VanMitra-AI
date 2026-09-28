"""FastAPI dependencies: current user, principal, role and village checks."""

import uuid
from collections.abc import Callable
from datetime import date
from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..errors import ApiError
from ..models import AppUser, Role, UserRole
from .principal import Principal, active_grants
from .security import decode_token

_bearer = HTTPBearer(auto_error=False)

DbSession = Annotated[Session, Depends(get_db)]


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
    rows = db.execute(
        select(UserRole.village_id, UserRole.role, UserRole.valid_from, UserRole.valid_to).where(
            UserRole.user_id == user.id
        )
    ).all()
    return Principal(
        user_id=user.id,
        is_admin=user.is_admin,
        grants=active_grants(((r[0], r[1], r[2], r[3]) for r in rows), date.today()),
    )


CurrentPrincipal = Annotated[Principal, Depends(get_principal)]


def require_village_role(*roles: Role) -> Callable[[uuid.UUID, Principal], Principal]:
    """
    Dependency for routes with a `village_id` path parameter.
    With no roles given, any role in the village is enough.

        @router.post("/villages/{village_id}/members")
        def add_member(p: Annotated[Principal, Depends(require_village_role(Role.GS_SECRETARY))]):
    """

    def dependency(village_id: uuid.UUID, principal: CurrentPrincipal) -> Principal:
        if not principal.has(village_id, roles or None):
            raise ApiError(
                403,
                "FORBIDDEN",
                "auth.forbidden_in_village",
                {"village_id": village_id, "required_roles": [r.value for r in roles]},
            )
        return principal

    return dependency


def require_admin(principal: CurrentPrincipal) -> Principal:
    """Back-office endpoints only (master data). Never for case content."""
    if not principal.is_admin:
        raise ApiError(403, "FORBIDDEN", "auth.admin_only")
    return principal
