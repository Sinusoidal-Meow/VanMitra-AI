"""Registration (village users), login, token refresh and the current user."""

from datetime import UTC, date, datetime

from fastapi import APIRouter, status
from sqlalchemy import select

from ...auth.deps import CurrentUser, DbSession
from ...auth.security import create_token, decode_token, hash_pin, verify_pin
from ...config import get_settings
from ...errors import ApiError
from ...models import AppUser, Role, UserRole, Village
from ...schemas.auth import (
    LoginRequest,
    MeResponse,
    PublicVillage,
    RefreshRequest,
    RegisterRequest,
    RoleOut,
    TokenPair,
)

router = APIRouter(tags=["auth"])


def _token_pair(user: AppUser) -> TokenPair:
    return TokenPair(
        access_token=create_token(user.id, "access"),
        refresh_token=create_token(user.id, "refresh"),
        expires_in=get_settings().access_token_minutes * 60,
    )


@router.get("/public/villages", response_model=list[PublicVillage])
def public_villages(db: DbSession) -> list[PublicVillage]:
    """Villages a claimant can register in (names and jurisdiction only; no personal data)."""
    rows = db.scalars(select(Village).order_by(Village.district, Village.taluka, Village.name_en))
    return [
        PublicVillage(
            id=v.id,
            name_mr=v.name_mr,
            name_en=v.name_en,
            gram_panchayat=v.gram_panchayat,
            taluka=v.taluka,
            district=v.district,
        )
        for v in rows
    ]


@router.post("/auth/register", response_model=TokenPair, status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: DbSession) -> TokenPair:
    """
    A village user (claimant) registers with phone + 6-digit PIN and picks their village.
    Gram Sabha, SDO and district officer accounts are created by an admin only.
    """
    if db.get(Village, body.village_id) is None:
        raise ApiError(422, "VILLAGE_NOT_FOUND", "village.not_found")
    if db.scalar(select(AppUser.id).where(AppUser.phone == body.phone)) is not None:
        raise ApiError(409, "PHONE_ALREADY_REGISTERED", "auth.phone_taken")
    user = AppUser(phone=body.phone, name=body.name.strip(), pin_hash=hash_pin(body.pin))
    db.add(user)
    db.flush()
    db.add(UserRole(user_id=user.id, village_id=body.village_id, role=Role.VILLAGER))
    user.last_login_at = datetime.now(UTC)
    db.commit()
    return _token_pair(user)


@router.post("/auth/login", response_model=TokenPair)
def login(body: LoginRequest, db: DbSession) -> TokenPair:
    """Phone + 6-digit PIN → access and refresh tokens (all three levels log in here)."""
    user = db.scalar(select(AppUser).where(AppUser.phone == body.phone))
    # verify_pin always runs, so an unknown phone takes as long as a wrong PIN.
    pin_ok = verify_pin(user.pin_hash if user else None, body.pin)
    if user is None or not pin_ok or not user.is_active:
        raise ApiError(401, "INVALID_CREDENTIALS", "auth.invalid_credentials")
    user.last_login_at = datetime.now(UTC)
    db.commit()
    return _token_pair(user)


@router.post("/auth/refresh", response_model=TokenPair)
def refresh(body: RefreshRequest, db: DbSession) -> TokenPair:
    user = db.get(AppUser, decode_token(body.refresh_token, "refresh"))
    if user is None or not user.is_active:
        raise ApiError(401, "NOT_AUTHENTICATED", "auth.required")
    return _token_pair(user)


@router.get("/me", response_model=MeResponse)
def me(user: CurrentUser, db: DbSession) -> MeResponse:
    """The current user and the roles they hold today, with jurisdiction and level."""
    rows = db.execute(
        select(UserRole, Village)
        .outerjoin(Village, Village.id == UserRole.village_id)
        .where(UserRole.user_id == user.id)
        .order_by(UserRole.role)
    ).all()
    today = date.today()
    return MeResponse(
        id=user.id,
        name=user.name,
        phone=user.phone,
        is_admin=user.is_admin,
        roles=[
            RoleOut(
                role=grant.role,
                level=grant.role.level,
                village_id=grant.village_id,
                village_name_mr=village.name_mr if village else None,
                village_name_en=village.name_en if village else None,
                taluka=village.taluka if village else grant.taluka,
                district=village.district if village else grant.district,
                valid_from=grant.valid_from,
                valid_to=grant.valid_to,
            )
            for grant, village in rows
            if grant.is_active_on(today)
        ],
    )
