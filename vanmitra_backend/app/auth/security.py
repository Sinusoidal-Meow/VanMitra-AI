"""PIN hashing (Argon2) and JWT access/refresh tokens (BACKEND_PLAN B-02)."""

import uuid
from datetime import UTC, datetime, timedelta
from typing import Literal

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from ..config import get_settings
from ..errors import ApiError

TokenType = Literal["access", "refresh"]

_hasher = PasswordHasher()
# Verified against when the phone is unknown, so response time doesn't reveal it.
_DUMMY_HASH = _hasher.hash("000000")


def hash_pin(pin: str) -> str:
    return _hasher.hash(pin)


def verify_pin(pin_hash: str | None, pin: str) -> bool:
    try:
        return _hasher.verify(pin_hash or _DUMMY_HASH, pin) and pin_hash is not None
    except (VerificationError, InvalidHashError):
        return False


def create_token(user_id: uuid.UUID, token_type: TokenType, now: datetime | None = None) -> str:
    settings = get_settings()
    issued = now or datetime.now(UTC)
    lifetime = (
        timedelta(minutes=settings.access_token_minutes)
        if token_type == "access"  # noqa: S105 (token kind, not a secret)
        else timedelta(days=settings.refresh_token_days)
    )
    payload = {
        "sub": str(user_id),
        "type": token_type,
        "iat": issued,
        "exp": issued + lifetime,
        "jti": uuid.uuid4().hex,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str, expected_type: TokenType) -> uuid.UUID:
    """Return the user id in a valid token of the expected type, else raise 401."""
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
            options={"require": ["sub", "type", "exp"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise ApiError(401, "TOKEN_EXPIRED", "auth.token_expired") from exc
    except jwt.PyJWTError as exc:
        raise ApiError(401, "TOKEN_INVALID", "auth.token_invalid") from exc
    if payload.get("type") != expected_type:
        raise ApiError(401, "TOKEN_INVALID", "auth.token_invalid")
    try:
        return uuid.UUID(payload["sub"])
    except ValueError as exc:
        raise ApiError(401, "TOKEN_INVALID", "auth.token_invalid") from exc
