import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.auth.security import create_token, decode_token, hash_pin, verify_pin
from app.config import get_settings
from app.errors import ApiError


def test_pin_hash_roundtrip() -> None:
    h = hash_pin("123456")
    assert h != "123456"
    assert verify_pin(h, "123456")
    assert not verify_pin(h, "654321")


def test_unknown_user_never_verifies_even_with_dummy_pin() -> None:
    assert not verify_pin(None, "000000")
    assert not verify_pin(None, "123456")


def test_corrupt_hash_is_rejected_not_raised() -> None:
    assert not verify_pin("not-an-argon2-hash", "123456")


def test_access_token_roundtrip() -> None:
    uid = uuid.uuid4()
    assert decode_token(create_token(uid, "access"), "access") == uid


def test_refresh_token_cannot_be_used_as_access() -> None:
    token = create_token(uuid.uuid4(), "refresh")
    with pytest.raises(ApiError) as exc:
        decode_token(token, "access")
    assert exc.value.status_code == 401
    assert exc.value.error == "TOKEN_INVALID"


def test_expired_token() -> None:
    long_ago = datetime.now(UTC) - timedelta(days=365)
    token = create_token(uuid.uuid4(), "access", now=long_ago)
    with pytest.raises(ApiError) as exc:
        decode_token(token, "access")
    assert exc.value.error == "TOKEN_EXPIRED"


def test_token_signed_with_another_secret() -> None:
    forged = jwt.encode(
        {"sub": str(uuid.uuid4()), "type": "access", "exp": datetime.now(UTC) + timedelta(hours=1)},
        "some-other-secret-that-is-long-enough",
        algorithm=get_settings().jwt_algorithm,
    )
    with pytest.raises(ApiError) as exc:
        decode_token(forged, "access")
    assert exc.value.error == "TOKEN_INVALID"


def test_token_with_bad_subject() -> None:
    bad = jwt.encode(
        {"sub": "not-a-uuid", "type": "access", "exp": datetime.now(UTC) + timedelta(hours=1)},
        get_settings().jwt_secret,
        algorithm=get_settings().jwt_algorithm,
    )
    with pytest.raises(ApiError):
        decode_token(bad, "access")
