# Module 4: VanRozgar, the personal livelihood report

A villager enters his **land, livestock and what he already owns**; the app lists the **resources
within 5 km** of his land (each marked Useful / Partly useful / Not useful, with a reason, a
distance and a source and date) and gives a plain **analysis of where he is heading** with five
ranked, legal and wildlife-safe work ideas. It only suggests: the landowner decides, and for
community forest the Gram Sabha decides.

Planning, rules and the full contract live in the Module 4 repo
(`VanRojgaar_module2.0`, branches `backend`, `frontend`, `integration`). This file is what the
host team needs.

## What was added (all in isolated folders)

| Where | What |
|---|---|
| `vanmitra_backend/app/livelihood/` | The module: rules, geo, store, routes. Routes at `/api/v1/livelihood/*` |
| `vanmitra_backend/app/livelihood/deps.py` | **The only host-specific file**: the user comes from the host login and `user_role` grants (`villager` or `gram_sabha`, with a village); the data from the host's MongoDB (`get_database()`) |
| `vanmitra_backend/scripts/` | `seed_livelihood.py`, `load_livelihood_resources.py`, `setup_livelihood_indexes.py`, `smoke_mongo.py`. **Every one defaults to a dry run** |
| `vanmitra_backend/tests/livelihood/` | 115 tests, no database needed |
| `vanmitra_tem/lib/features/livelihood/` | The screens and logic. No change to the host's `core/` |
| `vanmitra_tem/assets/livelihood/` | The bundled SAMPLE report (demo and offline fallback) |
| `vanmitra_tem/test/livelihood/` | 69 tests |

## The 34 lines changed in existing host files

| File | Change |
|---|---|
| `app/api/v1/__init__.py` | import and include the livelihood router |
| `app/config.py` | three settings (demo route off, radius 5 km, cap 10 km); the demo route is refused in production |
| `app/mongo.py` | merge the `lv_*` indexes into `INDEXES` (created by `scripts.setup_mongo`, run by a person) |
| `requirements-core.txt` | `numpy>=1.26` (already pulled in by shapely) |
| `lib/app.dart` | `...livelihoodRoutes` in `MaterialApp.routes` |
| `lib/screens/home/villager_home_screen.dart` | one "My Livelihood" card in the Gram Sabha and records list |
| `pubspec.yaml` | the sample-report asset. **No new packages** (http, hive, secure storage, geolocator were already here) |

To remove the module: revert those seven edits and delete the folders above. Nothing else depends on it.

## Routes

| Route | Purpose |
|---|---|
| `PUT/GET/DELETE /livelihood/profile` | his details; delete also removes his saved reports |
| `POST /livelihood/report`, `GET /livelihood/report/latest` | build and read his report |
| `POST /livelihood/resources/nearby` | labelled resources near a point |
| `GET /livelihood/meta` | form vocabularies and limits (public) |

All need the host login except `/meta`. Each user can only reach **his own** data.

## What a person must run before it works (the author did not touch any database)

```bash
cd vanmitra_backend
python -m scripts.setup_mongo                         # creates the new lv_* indexes (existing script)
python -m scripts.seed_livelihood                     # dry run first, then add --apply
python -m scripts.load_livelihood_resources FILE      # validates first; --apply to load
python -m scripts.smoke_mongo                         # ONLY against a throwaway DB whose name ends _test
```

Until a resource file is loaded, `POST /report` answers **503 data not loaded** on purpose (an empty
database must not look like "nothing is near you"). The bundled sample file is
`app/livelihood/seed/sample_resources.geojson` (synthetic, labelled Sample).

## Known limits

- The Mongo code is unit-tested for its conversions and queries but **has not been run against a
  real database**. Run `smoke_mongo` before trusting it.
- **No real resource data yet.** Only the labelled Sample set exists. Real sources need permission.
- The idea library (13 ideas) is a **draft, not expert-reviewed**. Weather and disasters are Sample.
- The Marathi text is a **machine draft**; Hindi and Konkani fall back to English.
- Ozhar's centre in `lv_village_geo` is approximate and marked Sample (the host `village` has no coordinates).
- Not run on a phone or emulator yet; the encrypted cache (Android Keystore) and GPS are unit-tested only.
