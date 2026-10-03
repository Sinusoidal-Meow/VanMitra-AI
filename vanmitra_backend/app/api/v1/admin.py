"""
Back-office account management (admin only).

Creates Gram Sabha and government logins with their jurisdiction. Admin never sees or
edits case content.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy import select

from ...auth.deps import DbSession, require_admin
from ...auth.principal import Principal
from ...auth.security import hash_pin
from ...errors import ApiError
from ...models import DISTRICT_ROLES, AppUser, Role, UserRole, Village
from ...schemas.auth import OfficialCreate, UserOut

router = APIRouter(prefix="/admin", tags=["admin"])

AdminOnly = Annotated[Principal, Depends(require_admin)]


def _scope(body: OfficialCreate, db: DbSession) -> tuple[Village | None, str | None, str | None]:
    """Validate and normalise the jurisdiction for the role."""
    if body.role in (Role.VILLAGER, Role.GRAM_SABHA):
        village = db.get(Village, body.village_id) if body.village_id else None
        if village is None:
            raise ApiError(422, "VILLAGE_REQUIRED", "admin.village_required")
        return village, None, None
    if body.role is Role.SDO:
        if not (body.taluka and body.district):
            raise ApiError(422, "TALUKA_AND_DISTRICT_REQUIRED", "admin.taluka_district_required")
        return None, body.taluka.strip(), body.district.strip()
    if body.role in DISTRICT_ROLES:
        if not body.district:
            raise ApiError(422, "DISTRICT_REQUIRED", "admin.district_required")
        return None, None, body.district.strip()
    raise ApiError(422, "UNKNOWN_ROLE", "admin.unknown_role")


@router.post("/users", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def create_user(body: OfficialCreate, db: DbSession, _: AdminOnly) -> UserOut:
    village, taluka, district = _scope(body, db)
    if db.scalar(select(AppUser.id).where(AppUser.phone == body.phone)) is not None:
        raise ApiError(409, "PHONE_ALREADY_REGISTERED", "auth.phone_taken")
    user = AppUser(phone=body.phone, name=body.name.strip(), pin_hash=hash_pin(body.pin))
    db.add(user)
    db.flush()
    grant = UserRole(
        user_id=user.id,
        role=body.role,
        village_id=village.id if village else None,
        taluka=taluka,
        district=district,
    )
    db.add(grant)
    db.commit()
    return UserOut(
        id=user.id,
        name=user.name,
        phone=user.phone,
        role=body.role,
        village_id=grant.village_id,
        taluka=taluka,
        district=district,
    )


@router.get("/users", response_model=list[UserOut])
def list_users(db: DbSession, _: AdminOnly) -> list[UserOut]:
    rows = db.execute(
        select(AppUser, UserRole)
        .join(UserRole, UserRole.user_id == AppUser.id)
        .order_by(UserRole.role, AppUser.name)
    ).all()
    return [
        UserOut(
            id=u.id,
            name=u.name,
            phone=u.phone,
            role=r.role,
            village_id=r.village_id,
            taluka=r.taluka,
            district=r.district,
        )
        for u, r in rows
    ]
