"""
MongoDB connection and the per-request unit of work (Store).

How the rest of the backend talks to the database:

    db.get(ClaimCase, case_id)                         # one record by id (or None)
    db.find(Evidence, {"case_id": cid}, sort=[("created_at", 1)])
    db.find_one(GramSabha, {"village_id": vid})
    db.count(CaseClaimant, {"case_id": cid})
    db.add(record)                                     # insert now
    record.field = value                               # change a loaded record...
    db.commit()                                        # ...saved here (or before the next query)

Every request runs in one MongoDB transaction: either all its changes are saved or none.
`commit()` saves and starts a fresh transaction, like the SQL session the code used
before. Records loaded through the Store are tracked: changing their attributes is
enough, the Store writes the change before the next query and at commit. Records marked
APPEND_ONLY (evidence, history, resolutions, ...) are never replaced or deleted: the
Store refuses (rule C8). The hash chain (services/ledger.py) detects any change made
outside the server.

Two requests changing the same record at the same moment: MongoDB lets the first win
and the second fails with a write conflict (HTTP 409 WRITE_CONFLICT, try again).
"""

import uuid
from collections.abc import Iterator, Mapping, Sequence
from datetime import date
from decimal import Decimal
from functools import lru_cache
from types import TracebackType
from typing import Any, Self, TypeVar

from bson.binary import UuidRepresentation
from bson.codec_options import CodecOptions, TypeCodec, TypeEncoder, TypeRegistry
from bson.decimal128 import Decimal128
from pymongo import ASCENDING, DESCENDING, GEOSPHERE, IndexModel, MongoClient, ReturnDocument
from pymongo.client_session import ClientSession
from pymongo.collection import Collection
from pymongo.database import Database
from pymongo.errors import PyMongoError
from pymongo.read_concern import ReadConcern
from pymongo.write_concern import WriteConcern

from .config import get_settings
from .models.base import Doc, now_ms

D = TypeVar("D", bound=Doc)
Raw = dict[str, Any]
Filter = Mapping[str, Any]
Sort = Sequence[tuple[str, int]]


class _DecimalCodec(TypeCodec):
    python_type = Decimal
    bson_type = Decimal128

    def transform_python(self, value: Any) -> Any:
        return Decimal128(value)

    def transform_bson(self, value: Any) -> Any:
        return value.to_decimal()


class _DateEncoder(TypeEncoder):
    """Calendar dates (not times) are stored, and compared in queries, as YYYY-MM-DD."""

    python_type = date

    def transform_python(self, value: Any) -> Any:
        return value.isoformat()


CODEC_OPTIONS: CodecOptions[Raw] = CodecOptions(
    document_class=dict,
    tz_aware=True,
    uuid_representation=UuidRepresentation.STANDARD,
    type_registry=TypeRegistry([_DecimalCodec(), _DateEncoder()]),
)


@lru_cache
def get_client() -> MongoClient[Raw]:
    settings = get_settings()
    timeout_ms = settings.db_connect_timeout_s * 1000
    return MongoClient(
        settings.mongodb_uri,
        tz_aware=True,
        uuidRepresentation="standard",
        serverSelectionTimeoutMS=timeout_ms,
        connectTimeoutMS=timeout_ms,
        appname="vanmitra-backend",
    )


def get_database(name: str | None = None) -> Database[Raw]:
    return get_client().get_database(name or get_settings().mongodb_db, codec_options=CODEC_OPTIONS)


def ping() -> bool:
    """True if the database answers (used by the health check)."""
    try:
        get_client().admin.command("ping")
    except PyMongoError:
        return False
    return True


class AppendOnlyError(RuntimeError):
    """A protected record (rule C8) was about to be changed or deleted."""


