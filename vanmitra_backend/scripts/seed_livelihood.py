"""
[USER RUNS] Seed Module 4 (livelihood report) data into the host's MongoDB.

    python -m scripts.seed_livelihood            # dry run: reads, prints what it would write
    python -m scripts.seed_livelihood --apply    # writes

What it writes (upserts only, never deletes, safe to run again):
  - the DRAFT idea library into `lv_idea` (NOT reviewed by a forest-law expert, an agriculture
    expert, an animal-welfare NGO or the Forest Department; see IDEA_LIBRARY.md in the Module 4
    repo);
  - the SAMPLE scheme rows into `lv_scheme` (links to official pages only, every row labelled
    Sample until a real register exists);
  - a location row in `lv_village_geo` for the demo village Ozhar. The host `village` records carry
    no coordinates, so the report needs this row. The centre is APPROXIMATE and marked SAMPLE.

The only thing it READS is the `village` collection, to find Ozhar's id (a read-only query).
Resource data is loaded separately: `python -m scripts.load_livelihood_resources <file.geojson>`.
Do not seed sample data into a database that serves real users.
"""

import sys

from app.livelihood.mongo_store import IDEAS, SCHEMES, VILLAGES
from app.livelihood.seed import load_demo_village, load_ideas, load_schemes
from app.mongo import get_database

VILLAGE_NAME_EN = "Ozhar"


def main(apply: bool) -> int:
    db = get_database()
    ideas = load_ideas()
    schemes = load_schemes()
    print(f"mode: {'APPLY' if apply else 'dry run'}")
    print(f"  ideas: {len(ideas)} (draft)")
    print(f"  schemes: {len(schemes)} (all sample rows, links only)")

    found = db["village"].find_one({"name_en": VILLAGE_NAME_EN})
    if found is None:
        print(f"  village '{VILLAGE_NAME_EN}' not found in `village`: seed the demo users first")
        return 1
    village_id = str(found["_id"])
    demo = load_demo_village()
    geo = demo.model_copy(update={"village_id": village_id}).model_dump(mode="json")
    print(f"  village: {VILLAGE_NAME_EN} -> {village_id} (approximate centre, SAMPLE)")

    if not apply:
        print("dry run only; add --apply to write")
        return 0
    for idea in ideas:
        db[IDEAS].replace_one({"code": idea.code}, idea.model_dump(mode="json"), upsert=True)
    for scheme in schemes:
        db[SCHEMES].replace_one({"code": scheme.code}, scheme.model_dump(mode="json"), upsert=True)
    db[VILLAGES].replace_one({"village_id": village_id}, geo, upsert=True)
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main("--apply" in sys.argv))
