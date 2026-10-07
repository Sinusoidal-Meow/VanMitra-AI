"""
Tamper-evident hash chain, one chain per Gram Sabha (Spec §6.8, rule C8):

    record_hash(n) = SHA256( canonical_json(payload(n)) || record_hash(n-1) )

`append` links a freshly inserted record into its Gram Sabha's chain; `verify`
recomputes every link from the stored records and reports the first break. The chain
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

from ..db import Store
from ..models import DOC_TYPES, Doc, GramSabha
from ..models.procedure import LedgerEntry

GENESIS = "0" * 64


def _jsonable(value: Any) -> Any:
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, datetime):
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


def canonical_payload(doc: Doc) -> str:
    """Every stored field of the record, sorted keys, no whitespace: stable across runs.
    Built from the stored form (`to_mongo`), so a record read back hashes the same."""
    stored = doc.to_mongo()
    data = {("id" if k == "_id" else k): _jsonable(v) for k, v in stored.items()}
    return json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def link_hash(payload: str, prev_hash: str) -> str:
    return hashlib.sha256((payload + prev_hash).encode("utf-8")).hexdigest()


def append(db: Store, gram_sabha_id: uuid.UUID, doc: Doc) -> LedgerEntry:
    """
    Add `doc` (already added to the Store) to the chain. Moving the Gram Sabha's chain
    head inside the same transaction means two writers cannot both extend the chain:
    the second gets a write conflict (and the unique (gram_sabha_id, seq) index backs it).
    """
    gs = db.get(GramSabha, gram_sabha_id, fresh=True)
    if gs is None:
        raise LookupError(f"gram sabha {gram_sabha_id} not found")
    prev = gs.chain_head_hash or GENESIS
    entry = LedgerEntry(
        gram_sabha_id=gram_sabha_id,
        seq=gs.chain_length + 1,
        entity=doc.COLLECTION,
        entity_id=doc.id,
        prev_hash=prev,
        record_hash=link_hash(canonical_payload(doc), prev),
    )
    db.add(entry)
    gs.chain_head_hash = entry.record_hash
    gs.chain_length = entry.seq
    db.flush()  # claim the head now, so a concurrent writer conflicts here
    return entry


@dataclass(frozen=True)
class ChainReport:
    ok: bool
    length: int
    head: str
    broken_at_seq: int | None
    broken_entity: str | None
    reason: str | None


def verify(db: Store, gram_sabha_id: uuid.UUID) -> ChainReport:
    entries = db.find(LedgerEntry, {"gram_sabha_id": gram_sabha_id}, sort=[("seq", 1)])
    prev = GENESIS
    for e in entries:
        model = DOC_TYPES.get(e.entity)
        doc = db.get(model, e.entity_id, fresh=True) if model else None
        if doc is None:
            return ChainReport(False, len(entries), prev, e.seq, e.entity, "record missing")
        if e.prev_hash != prev:
            return ChainReport(False, len(entries), prev, e.seq, e.entity, "chain link broken")
        if link_hash(canonical_payload(doc), prev) != e.record_hash:
            return ChainReport(False, len(entries), prev, e.seq, e.entity, "record altered")
        prev = e.record_hash
    gs = db.get(GramSabha, gram_sabha_id, fresh=True)
    head = gs.chain_head_hash if gs is not None else None
    if entries and head != prev:
        return ChainReport(False, len(entries), prev, None, None, "chain head mismatch")
    return ChainReport(True, len(entries), prev, None, None, None)
