"""
VanMitra backend: CFR claim module API.

Run locally:  uvicorn app.main:app --reload --port 8000
API docs:     http://localhost:8000/docs
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import __version__
from .api.v1 import router as v1_router
from .config import get_settings
from .errors import install_error_handlers
from .scheduler import run_expiry_checks


def create_app() -> FastAPI:
    settings = get_settings()

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        task = run_expiry_checks(settings.expiry_check_minutes)
        try:
            yield
        finally:
            if task is not None:
                task.cancel()

    app = FastAPI(
        lifespan=lifespan,
        title="VanMitra API",
        description=(
            "Community Forest Resource (CFR) claim module, Section 3(1)(i) FRA 2006. "
            "A community-side record system: it never decides a claim."
        ),
        version=__version__,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    install_error_handlers(app)
    app.include_router(v1_router)

    if settings.enable_legacy_api:
        # Imported lazily: it loads the ML models at import time.
        from .legacy.routes import router as legacy_router

        app.include_router(legacy_router)

    @app.get("/", include_in_schema=False)
    def root() -> dict[str, Any]:
        return {"service": "vanmitra-backend", "version": __version__, "docs": "/docs"}

    return app


app = create_app()
