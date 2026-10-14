"""
[USER RUNS] Get the Module 4 (livelihood) data into the database in one go, for a demo.

    python -m scripts.setup_module4_demo --check     # READ ONLY: what is in the database now
    python -m scripts.setup_module4_demo             # dry run: shows the steps, writes nothing
    python -m scripts.setup_module4_demo --apply     # does them

The three steps (each is safe to run again, none deletes anything):
  1. the Module 4 indexes (`lv_*` collections);
  2. the draft idea library, the Sample scheme rows, and the location row for the demo village
     Ozhar (needs the host's demo village to exist: run `scripts.seed_demo` first if it does not);
  3. the SAMPLE resource dataset (12 made-up places around 19.7805, 73.2210).

All of it is SAMPLE data, labelled so in the app. Do not run it against a database that serves
real users. Without these three steps the Livelihood tab has nothing to build a report from.
"""

import sys
from pathlib import Path

from pymongo import MongoClient

from app.config import get_settings
from app.livelihood.mongo_store import DATASETS, IDEAS, RESOURCES, SCHEMES, VILLAGES

SAMPLE_FILE = (
    Path(__file__).resolve().parent.parent
    / "app"
    / "livelihood"
    / "seed"
    / "sample_resources.geojson"
)


def _db() -> "MongoClient[dict[str, object]]":
    s = get_settings()
    return MongoClient(s.mongodb_uri, serverSelectionTimeoutMS=s.db_connect_timeout_s * 1000)


def check() -> int:
    """Read-only: count what the Livelihood tab needs. Exit 0 only when all of it is there."""
    s = get_settings()
    db = _db()[s.mongodb_db]
    print(f"database: {s.mongodb_db}   (read only)")
    needed = {
        IDEAS: "ideas (draft library)",
        SCHEMES: "scheme rows (Sample)",
        RESOURCES: "resources (Sample dataset)",
        DATASETS: "dataset headers",
        VILLAGES: "village locations",
    }
    missing = False
    for collection, what in needed.items():
        n = db[collection].count_documents({})
        print(f"  {collection:<14} {n:>4}  {what}{'' if n else '   <-- EMPTY'}")
        missing = missing or n == 0
    village = db["village"].find_one({"name_en": "Ozhar"})
    print(
        f"  demo village 'Ozhar' in `village`: {'found' if village else 'MISSING (run seed_demo)'}"
    )
    if missing or not village:
        print("NOT READY: run `python -m scripts.setup_module4_demo --apply`")
        return 1
    print("READY: the Livelihood tab has what it needs")
    return 0


def main(apply: bool) -> int:
    # imported here so `--check` needs nothing but the settings
    from scripts import load_livelihood_resources, seed_livelihood, setup_livelihood_indexes

    print(f"mode: {'APPLY' if apply else 'dry run'}")
    print("\n[1/3] indexes")
    setup_livelihood_indexes.main(apply)
    print("\n[2/3] ideas, schemes, demo village")
    if seed_livelihood.main(apply) != 0:
        print("stopped at step 2")
        return 1
    print("\n[3/3] sample resources")
    if load_livelihood_resources.main(SAMPLE_FILE, apply, False) != 0:
        print("stopped at step 3")
        return 1
    print("\nall steps done" if apply else "\ndry run only; add --apply to write")
    return 0


if __name__ == "__main__":
    if "--check" in sys.argv:
        raise SystemExit(check())
    raise SystemExit(main("--apply" in sys.argv))
