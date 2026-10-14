"""
[USER RUNS] Create the Module 4 MongoDB indexes. This writes to the database, so Claude does
not run it. By default it only PRINTS what it would do; pass --apply to do it.

    python scripts/setup_livelihood_indexes.py            # dry run: prints the plan
    python scripts/setup_livelihood_indexes.py --apply    # creates the indexes

Safe to run again (creating an index that exists is a no-op). It never drops anything. In the
host app, merge `INDEXES` from app/livelihood/mongo_store.py into app/mongo.py instead.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pymongo import MongoClient  # noqa: E402

from app.config import get_settings  # noqa: E402
from app.livelihood.mongo_store import INDEXES  # noqa: E402


def main(apply: bool) -> None:
    s = get_settings()
    print(f"database: {s.mongodb_db}   mode: {'APPLY' if apply else 'dry run'}")
    for collection, indexes in INDEXES.items():
        for ix in indexes:
            doc = ix.document
            unique = doc.get("unique", False)
            print(f"  {collection}: {doc['name']} {dict(doc['key'])} unique={unique}")
    if not apply:
        print("dry run only; add --apply to create them")
        return
    client: MongoClient[dict[str, object]] = MongoClient(
        s.mongodb_uri, serverSelectionTimeoutMS=s.db_connect_timeout_s * 1000
    )
    db = client[s.mongodb_db]
    existing = set(db.list_collection_names())
    for collection, indexes in INDEXES.items():
        if collection not in existing:
            db.create_collection(collection)
        db[collection].create_indexes(indexes)
    print("done")


if __name__ == "__main__":
    main("--apply" in sys.argv)
