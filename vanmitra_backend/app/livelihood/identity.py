"""Who the signed-in user is, as this module sees them. Shared unchanged by the standalone app and
the host: only HOW a request becomes a UserInfo differs (see deps.py)."""

import uuid
from dataclasses import dataclass


@dataclass(frozen=True)
class UserInfo:
    id: uuid.UUID
    name: str
    village_id: str | None
    roles: frozenset[str]
