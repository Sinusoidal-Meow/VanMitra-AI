"""
The shape of every stored record (a "document" in MongoDB), ids and timestamps.

Each kind of record is a Pydantic model with a COLLECTION name. Records are converted
to MongoDB form by `to_mongo()` and back by `from_mongo()`:
- the id is stored as `_id` (a UUIDv7, so ids sort in creation order);
- calendar dates are stored as "YYYY-MM-DD" text, times in UTC to the millisecond
  (MongoDB keeps milliseconds only, and the hash chain must see exactly what is stored);
- enum values are stored as their text, decimals as Decimal128.
"""

import uuid
from collections.abc import Mapping
from datetime import UTC, date, datetime
from decimal import Decimal
from enum import Enum
from typing import Annotated, Any, ClassVar, Self

import uuid6
from pydantic import AfterValidator, BaseModel, ConfigDict, Field


def new_id() -> uuid.UUID:
    """Time-ordered UUIDv7 (BACKEND_PLAN B-09). Devices mint the same kind offline."""
    return uuid.UUID(bytes=uuid6.uuid7().bytes)


def to_ms(moment: datetime) -> datetime:
    """The moment in UTC, cut to whole milliseconds (what MongoDB stores)."""
    aware = moment if moment.tzinfo else moment.replace(tzinfo=UTC)
    utc = aware.astimezone(UTC)
    return utc.replace(microsecond=(utc.microsecond // 1000) * 1000)


def now_ms() -> datetime:
    return to_ms(datetime.now(UTC))


def bson_ready(value: Any) -> Any:
    """Plain values MongoDB stores exactly and gives back unchanged."""
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, datetime):
        return to_ms(value)
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, dict):
        return {str(k): bson_ready(v) for k, v in value.items()}
    if isinstance(value, list | tuple | set | frozenset):
        return [bson_ready(v) for v in value]
    return value  # str, int, float, bool, None, UUID, Decimal


class Part(BaseModel):
    """A piece stored inside a record (a form, a list entry), not on its own."""

    model_config = ConfigDict(extra="ignore")


class Doc(BaseModel):
    """A record stored on its own in a MongoDB collection."""

    model_config = ConfigDict(extra="ignore")

    COLLECTION: ClassVar[str] = ""
    # Append-only records (rule C8) are never replaced or deleted by the server.
    APPEND_ONLY: ClassVar[bool] = False

    id: uuid.UUID = Field(default_factory=new_id)

    def to_mongo(self) -> dict[str, Any]:
        data: dict[str, Any] = bson_ready(self.model_dump(exclude={"id"}))
        return {"_id": self.id, **data}

    @classmethod
    def from_mongo(cls, raw: Mapping[str, Any]) -> Self:
        data = {k: v for k, v in raw.items() if k != "_id"}
        return cls.model_validate({"id": raw["_id"], **data})


class TimestampedDoc(Doc):
    """A record with created/updated times (updated_at moves on every saved change)."""

    created_at: datetime = Field(default_factory=now_ms)
    updated_at: datetime = Field(default_factory=now_ms)


def _places(places: str) -> Any:
    def quantize(value: Decimal | None) -> Decimal | None:
        return None if value is None else value.quantize(Decimal(places))

    return AfterValidator(quantize)


# Decimals rounded like the old database columns: Numeric(x, 2) and Numeric(x, 4).
Dec2 = Annotated[Decimal, _places("0.01")]
Dec4 = Annotated[Decimal, _places("0.0001")]
