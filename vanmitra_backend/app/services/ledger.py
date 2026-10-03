"""
Tamper-evident hash chain, one chain per Gram Sabha (Spec §6.8, rule C8):

    record_hash(n) = SHA256( canonical_json(payload(n)) || record_hash(n-1) )

`append` links a freshly inserted ledger row into its Gram Sabha's chain; `verify`
recomputes every link from the stored rows and reports the first break. The chain
head is kept on gram_sabha.chain_head_hash so it can be printed in the register.
"""

import hashlib
import json
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import Decimal
from enum import Enum
from typing import Any

from sqlalchemy import func, inspect, select
from sqlalchemy.orm import Session

from ..models import GramSabha
from ..models.base import Base
from ..models.procedure import LedgerEntry

GENESIS = "0" * 64


def _jsonable(value: Any) -> Any:
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, datetime):
        # Normalise to UTC: the database returns timestamps in the session time zone.
        aware = value if value.tzinfo else value.replace(tzinfo=UTC)
        return aware.astimezone(UTC).isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, list | tuple):
        return [_jsonable(v) for v in value]
    if isinstance(value, dict):
        return {str(k): _jsonable(v) for k, v in value.items()}
    return value


def canonical_payload(row: Base) -> str:
    """All column values of the row, sorted keys, no whitespace: stable across runs."""
    mapper = inspect(row).mapper
    data = {col.key: _jsonable(getattr(row, col.key)) for col in mapper.column_attrs}
    return json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def link_hash(payload: str, prev_hash: str) -> str:
    return hashlib.sha256((payload + prev_hash).encode("utf-8")).hexdigest()


def append(db: Session, gram_sabha_id: uuid.UUID, row: Base) -> LedgerEntry:
    """
    Add `row` (already added to the session) to the chain. Locks the Gram Sabha row so
    two writers cannot take the same sequence number.
    """
    db.flush()
    db.refresh(row)  # server defaults (created_at) are part of the hashed payload
    gs = db.execute(
        select(GramSabha).where(GramSabha.id == gram_sabha_id).with_for_update()
    ).scalar_one()
    prev = gs.chain_head_hash or GENESIS
    seq = (
        db.scalar(
            select(func.max(LedgerEntry.seq)).where(LedgerEntry.gram_sabha_id == gram_sabha_id)
        )
        or 0
    ) + 1
    entry = LedgerEntry(
        gram_sabha_id=gram_sabha_id,
        seq=seq,
        entity=row.__tablename__,
        entity_id=row.id,  # type: ignore[attr-defined]
        prev_hash=prev,
        record_hash=link_hash(canonical_payload(row), prev),
    )
    db.add(entry)
    gs.chain_head_hash = entry.record_hash
    return entry


@dataclass(frozen=True)
class ChainReport:
    ok: bool
    length: int
    head: str
    broken_at_seq: int | None
    broken_entity: str | None
    reason: str | None


def verify(db: Session, gram_sabha_id: uuid.UUID) -> ChainReport:
    tables = {m.class_.__tablename__: m.class_ for m in Base.registry.mappers}
    entries = db.scalars(
        select(LedgerEntry)
        .where(LedgerEntry.gram_sabha_id == gram_sabha_id)
        .order_by(LedgerEntry.seq)
    ).all()
    prev = GENESIS
    for e in entries:
        model = tables.get(e.entity)
        row = db.get(model, e.entity_id) if model else None
        if row is None:
            return ChainReport(False, len(entries), prev, e.seq, e.entity, "record missing")
        if e.prev_hash != prev:
            return ChainReport(False, len(entries), prev, e.seq, e.entity, "chain link broken")
        if link_hash(canonical_payload(row), prev) != e.record_hash:
            return ChainReport(False, len(entries), prev, e.seq, e.entity, "record altered")
        prev = e.record_hash
    head = db.scalar(select(GramSabha.chain_head_hash).where(GramSabha.id == gram_sabha_id))
    if entries and head != prev:
        return ChainReport(False, len(entries), prev, None, None, "chain head mismatch")
    return ChainReport(True, len(entries), prev, None, None, None)
