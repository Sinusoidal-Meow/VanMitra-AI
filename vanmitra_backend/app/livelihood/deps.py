"""
THE ONLY FILE THAT DIFFERS FROM THE STANDALONE MODULE 4 REPO (docs/INTEGRATION.md there).

It answers the two questions the routes ask, using the host's own machinery:
- `CurrentUser`: who is calling? The host login (JWT, `AppUser`) and the role grants in
  `user_role`. Only `villager` and `gram_sabha` users may use this module, each for their OWN
  land, and their village comes from that grant, never from the request.
- `get_store`: where is the data? The host's MongoDB database, through `get_database()`.

Routes and tests override these two names with `app.dependency_overrides`.
"""

from typing import Annotated

from fastapi import Depends

from ..auth.deps import CurrentPrincipal
from ..auth.deps import CurrentUser as HostUser
from ..errors import ApiError
from ..models import Role
from ..mongo import get_database
from .identity import UserInfo
from .mongo_store import MongoStore
from .store import LivelihoodStore

_SERVED_ROLES = (Role.VILLAGER, Role.GRAM_SABHA)


def get_user_info(user: HostUser, principal: CurrentPrincipal) -> UserInfo:
    """The signed-in user as this module sees them, or 403 if their role has no use for it."""
    grants = [g for g in principal.grants if g.role in _SERVED_ROLES and g.village_id is not None]
    if not grants:
        raise ApiError(403, "FORBIDDEN", "livelihood.role_not_allowed")
    # a person who is both a villager and a Gram Sabha user is served as the villager (their own
    # land); ties are broken by village id so the choice is stable
    chosen = min(grants, key=lambda g: (g.role is not Role.VILLAGER, str(g.village_id)))
    return UserInfo(
        id=user.id,
        name=user.name,
        village_id=str(chosen.village_id),
        roles=frozenset(g.role.value for g in grants),
    )


CurrentUser = Annotated[UserInfo, Depends(get_user_info)]


def get_store() -> LivelihoodStore:
    """One cheap store object per request over the host's database."""
    return MongoStore(get_database())
