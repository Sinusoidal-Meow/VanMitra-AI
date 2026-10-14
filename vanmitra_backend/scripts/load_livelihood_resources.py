"""
[USER RUNS] Load a resource dataset (GeoJSON, docs/DATA_PLAN.md §3) into MongoDB.

    python scripts/load_livelihood_resources.py data.geojson           # VALIDATE ONLY
    python scripts/load_livelihood_resources.py data.geojson --apply   # validate, then write

The default is read-only: it checks the file and prints what it found. Nothing is written without
--apply, and --apply refuses a file with any rejected feature unless you also pass
--allow-rejects. Loading is idempotent (a feature is replaced by dataset + version + id) and
NEVER deletes: an older version stays in the database but is no longer served.

Vidarbha (districts 08 to 13) portal data sits about 6 degrees west of the true position (PDF §14).
The correction is NOT implemented here because the exact offset used by the earlier prototype is
not in this repository: get it from the team and add it before loading any Vidarbha file.
"""

import json
import sys
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pymongo import MongoClient  # noqa: E402

from app.config import get_settings  # noqa: E402
from app.livelihood.loader import validate_dataset  # noqa: E402
from app.livelihood.mongo_store import DATASETS, RESOURCES, resource_to_doc  # noqa: E402


def main(path: Path, apply: bool, allow_rejects: bool) -> int:
    report = validate_dataset(json.loads(path.read_text(encoding="utf-8")))

    print(f"file: {path}")
    for problem in report.header_errors:
        print(f"  HEADER ERROR: {problem}")
    if report.header:
        h = report.header
        print(f"  dataset={h.get('dataset')} version={h.get('data_version')}")
        print(f"  sample data: {h.get('is_sample')}")
        print(f"  source={h.get('source')} ({h.get('source_date')})")
    print(f"  accepted: {len(report.records)}   rejected: {len(report.rejected)}")
    for kind, n in report.counts_by_kind().items():
        print(f"    {kind}: {n}")
    for r in report.rejected:
        print(f"  REJECTED #{r.index} ({r.feature_id or 'no id'}): {r.reason}")
    for w in report.warnings:
        print(f"  warning: {w}")

    if not report.ok:
        print("NOT OK: nothing can be loaded from this file")
        return 1
    if report.rejected and not allow_rejects:
        print("some features were rejected; fix them, or pass --allow-rejects to load the rest")
        return 1
    if not apply:
        print("validation only; nothing written. Add --apply to load.")
        return 0

    s = get_settings()
    print(f"writing to database '{s.mongodb_db}' ...")
    client: MongoClient[dict[str, object]] = MongoClient(
        s.mongodb_uri, serverSelectionTimeoutMS=s.db_connect_timeout_s * 1000
    )
    db = client[s.mongodb_db]
    version = str(report.header["data_version"])
    name = str(report.header["dataset"])
    for record in report.records:
        db[RESOURCES].replace_one(
            {"dataset": name, "data_version": version, "id": record.id},
            resource_to_doc(record, version),
            upsert=True,
        )
    db[DATASETS].replace_one(
        {"dataset": name, "data_version": version},
        {**report.header, "loaded_at": datetime.now(UTC), "feature_count": len(report.records)},
        upsert=True,
    )
    print(f"done: {len(report.records)} features loaded as {name} {version}")
    return 0


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        raise SystemExit(
            "usage: python scripts/load_livelihood_resources.py <file.geojson> [--apply]"
        )
    raise SystemExit(main(Path(args[0]), "--apply" in sys.argv, "--allow-rejects" in sys.argv))
