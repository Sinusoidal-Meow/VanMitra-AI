"""
The MongoDB implementation of LivelihoodStore.

IMPORTANT: the pure parts (document conversion, the candidate query, index definitions) are unit
tested. The database calls themselves have NOT been run against a real database by the author:
database writes are run by a person (CLAUDE.md). Run `scripts/smoke_mongo.py` against a THROWAWAY
database (name ending _test) before trusting it.

Collections use the `lv_` prefix (docs/BACKEND_PLAN.md §2). Geometry is GeoJSON in WGS 84.
"""

from collections.abc import Sequence
from typing import Any

from pymongo import ASCENDING, DESCENDING, GEOSPHERE, IndexModel, MongoClient
from pymongo.collection import Collection
from pymongo.database import Database

from ..config import Settings
from .schemas import Idea, ProfileIn, ReportOut, ResourceRecord, VillageGeo
from .service import DatasetMeta
from .store import KEEP_REPORTS, StoredProfile

# Reports are ordered by time, then by id (ids are time-ordered UUIDv7), so two reports made in
# the same millisecond still have one fixed order.
_NEWEST_FIRST = [("generated_at", DESCENDING), ("report_id", DESCENDING)]

PROFILES = "lv_profile"
VILLAGES = "lv_village_geo"
REPORTS = "lv_report"
RESOURCES = "lv_resource"
IDEAS = "lv_idea"
DATASETS = "lv_dataset"

# Created by `scripts/setup_livelihood_indexes.py` (a person runs it). In the host, merge these
# into `INDEXES` in app/mongo.py instead.
INDEXES: dict[str, list[IndexModel]] = {
    PROFILES: [IndexModel([("user_id", ASCENDING)], name="user_unique", unique=True)],
    VILLAGES: [IndexModel([("village_id", ASCENDING)], name="village_unique", unique=True)],
    REPORTS: [
        IndexModel(
            [("user_id", ASCENDING), ("generated_at", DESCENDING), ("report_id", DESCENDING)],
            name="user_latest",
        )
    ],
    RESOURCES: [
        IndexModel([("geom", GEOSPHERE)], name="geom_2dsphere"),
        IndexModel(
            [("dataset", ASCENDING), ("data_version", ASCENDING), ("id", ASCENDING)],
            name="dataset_feature_unique",
            unique=True,
        ),
    ],
    IDEAS: [IndexModel([("code", ASCENDING)], name="code_unique", unique=True)],
    DATASETS: [IndexModel([("loaded_at", DESCENDING)], name="newest_first")],
}


# ── pure conversions (tested without a database) ──────────────────────────────


def profile_to_doc(stored: StoredProfile) -> dict[str, Any]:
    return {
        "user_id": stored.user_id,
        "village_id": stored.village_id,
        "profile": stored.profile.model_dump(mode="json"),
        "created_at": stored.created_at,
        "updated_at": stored.updated_at,
    }


def doc_to_profile(doc: dict[str, Any]) -> StoredProfile:
    return StoredProfile(
        user_id=doc["user_id"],
        village_id=doc.get("village_id"),
        profile=ProfileIn.model_validate(doc["profile"]),
        created_at=doc["created_at"],
        updated_at=doc["updated_at"],
    )


def report_to_doc(user_id: str, report: ReportOut) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "report_id": report.id,
        "generated_at": report.generated_at,
        "report": report.model_dump(mode="json"),
    }


def doc_to_report(doc: dict[str, Any]) -> ReportOut:
    return ReportOut.model_validate(doc["report"])


def resource_to_doc(record: ResourceRecord, data_version: str) -> dict[str, Any]:
    """A resource as stored: GeoJSON under `geom` (what the 2dsphere index reads)."""
    data = record.model_dump(mode="json", exclude={"geometry"})
    return {**data, "data_version": data_version, "geom": record.geometry}


def doc_to_resource(doc: dict[str, Any]) -> ResourceRecord:
    return ResourceRecord.model_validate(
        {k: v for k, v in doc.items() if k not in {"_id", "geom", "data_version"}}
        | {"geometry": doc["geom"]}
    )


def candidate_query(circle: dict[str, Any]) -> dict[str, Any]:
    """
    Resources whose geometry touches the circle. `$geoIntersects` is sound for every geometry
    type (a point, a river line, a big polygon whose centroid is far away), unlike a centroid
    radius search. The circle is circumscribed, so it never loses a resource; the exact distance
    filters the few extras afterwards.
    """
    return {
        "status": "active",
        "sensitive": False,
        "geom": {"$geoIntersects": {"$geometry": circle}},
    }


_DATASET_FIELDS = ("dataset", "data_version", "loaded_at", "is_sample", "source", "source_date")


