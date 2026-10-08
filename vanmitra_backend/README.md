# VanMitra backend

FastAPI + MongoDB (Atlas) API for the **FRA claim module**. Plan and rules: [`../docs/BACKEND_PLAN.md`](../docs/BACKEND_PLAN.md).

**Status:** villager → Gram Sabha → SDO, then handed to the district website; Forms A, B and C; send-back with remarks and 60 days to resubmit; the full CFR procedure. API: [`../docs/API_MODULE3.md`](../docs/API_MODULE3.md), [`../docs/API_PROCEDURE.md`](../docs/API_PROCEDURE.md).

## Quick start (Windows, Git Bash)

```bash
cd vanmitra_backend
py -3.12 -m venv venv
./venv/Scripts/pip install -r requirements.txt       # full (includes the legacy AI stack)
#   or: -r requirements-dev.txt                        # API + tests only, no PyTorch
cp .env.example .env

# In .env set VANMITRA_MONGODB_URI to the MongoDB Atlas link (a secret: never commit it).
# Once per database (you run these, not the app):
./venv/Scripts/python -m scripts.setup_mongo         # collections and indexes
./venv/Scripts/python -m scripts.seed_demo           # Ozhar village + one demo user per role

./venv/Scripts/uvicorn app.main:app --reload --port 8000
```

- API docs: http://localhost:8000/docs
- Demo logins (development only), PIN `123456`: `9000000001`, `9000000002` (villagers), `9000000003` (Gram Sabha), `9000000004` (admin), `9000000005` (SDO)
- Phone over USB: `adb reverse tcp:8000 tcp:8000`, then the app uses `http://localhost:8000`


## Layout

```
app/
  main.py          app factory; mounts /api/v1 and, if enabled, the legacy routes
  config.py        settings (VANMITRA_* env vars / .env)
  mongo.py         MongoDB client, the per-request unit of work (Store), indexes
  db.py            the request dependency (re-exports from mongo.py)
  errors.py        uniform error body: {error, rule?, message_key, details}
  auth/            PIN hashing, JWT, Principal (role x village), route dependencies
  models/          stored records (Pydantic documents)
  schemas/         request/response models
  api/v1/          routers
  legacy/          old Model A endpoints: frozen, removed once the app migrates (B-04)
scripts/           setup_mongo.py (indexes), seed_demo.py
tests/             unit/ and api/ (no database) · db/ (needs VANMITRA_TEST_MONGODB_URI)
```

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/health` | none | Always 200; reports `database: ok \| unavailable` |
| POST | `/api/v1/auth/login` | none | `{phone, pin}` → access + refresh tokens |
| POST | `/api/v1/auth/refresh` | refresh token | New token pair |
| GET | `/api/v1/me` | access token | User + roles valid today, per village |
| GET | `/api/v1/forms/form-b/fields` | access token | Form B rights (items 1–6) with sections, Rule 13 tags |
| POST | `/api/v1/villages/{village_id}/cases` | facilitator / FRC | Open a `cr` case with an empty Form B draft |
| GET | `/api/v1/villages/{village_id}/cases` | any role in village | Cases in the village |
| GET | `/api/v1/cases/{case_id}/form-b` | any role in village | Form B draft + documentation completeness |
| PUT | `/api/v1/cases/{case_id}/form-b` | facilitator / FRC | Replace the Form B draft (DRAFT only) |
| GET | `/api/v1/forms/form-c/fields` | access token | Form C vocabularies (boundary sides, landmark kinds), default statement |
| GET | `/api/v1/cases/{case_id}/form-c` | any role in village | Form C draft + member sheet + documentation completeness |
| PUT | `/api/v1/cases/{case_id}/form-c` | facilitator / FRC | Replace the Form C draft (DRAFT only) |
| GET / POST | `/api/v1/villages/{village_id}/members` | read: any role · add: GS Secretary | Gram Sabha roster (feeds the Form C member sheet) |
| PATCH | `/api/v1/members/{member_id}` | GS Secretary | Correct or deactivate a member |

Contracts for the app: [`../docs/API_FORM_B.md`](../docs/API_FORM_B.md) · [`../docs/API_FORM_C.md`](../docs/API_FORM_C.md).

Every error has the same body, so the app can show a local-language message:

```json
{ "error": "NOT_AUTHENTICATED", "message_key": "auth.required", "details": {} }
```

Errors caused by a legal rule also carry `"rule": "Rule 3(1)"`.

## Checks

```bash
./venv/Scripts/ruff check app tests scripts
./venv/Scripts/ruff format --check app tests scripts
./venv/Scripts/mypy app scripts
./venv/Scripts/pytest -q                               # db tests skip without a test database
```

To run the database tests, point `VANMITRA_TEST_MONGODB_URI` at a **throwaway** MongoDB replica set (transactions need one). The tests create the database and drop it afterwards. CI does this automatically (`.github/workflows/backend-ci.yml`).

## Settings

| Variable | Default | Notes |
|---|---|---|
| `VANMITRA_MONGODB_URI` | local replica set | The MongoDB Atlas link (`mongodb+srv://…`). Secret: only in `.env` |
| `VANMITRA_MONGODB_DB` | `vanmitra` | Database name |
| `VANMITRA_EXPIRY_CHECK_MINUTES` | `60` | How often claims past their 60 days are closed (`0` = off) |
| `VANMITRA_JWT_SECRET` | dev value | **Must** be set when `VANMITRA_ENV=production` (start-up refuses otherwise) |
| `VANMITRA_ENABLE_LEGACY_API` | `true` | `false` skips loading the ML models: faster start, no old AI endpoints |
| `VANMITRA_CORS_ORIGINS` | `["*"]` | JSON list |
