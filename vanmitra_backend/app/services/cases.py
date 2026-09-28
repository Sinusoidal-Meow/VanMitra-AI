"""Loading cases with the caller's village access checked."""

import uuid
from collections.abc import Iterable

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth.principal import Principal
from ..errors import ApiError
from ..models import ClaimCase, GramSabha, Role, Village


def load_case(
    db: Session,
    principal: Principal,
    case_id: uuid.UUID,
    roles: Iterable[Role] | None = None,
) -> tuple[ClaimCase, Village]:
    """
    The case and its village, if the caller holds a role in that village.
    No role there at all → 404 (existence is not revealed); wrong role → 403.
    """
    row = db.execute(
        select(ClaimCase, Village)
        .join(GramSabha, GramSabha.id == ClaimCase.gram_sabha_id)
        .join(Village, Village.id == GramSabha.village_id)
        .where(ClaimCase.id == case_id)
    ).first()
    if row is None or not principal.has(row[1].id):
        raise ApiError(404, "CASE_NOT_FOUND", "case.not_found")
    case, village = row[0], row[1]
    wanted = list(roles) if roles is not None else None
    if wanted and not principal.has(village.id, wanted):
        raise ApiError(
            403,
            "FORBIDDEN",
            "auth.forbidden_in_village",
            {"village_id": village.id, "required_roles": [r.value for r in wanted]},
        )
    return case, village