class Store:
    """The unit of work of one request (or one background job). Not thread-safe."""

    def __init__(self, database: Database[Raw]) -> None:
        self._db = database
        self._session: ClientSession | None = None
        # identity map: (collection, id) -> (record, what was last loaded or saved)
        self._tracked: dict[tuple[str, uuid.UUID], tuple[Doc, Raw]] = {}

    # ── transaction ───────────────────────────────────────────────────────────────

    @property
    def session(self) -> ClientSession:
        """The open session, inside a transaction (started on first use)."""
        if self._session is None:
            self._session = self._db.client.start_session()
        if not self._session.in_transaction:
            self._session.start_transaction(
                read_concern=ReadConcern("snapshot"), write_concern=WriteConcern("majority")
            )
        return self._session

    def flush(self) -> None:
        """Write every change made to tracked records since they were loaded or saved."""
        for key, (doc, saved) in list(self._tracked.items()):
            current = doc.to_mongo()
            if current == saved:
                continue
            if doc.APPEND_ONLY:
                raise AppendOnlyError(f"{doc.COLLECTION} records are append-only")
            if "updated_at" in current:
                doc.updated_at = now_ms()  # type: ignore[attr-defined]
                current = doc.to_mongo()
            self._db[doc.COLLECTION].replace_one({"_id": doc.id}, current, session=self.session)
            self._tracked[key] = (doc, current)

    def commit(self) -> None:
        self.flush()
        if self._session is not None and self._session.in_transaction:
            self._session.commit_transaction()

    def rollback(self) -> None:
        """Discard everything not committed; records must be loaded again afterwards."""
        if self._session is not None and self._session.in_transaction:
            self._session.abort_transaction()
        self._tracked.clear()

    def close(self) -> None:
        try:
            self.rollback()
        finally:
            if self._session is not None:
                self._session.end_session()
                self._session = None

    def __enter__(self) -> Self:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        tb: TracebackType | None,
    ) -> None:
        self.close()

    # ── reading ───────────────────────────────────────────────────────────────────

    def collection(self, model: type[Doc]) -> Collection[Raw]:
        """The raw collection, for queries the helpers below do not cover.
        Pass `session=db.session` to every call so it joins the transaction."""
        return self._db[model.COLLECTION]

    def _load(self, model: type[D], raw: Raw) -> D:
        key = (model.COLLECTION, raw["_id"])
        if key in self._tracked:
            return self._tracked[key][0]  # type: ignore[return-value]
        doc = model.from_mongo(raw)
        self._tracked[key] = (doc, doc.to_mongo())
        return doc

    def get(self, model: type[D], doc_id: uuid.UUID, *, fresh: bool = False) -> D | None:
        """
        One record by id. A record already loaded in this unit of work is returned as is,
        unless `fresh`: then it is read again from the database and updated in place.
        """
        key = (model.COLLECTION, doc_id)
        if key in self._tracked and not fresh:
            return self._tracked[key][0]  # type: ignore[return-value]
        self.flush()
        raw = self._db[model.COLLECTION].find_one({"_id": doc_id}, session=self.session)
        if raw is None:
            return None
        if key in self._tracked:  # fresh: refresh the object everyone already holds
            doc = self._tracked[key][0]
            loaded = model.from_mongo(raw)
            for name in type(loaded).model_fields:
                setattr(doc, name, getattr(loaded, name))
            self._tracked[key] = (doc, doc.to_mongo())
            return doc  # type: ignore[return-value]
        return self._load(model, raw)

    def find(
        self,
        model: type[D],
        filter: Filter | None = None,
        *,
        sort: Sort | None = None,
        limit: int = 0,
        skip: int = 0,
    ) -> list[D]:
        self.flush()
        cursor = self._db[model.COLLECTION].find(
            dict(filter or {}),
            sort=list(sort) if sort else None,
            limit=limit,
            skip=skip,
            session=self.session,
        )
        return [self._load(model, raw) for raw in cursor]

    def find_one(
        self, model: type[D], filter: Filter | None = None, *, sort: Sort | None = None
    ) -> D | None:
        found = self.find(model, filter, sort=sort, limit=1)
        return found[0] if found else None

    def count(self, model: type[Doc], filter: Filter | None = None) -> int:
        self.flush()
        return self._db[model.COLLECTION].count_documents(dict(filter or {}), session=self.session)

    def exists(self, model: type[Doc], filter: Filter) -> bool:
        return self.count(model, filter) > 0

    def distinct(self, model: type[Doc], key: str, filter: Filter | None = None) -> list[Any]:
        self.flush()
        return list(
            self._db[model.COLLECTION].distinct(key, dict(filter or {}), session=self.session)
        )

    def aggregate(self, model: type[Doc], pipeline: Sequence[Mapping[str, Any]]) -> list[Raw]:
        self.flush()
        return list(
            self._db[model.COLLECTION].aggregate(
                [dict(stage) for stage in pipeline], session=self.session
            )
        )

    # ── writing ───────────────────────────────────────────────────────────────────

    def add(self, doc: D) -> D:
        """Insert a new record now (inside the transaction) and track it."""
        raw = doc.to_mongo()
        self._db[doc.COLLECTION].insert_one(raw, session=self.session)
        self._tracked[(doc.COLLECTION, doc.id)] = (doc, raw)
        return doc

    def add_all(self, docs: Sequence[Doc]) -> None:
        for doc in docs:
            self.add(doc)

    def delete(self, doc: Doc) -> None:
        if doc.APPEND_ONLY:
            raise AppendOnlyError(f"{doc.COLLECTION} records are append-only")
        self._db[doc.COLLECTION].delete_one({"_id": doc.id}, session=self.session)
        self._tracked.pop((doc.COLLECTION, doc.id), None)

    def update_many(self, model: type[Doc], filter: Filter, update: Mapping[str, Any]) -> int:
        """
        A direct update of every matching record. Records of this kind already loaded are
        forgotten (load them again to see the change).
        """
        if model.APPEND_ONLY:
            raise AppendOnlyError(f"{model.COLLECTION} records are append-only")
        self.flush()
        result = self._db[model.COLLECTION].update_many(
            dict(filter), dict(update), session=self.session
        )
        for key in [k for k in self._tracked if k[0] == model.COLLECTION]:
            del self._tracked[key]
        return result.modified_count

    def next_number(self, key: str) -> int:
        """
        The next number of a named sequence (1, 2, 3, ...), for serials such as the
        acknowledgement register. Taken inside the transaction: if it is rolled back, the
        number is not used up.
        """
        found = self._db["counters"].find_one_and_update(
            {"_id": key},
            {"$inc": {"value": 1}},
            upsert=True,
            return_document=ReturnDocument.AFTER,
            session=self.session,
        )
        assert found is not None
        return int(found["value"])


