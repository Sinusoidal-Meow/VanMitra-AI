"""
[USER RUNS] Round-trip a profile through the real MongoStore, to check the database code works.
This WRITES to the database, so Claude does not run it, and it refuses to touch anything that
is not clearly a throwaway database.

    set VANMITRA_MONGODB_DB=vanmitra_smoke_test     (the name must end with _test)
    python scripts/smoke_mongo.py --apply
"""

import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import get_settings  # noqa: E402
from app.livelihood.mongo_store import MongoStore  # noqa: E402
from app.livelihood.schemas import ProfileIn  # noqa: E402


def main() -> None:
    s = get_settings()
    if not s.mongodb_db.endswith("_test"):
        raise SystemExit(f"refusing: database '{s.mongodb_db}' does not end with _test")
    if "--apply" not in sys.argv:
        raise SystemExit(f"dry run: would write to '{s.mongodb_db}'; add --apply")

    store = MongoStore.from_settings(s)
    user = f"smoke-{uuid.uuid4().hex[:8]}"
    profile = ProfileIn.model_validate(
        {
            "land": {"area_value": 2, "area_unit": "acre"},
            "livestock": {"cow": 1},
            "assets": ["well"],
        }
    )
    saved = store.put_profile(user, "sample_ozhar", profile)
    assert store.get_profile(user) is not None, "profile was not saved"
    replaced = store.put_profile(user, "sample_ozhar", ProfileIn())
    assert replaced.created_at == saved.created_at, "created_at must survive a replace"
    assert store.get_profile(user).profile.assets == [], "a replace must not merge"  # type: ignore[union-attr]
    assert store.delete_profile(user) is True
    assert store.get_profile(user) is None
    print("MongoStore profile round trip: OK")


if __name__ == "__main__":
    main()
