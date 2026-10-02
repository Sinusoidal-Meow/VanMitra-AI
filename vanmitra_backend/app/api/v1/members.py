"""
Gram Sabha member roster.

Kept by the Gram Sabha Secretary [Rule 11(6)]. The same roster feeds the Form C member
sheet (item 5), FRC composition [Rule 3(1)] and the quorum count [Rule 4(2)], so it is
maintained once and used three times. Members are deactivated, never deleted.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy import select

from ...auth.deps import CurrentPrincipal, DbSession, require_village_role
from ...auth.principal import Principal
from ...errors import ApiError
from ...models import GramSabha, GsMember, Role
from ...schemas.members import MemberCreate, MemberOut, MemberUpdate

router = APIRouter(tags=["members"])

ROSTER_EDITORS = (Role.GS_SECRETARY,)


def _out(m: GsMember) -> MemberOut:
    return MemberOut(id=m.id, name=m.name, gender=m.gender, category=m.category, active=m.active)


def _gram_sabha(db: DbSession, village_id: uuid.UUID) -> GramSabha:
    gs = db.scalar(select(GramSabha).where(GramSabha.village_id == village_id))
    if gs is None:
        raise ApiError(409, "GRAM_SABHA_MISSING", "village.gram_sabha_missing")
    return gs


@router.get("/villages/{village_id}/members", response_model=list[MemberOut])
def list_members(
    village_id: uuid.UUID,
    db: DbSession,
    _: Annotated[Principal, Depends(require_village_role())],
    include_inactive: bool = False,
) -> list[MemberOut]:
    gs = _gram_sabha(db, village_id)
    query = select(GsMember).where(GsMember.gram_sabha_id == gs.id)
    if not include_inactive:
        query = query.where(GsMember.active.is_(True))
    return [_out(m) for m in db.scalars(query.order_by(GsMember.name)).all()]


@router.post(
    "/villages/{village_id}/members",
    response_model=MemberOut,
    status_code=status.HTTP_201_CREATED,
)
def add_member(
    village_id: uuid.UUID,
    body: MemberCreate,
    db: DbSession,
    _: Annotated[Principal, Depends(require_village_role(*ROSTER_EDITORS))],
) -> MemberOut:
    gs = _gram_sabha(db, village_id)
    member = GsMember(
        gram_sabha_id=gs.id,
        name=body.name,
        gender=body.gender,
        category=body.category,
        active=True,
    )
    db.add(member)
    db.commit()
    db.refresh(member)
    return _out(member)


@router.patch("/members/{member_id}", response_model=MemberOut)
def update_member(
    member_id: uuid.UUID,
    body: MemberUpdate,
    db: DbSession,
    principal: CurrentPrincipal,
) -> MemberOut:
    row = db.execute(
        select(GsMember, GramSabha.village_id)
        .join(GramSabha, GramSabha.id == GsMember.gram_sabha_id)
        .where(GsMember.id == member_id)
    ).first()
    if row is None or not principal.has(row[1]):
        raise ApiError(404, "MEMBER_NOT_FOUND", "member.not_found")
    member, village_id = row[0], row[1]
    if not principal.has(village_id, ROSTER_EDITORS):
        raise ApiError(403, "FORBIDDEN", "auth.forbidden_in_village", {"village_id": village_id})
    for field, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(member, field, value)
    db.commit()
    db.refresh(member)
    return _out(member)
