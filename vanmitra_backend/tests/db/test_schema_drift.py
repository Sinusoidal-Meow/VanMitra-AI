"""The migrations build exactly the schema the models describe (what `alembic check` tests)."""

from typing import Any

from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy.orm import Session, sessionmaker

from app.models.base import Base


def _ours(obj: Any, name: str | None, type_: str, reflected: bool, compare_to: Any) -> bool:
    # Same filter as migrations/env.py: ignore PostGIS extension tables.
    return not (type_ == "table" and reflected and compare_to is None)


def test_models_match_migrations(session_factory: sessionmaker[Session]) -> None:
    with session_factory() as db:
        mc = MigrationContext.configure(
            db.connection(), opts={"compare_type": True, "include_object": _ours}
        )
        diff = compare_metadata(mc, Base.metadata)
    assert diff == []
