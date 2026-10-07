"""
Uniform error responses.

Every error the API returns has the same shape, so the app can show a plain
local-language message instead of a raw code:

    {"error": "FRC_COMPOSITION_INVALID", "rule": "Rule 3(1)",
     "message_key": "frc.too_few_women", "details": {...}}

`rule` is present only when a statutory provision blocked the action.
"""

from typing import Any

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pymongo.errors import ConnectionFailure, DuplicateKeyError, PyMongoError
from starlette.exceptions import HTTPException as StarletteHTTPException


class ApiError(Exception):
    """A non-statutory error (auth, not found, bad input)."""

    def __init__(
        self,
        status_code: int,
        error: str,
        message_key: str,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(error)
        self.status_code = status_code
        self.error = error
        self.message_key = message_key
        self.details = details or {}


class RuleViolation(ApiError):
    """An action blocked by a provision of the Act, the Rules or the Guidelines."""

    def __init__(
        self,
        error: str,
        rule: str,
        message_key: str,
        details: dict[str, Any] | None = None,
        status_code: int = 409,
    ) -> None:
        super().__init__(status_code, error, message_key, details)
        self.rule = rule


def _body(exc: ApiError) -> dict[str, Any]:
    body: dict[str, Any] = {"error": exc.error, "message_key": exc.message_key}
    if isinstance(exc, RuleViolation):
        body["rule"] = exc.rule
    body["details"] = jsonable_encoder(exc.details)
    return body


async def _api_error(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, ApiError)
    return JSONResponse(status_code=exc.status_code, content=_body(exc))


async def _http_error(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, StarletteHTTPException)
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": f"HTTP_{exc.status_code}",
            "message_key": f"http.{exc.status_code}",
            "details": {},
            # Kept for the legacy endpoints, whose clients read FastAPI's "detail".
            "detail": exc.detail,
        },
        headers=getattr(exc, "headers", None),
    )


async def _validation_error(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, RequestValidationError)
    return JSONResponse(
        status_code=422,
        content={
            "error": "VALIDATION_ERROR",
            "message_key": "validation.invalid",
            "details": {"errors": jsonable_encoder(exc.errors())},
        },
    )


async def _database_error(_: Request, exc: Exception) -> JSONResponse:
    """MongoDB problems in the error format the app understands."""
    assert isinstance(exc, PyMongoError)
    if isinstance(exc, DuplicateKeyError):
        status, error, key = 409, "DUPLICATE", "db.duplicate"
    elif exc.has_error_label("TransientTransactionError"):
        # Two people changed the same record at the same moment; the other one won.
        status, error, key = 409, "WRITE_CONFLICT", "db.retry"
    elif isinstance(exc, ConnectionFailure):  # includes server selection timeouts
        status, error, key = 503, "DATABASE_UNAVAILABLE", "db.unavailable"
    else:
        status, error, key = 500, "DATABASE_ERROR", "db.error"
    return JSONResponse(
        status_code=status, content={"error": error, "message_key": key, "details": {}}
    )


def install_error_handlers(app: FastAPI) -> None:
    app.add_exception_handler(ApiError, _api_error)
    app.add_exception_handler(StarletteHTTPException, _http_error)
    app.add_exception_handler(RequestValidationError, _validation_error)
    app.add_exception_handler(PyMongoError, _database_error)
