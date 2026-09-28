from datetime import UTC, datetime
from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from ... import __version__
from ...config import get_settings
from ...db import get_engine

router = APIRouter(tags=["health"])


class HealthResponse(BaseModel):
    status: Literal["ok"]
    service: str
    version: str
    time: datetime
    database: Literal["ok", "unavailable"]
    legacy_api: bool


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    """
    Always 200 while the process is up (the app treats 200 as reachable).
    `database` reports whether PostgreSQL answered a `SELECT 1`.
    """
    try:
        with get_engine().connect() as conn:
            conn.execute(text("SELECT 1"))
        database: Literal["ok", "unavailable"] = "ok"
    except SQLAlchemyError:
        database = "unavailable"
    return HealthResponse(
        status="ok",
        service="vanmitra-backend",
        version=__version__,
        time=datetime.now(UTC),
        database=database,
        legacy_api=get_settings().enable_legacy_api,
    )