def current_dataset_docs(dataset_docs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """For each dataset name, the document loaded most recently. Older versions stay in the
    database but are no longer served. A malformed document (a missing field, for example one
    inserted by hand) is skipped rather than breaking every request."""
    newest: dict[str, dict[str, Any]] = {}
    for doc in dataset_docs:
        if any(f not in doc for f in _DATASET_FIELDS):
            continue
        have = newest.get(doc["dataset"])
        if have is None or doc["loaded_at"] > have["loaded_at"]:
            newest[doc["dataset"]] = doc
    return [newest[name] for name in sorted(newest)]


def current_versions(dataset_docs: list[dict[str, Any]]) -> dict[str, str]:
    return {d["dataset"]: d["data_version"] for d in current_dataset_docs(dataset_docs)}


def combine_datasets(dataset_docs: list[dict[str, Any]]) -> DatasetMeta | None:
    """
    What a report says about its data. One dataset: its own header. Several (for example two
    districts): their sources joined, sample if ANY is a sample, and a version that changes when
    any of them is reloaded, so the report never claims the source or date of just one of them
    (rule L1). None if nothing valid is loaded.
    """
    current = current_dataset_docs(dataset_docs)
    if not current:
        return None
    if len(current) == 1:
        d = current[0]
        return DatasetMeta(
            d["dataset"], d["data_version"], bool(d["is_sample"]), d["source"], d["source_date"]
        )
    dates = [str(d["source_date"]) for d in current]
    return DatasetMeta(
        "+".join(d["dataset"] for d in current),
        ";".join(f"{d['dataset']}:{d['data_version']}" for d in current),
        any(bool(d["is_sample"]) for d in current),
        "; ".join(sorted({str(d["source"]) for d in current})),
        "unknown" if "unknown" in dates else max(dates),
    )


class MongoStore:
    def __init__(self, database: "Database[dict[str, Any]]") -> None:
        # In the host this is `get_database()` from app/mongo.py (its codec options already
        # handle dates and UUIDs); standalone it comes from `from_settings`.
        self._db = database

    @classmethod
    def from_settings(cls, settings: Settings) -> "MongoStore":
        client: MongoClient[dict[str, Any]] = MongoClient(
            settings.mongodb_uri,
            tz_aware=True,
            serverSelectionTimeoutMS=settings.db_connect_timeout_s * 1000,
            appname="vanmitra-livelihood",
        )
        return cls(client[settings.mongodb_db])

    def _col(self, name: str) -> "Collection[dict[str, Any]]":
        return self._db[name]

    # profile
    def get_profile(self, user_id: str) -> StoredProfile | None:
        doc = self._col(PROFILES).find_one({"user_id": user_id})
        return doc_to_profile(doc) if doc else None

    def put_profile(
        self, user_id: str, village_id: str | None, profile: ProfileIn
    ) -> StoredProfile:
        existing = self.get_profile(user_id)
        stored = StoredProfile(user_id=user_id, village_id=village_id, profile=profile)
        if existing:
            stored = stored.model_copy(update={"created_at": existing.created_at})
        # replace, never merge: what he sends is the whole truth about his answers
        self._col(PROFILES).replace_one({"user_id": user_id}, profile_to_doc(stored), upsert=True)
        return stored

    def delete_profile(self, user_id: str) -> bool:
        return self._col(PROFILES).delete_one({"user_id": user_id}).deleted_count > 0

    # reports
    def save_report(self, user_id: str, report: ReportOut) -> None:
        col = self._col(REPORTS)
        col.insert_one(report_to_doc(user_id, report))
        stale = [
            d["_id"]
            for d in col.find({"user_id": user_id}, {"_id": 1})
            .sort(_NEWEST_FIRST)
            .skip(KEEP_REPORTS)
        ]
        if stale:
            col.delete_many({"_id": {"$in": stale}})

    def latest_report(self, user_id: str) -> ReportOut | None:
        doc = self._col(REPORTS).find_one({"user_id": user_id}, sort=_NEWEST_FIRST)
        return doc_to_report(doc) if doc else None

    def delete_reports(self, user_id: str) -> int:
        return self._col(REPORTS).delete_many({"user_id": user_id}).deleted_count

    # shared data
    def get_village(self, village_id: str) -> VillageGeo | None:
        doc = self._col(VILLAGES).find_one({"village_id": village_id})
        if not doc:
            return None
        doc.pop("_id", None)
        return VillageGeo.model_validate(doc)

    def list_ideas(self) -> list[Idea]:
        return [
            Idea.model_validate({k: v for k, v in d.items() if k != "_id"})
            for d in self._col(IDEAS).find({})
        ]

    def dataset_meta(self) -> DatasetMeta | None:
        return combine_datasets(list(self._col(DATASETS).find({})))

    def resource_candidates(self, circle: dict[str, Any]) -> Sequence[ResourceRecord]:
        current = current_versions(list(self._col(DATASETS).find({})))
        if not current:
            # no dataset registered: serve nothing (never every version of everything). The
            # routes turn this into "data not loaded", not an empty result.
            return []
        query = candidate_query(circle)
        # the newest version of EACH dataset: a re-load never double-counts, and another
        # district's dataset stays visible
        query["$or"] = [{"dataset": n, "data_version": v} for n, v in current.items()]
        return [doc_to_resource(d) for d in self._col(RESOURCES).find(query)]
