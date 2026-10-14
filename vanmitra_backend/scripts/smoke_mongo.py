"""
[USER RUNS] Run Module 4 end to end over the REAL MongoDB code, in a throwaway database.

This WRITES to the database, so Claude does not run it, and it refuses to touch anything that is
not clearly a throwaway database (the name must end with _test).

    set VANMITRA_MONGODB_DB=vanmitra_smoke_test      (PowerShell: $env:VANMITRA_MONGODB_DB=...)
    python -m scripts.smoke_mongo            # dry run: says what it would do
    python -m scripts.smoke_mongo --apply    # does it

What it does, in that throwaway database only:
  1. creates the Module 4 indexes and loads the Sample ideas, schemes, village and resources;
  2. round-trips a profile through the real MongoStore (created_at survives a replace, no merge);
  3. drives the real HTTP routes over that store as a signed-in villager: save details with the
     default coordinates, build the report (this is the 2dsphere resource search), read it back,
     ask a question and a harmful one, read and clear the history, open an idea, list the schemes,
     take the AI daily-limit counter, delete the details.

If this passes, the database code is right; what is left to check is only the hosting.
"""

import sys
import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi.testclient import TestClient

from app.config import get_settings
from app.livelihood.deps import get_store, get_user_info
from app.livelihood.identity import UserInfo
from app.livelihood.schemas import ProfileIn
from app.livelihood.store import LivelihoodStore
from app.main import create_app

URL = "/api/v1/livelihood"
DEMO_PROFILE = {
    "land": {"area_value": 3, "area_unit": "acre", "land_type": "irrigated"},
    "location": {"lat": 19.7805, "lng": 73.2210, "source": "manual"},
    "livestock": {"cow": 2, "goat_sheep": 5},
    "assets": ["well", "pump"],
    "past_work": ["dairy"],
}


def check(condition: bool, what: str) -> None:
    if not condition:
        raise AssertionError(what)
    print(f"  OK  {what}")


def exercise_profile(store: LivelihoodStore) -> None:
    user = f"smoke-{uuid.uuid4().hex[:8]}"
    profile = ProfileIn.model_validate(
        {
            "land": {"area_value": 2, "area_unit": "acre"},
            "livestock": {"cow": 1},
            "assets": ["well"],
        }
    )
    saved = store.put_profile(user, "sample_ozhar", profile)
    check(store.get_profile(user) is not None, "a profile is saved")
    replaced = store.put_profile(user, "sample_ozhar", ProfileIn())
    check(replaced.created_at == saved.created_at, "created_at survives a replace")
    kept = store.get_profile(user)
    check(kept is not None and kept.profile.assets == [], "a replace does not merge")
    check(store.delete_profile(user) is True, "a profile is deleted")
    check(store.get_profile(user) is None, "...and is gone")


def exercise_routes(store: LivelihoodStore) -> None:
    """The real routes, over [store], as a signed-in villager of the demo village."""
    me = UserInfo(uuid.uuid4(), "Smoke Villager", "sample_ozhar", frozenset({"villager"}))
    app = create_app()
    app.dependency_overrides[get_store] = lambda: store
    app.dependency_overrides[get_user_info] = lambda: me
    client = TestClient(app)
    try:
        put = client.put(f"{URL}/profile", json=DEMO_PROFILE)
        check(put.status_code == 200, "save details (with the default coordinates)")

        made = client.post(f"{URL}/report", json={})
        check(made.status_code == 200, "build the report")
        report: dict[str, Any] = made.json()
        check(report["is_sample_data"] is True, "the report says it is Sample data")
        check(len(report["resources"]) > 0, "resources were found within 5 km (geo search)")
        check(len(report["ideas"]) > 0, "ideas were ranked")
        latest = client.get(f"{URL}/report/latest")
        check(latest.status_code == 200 and latest.json()["id"] == report["id"], "read it back")

        ask = client.post(f"{URL}/ask", json={"question": "What is the best idea?", "lang": "en"})
        check(ask.status_code == 200 and ask.json()["turn"]["answer"]["kind"] == "ANSWER", "ask")
        bad = client.post(f"{URL}/ask", json={"question": "how to poison a leopard", "lang": "en"})
        refused = bad.json()["turn"]["answer"]["kind"] == "REFUSED_HARMFUL"
        check(refused, "a harmful question is refused")
        turns = client.get(f"{URL}/ask/history").json()["turns"]
        check(len(turns) == 2, "the history keeps both turns")
        check(client.delete(f"{URL}/ask/history").status_code == 204, "the history is cleared")

        code = report["ideas"][0]["code"]
        check(client.get(f"{URL}/ideas/{code}").status_code == 200, "an idea opens in full")
        schemes = client.get(f"{URL}/schemes").json()
        check(len(schemes["schemes"]) > 0 and schemes["is_sample_data"], "the schemes (Sample)")

        day = datetime.now(UTC).strftime("%Y-%m-%d")
        uses = [store.take_ai_use(str(me.id), day, 2) for _ in range(3)]
        check(uses == [True, True, False], "the AI daily limit counts and stops at the limit")

        check(client.delete(f"{URL}/profile").status_code == 204, "delete my answers")
        check(client.get(f"{URL}/profile").status_code == 404, "...the details are gone")
        check(client.get(f"{URL}/report/latest").status_code == 404, "...and so is the report")
    finally:
        app.dependency_overrides.clear()


def main() -> None:
    s = get_settings()
    if not s.mongodb_db.endswith("_test"):
        raise SystemExit(f"refusing: database '{s.mongodb_db}' does not end with _test")
    if "--apply" not in sys.argv:
        raise SystemExit(f"dry run: would write to '{s.mongodb_db}'; add --apply")

    # imported late: they open the database
    from app.livelihood.mongo_store import IDEAS, SCHEMES, VILLAGES, MongoStore
    from app.livelihood.seed import load_demo_village, load_ideas, load_schemes
    from app.mongo import get_database
    from scripts import load_livelihood_resources, setup_livelihood_indexes
    from scripts.setup_module4_demo import SAMPLE_FILE

    print(f"database: {s.mongodb_db}")
    print("1. indexes and Sample data")
    setup_livelihood_indexes.main(True)
    db = get_database()
    for idea in load_ideas():
        db[IDEAS].replace_one({"code": idea.code}, idea.model_dump(mode="json"), upsert=True)
    for scheme in load_schemes():
        db[SCHEMES].replace_one({"code": scheme.code}, scheme.model_dump(mode="json"), upsert=True)
    village = load_demo_village()
    db[VILLAGES].replace_one(
        {"village_id": village.village_id}, village.model_dump(mode="json"), upsert=True
    )
    check(load_livelihood_resources.main(SAMPLE_FILE, True, False) == 0, "Sample resources loaded")

    store = MongoStore(db)
    print("2. profile round trip")
    exercise_profile(store)
    print("3. the real routes over MongoStore")
    exercise_routes(store)
    print("MongoStore smoke test: ALL OK")


if __name__ == "__main__":
    main()