def get_db() -> Iterator[Store]:
    """FastAPI dependency: one unit of work per request. Nothing is saved unless the
    endpoint commits; the database is only contacted when first used."""
    with Store(get_database()) as store:
        yield store


# ── Indexes (created by scripts/setup_mongo.py, which a person runs) ───────────────


def _unique_when_set(*fields: str) -> dict[str, Any]:
    """Unique only among records where the last field has a value."""
    return {"unique": True, "partialFilterExpression": {fields[-1]: {"$type": "string"}}}


INDEXES: dict[str, list[IndexModel]] = {
    "village": [
        IndexModel(
            [("lgd_code", ASCENDING)], name="lgd_code_unique", **_unique_when_set("lgd_code")
        ),
        IndexModel([("parent_village_id", ASCENDING)], name="parent"),
        IndexModel([("taluka", ASCENDING), ("district", ASCENDING)], name="jurisdiction"),
    ],
    "gram_sabha": [IndexModel([("village_id", ASCENDING)], name="village_unique", unique=True)],
    "gs_member": [IndexModel([("gram_sabha_id", ASCENDING)], name="gram_sabha")],
    "app_user": [IndexModel([("phone", ASCENDING)], name="phone_unique", unique=True)],
    "user_role": [
        IndexModel([("user_id", ASCENDING)], name="user"),
        IndexModel([("village_id", ASCENDING), ("role", ASCENDING)], name="village_role"),
        IndexModel(
            [
                ("user_id", ASCENDING),
                ("village_id", ASCENDING),
                ("role", ASCENDING),
                ("valid_from", ASCENDING),
            ],
            name="grant_unique",
            unique=True,
        ),
    ],
    "claim_case": [
        IndexModel([("gram_sabha_id", ASCENDING), ("state", ASCENDING)], name="gram_sabha_state"),
        IndexModel([("created_by_user_id", ASCENDING)], name="creator"),
        IndexModel([("state", ASCENDING)], name="state"),
        IndexModel(
            [("gram_sabha_id", ASCENDING), ("ack_serial", ASCENDING)],
            name="ack_serial_unique",
            **_unique_when_set("gram_sabha_id", "ack_serial"),
        ),
    ],
    "workflow_event": [
        IndexModel(
            [("case_id", ASCENDING), ("created_at", ASCENDING), ("_id", ASCENDING)],
            name="case_history",
        ),
    ],
    "frc": [
        IndexModel([("gram_sabha_id", ASCENDING), ("is_current", ASCENDING)], name="gram_sabha"),
    ],
    "case_claimant": [
        IndexModel(
            [("case_id", ASCENDING), ("gs_member_id", ASCENDING)],
            name="claimant_unique",
            unique=True,
        ),
    ],
    "recusal": [
        IndexModel(
            [("case_id", ASCENDING), ("gs_member_id", ASCENDING)],
            name="recusal_unique",
            unique=True,
        ),
    ],
    "claim_call": [
        IndexModel([("gram_sabha_id", ASCENDING), ("is_current", ASCENDING)], name="gram_sabha"),
    ],
    "media": [IndexModel([("sha256", ASCENDING)], name="sha256")],
    "evidence": [
        IndexModel([("case_id", ASCENDING), ("created_at", ASCENDING)], name="case"),
        IndexModel([("supersedes_id", ASCENDING)], name="supersedes"),
        IndexModel([("media_id", ASCENDING)], name="media"),
        IndexModel([("signed_scan_media_id", ASCENDING)], name="signed_scan"),
    ],
    "evidence_verification": [IndexModel([("evidence_id", ASCENDING)], name="evidence")],
    "ledger_entry": [
        IndexModel(
            [("gram_sabha_id", ASCENDING), ("seq", ASCENDING)], name="seq_unique", unique=True
        ),
    ],
    "correspondence": [
        IndexModel([("gram_sabha_id", ASCENDING), ("created_at", ASCENDING)], name="gram_sabha"),
        IndexModel([("case_id", ASCENDING)], name="case"),
    ],
    "verification_proceeding": [
        IndexModel(
            [("case_id", ASCENDING), ("attempt_no", ASCENDING)], name="attempt_unique", unique=True
        ),
    ],
    "gs_meeting": [
        IndexModel([("gram_sabha_id", ASCENDING), ("held_on", DESCENDING)], name="gram_sabha"),
    ],
    "resolution": [
        IndexModel(
            [("gram_sabha_id", ASCENDING), ("number", ASCENDING)], name="number_unique", unique=True
        ),
        IndexModel([("case_id", ASCENDING), ("created_at", ASCENDING)], name="case"),
        IndexModel([("meeting_id", ASCENDING)], name="meeting"),
    ],
    "title_followup": [IndexModel([("case_id", ASCENDING)], name="case_unique", unique=True)],
    "cfr_boundary": [
        IndexModel(
            [("case_id", ASCENDING), ("version", ASCENDING)], name="version_unique", unique=True
        ),
        IndexModel([("geom", GEOSPHERE)], name="geom"),
    ],
    "boundary_walk": [IndexModel([("case_id", ASCENDING)], name="case")],
    "dispute": [
        IndexModel(
            [("case_id", ASCENDING), ("neighbour_case_id", ASCENDING)],
            name="pair_unique",
            unique=True,
        ),
        IndexModel([("neighbour_case_id", ASCENDING)], name="neighbour"),
    ],
    "notification": [
        IndexModel([("user_id", ASCENDING), ("created_at", DESCENDING)], name="inbox"),
    ],
}


def ensure_indexes(database: Database[Raw]) -> list[str]:
    """Create the collections' indexes if missing (safe to run again). Returns their names."""
    made: list[str] = []
    existing = set(database.list_collection_names())
    for name, indexes in INDEXES.items():
        if name not in existing:
            database.create_collection(name)
        made += [f"{name}.{i}" for i in database[name].create_indexes(indexes)]
    if "counters" not in existing:
        database.create_collection("counters")
    return made
