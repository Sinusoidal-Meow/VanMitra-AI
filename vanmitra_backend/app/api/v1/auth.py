from datetime import UTC, date, datetime

from fastapi import APIRouter
from sqlalchemy import select

from ...auth.deps import CurrentUser, DbSession
from ...auth.security import create_token, decode_token, verify_pin
from ...config import get_settings
from ...errors import ApiError
from ...models import AppUser, UserRole, Village
from ...schemas.auth import LoginRequest, MeResponse, RefreshRequest, RoleOut, TokenPair

router = APIRouter(tags=["auth"])


def _token_pair(user: AppUser) -> TokenPair:
    return TokenPair(
        access_token=create_token(user.id, "access"),
        refresh_token=create_token(user.id, "refresh"),
        expires_in=get_settings().access_token_minutes * 60,
    )


@router.post("/auth/login", response_model=TokenPair)
def login(body: LoginRequest, db: DbSession) -> TokenPair:
    """Phone + 6-digit PIN → access and refresh tokens."""
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
    """The current user and the roles they hold today, per village."""
    rows = db.execute(
        select(UserRole, Village)
        .join(Village, Village.id == UserRole.village_id)
        .where(UserRole.user_id == user.id)
        .order_by(Village.name_en, UserRole.role)
    ).all()
    today = date.today()
    return MeResponse(
        id=user.id,
        name=user.name,
        phone=user.phone,
        is_admin=user.is_admin,
        roles=[
            RoleOut(
                village_id=village.id,
                village_name_mr=village.name_mr,
                village_name_en=village.name_en,
                role=grant.role,
                valid_from=grant.valid_from,
                valid_to=grant.valid_to,
            )
            for grant, village in rows
            if grant.is_active_on(today)
        ],
    )
