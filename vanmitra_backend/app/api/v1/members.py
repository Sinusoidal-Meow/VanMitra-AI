"""
Gram Sabha member roster.

Kept by the Gram Panchayat / Gram Sabha office [Rule 11(6)]. It feeds the Form C member
sheet (item 5). Members are deactivated, never deleted.
"""

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Depends, status

from ...auth.deps import CurrentPrincipal, DbSession, require_village_role, village_ref
from ...auth.principal import Principal
from ...errors import ApiError
from ...models import GramSabha, GsMember, Role, Village
from ...schemas.members import MemberCreate, MemberOut, MemberUpdate

router = APIRouter(tags=["members"])

ROSTER_EDITORS = (Role.GRAM_SABHA,)


def _out(m: GsMember) -> MemberOut:
    return MemberOut(id=m.id, name=m.name, gender=m.gender, category=m.category, active=m.active)


def _gram_sabha(db: DbSession, village_id: uuid.UUID) -> GramSabha:
    gs = db.find_one(GramSabha, {"village_id": village_id})
    if gs is None:
        raise ApiError(409, "GRAM_SABHA_MISSING", "village.gram_sabha_missing")
    return gs


@router.get("/villages/{village_id}/members", response_model=list[MemberOut])
def list_members(
    db: DbSession,
    scope: Annotated[tuple[Principal, Village], Depends(require_village_role())],
    include_inactive: bool = False,
) -> list[MemberOut]:
    gs = _gram_sabha(db, scope[1].id)
    query: dict[str, Any] = {"gram_sabha_id": gs.id}
    if not include_inactive:
        query["active"] = True
    rows = db.find(GsMember, query, sort=[("name", 1)])
    return [_out(m) for m in rows]


@router.post(
    "/villages/{village_id}/members",
    response_model=MemberOut,
    status_code=status.HTTP_201_CREATED,
)
def add_member(
    body: MemberCreate,
    db: DbSession,
    scope: Annotated[tuple[Principal, Village], Depends(require_village_role(*ROSTER_EDITORS))],
) -> MemberOut:
    gs = _gram_sabha(db, scope[1].id)
    member = GsMember(
        gram_sabha_id=gs.id,
        name=body.name,
        gender=body.gender,
        category=body.category,
        active=True,
    )
    db.add(member)
    db.commit()
    return _out(member)


@router.patch("/members/{member_id}", response_model=MemberOut)
def update_member(
    member_id: uuid.UUID,
    body: MemberUpdate,
    db: DbSession,
    principal: CurrentPrincipal,
) -> MemberOut:
    member = db.get(GsMember, member_id)
    if member is None:
        raise ApiError(404, "MEMBER_NOT_FOUND", "member.not_found")
    gs = db.get(GramSabha, member.gram_sabha_id)
    village = db.get(Village, gs.village_id) if gs else None
    if village is None or not principal.has(village_ref(village)):
        raise ApiError(404, "MEMBER_NOT_FOUND", "member.not_found")
    if not principal.has(village_ref(village), ROSTER_EDITORS):
        raise ApiError(403, "FORBIDDEN", "auth.forbidden_in_village", {"village_id": village.id})
    for field, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(member, field, value)
    db.commit()
    return _out(member)
