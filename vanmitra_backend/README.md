# VanMitra backend

FastAPI + PostgreSQL/PostGIS API for the **CFR claim module**. Plan and rules: [`../docs/BACKEND_PLAN.md`](../docs/BACKEND_PLAN.md).

**Status: Stage 0 (foundations).** Login, roles scoped by village, error format, the first migration. Claim features start in Stage 1.

## Quick start (Windows, Git Bash)

```bash
cd vanmitra_backend
py -3.12 -m venv venv
./venv/Scripts/pip install -r requirements.txt       # full (includes the legacy AI stack)
#   or: -r requirements-dev.txt                        # API + tests only, no PyTorch
cp .env.example .env

docker compose up -d db                              # PostgreSQL 16 + PostGIS 3.4 on :5432

# Review, then apply, the schema (you run these, not the app):
./venv/Scripts/alembic upgrade head --sql            # print the SQL
./venv/Scripts/alembic upgrade head                  # apply it
./venv/Scripts/python -m scripts.seed_demo           # Ozhar village + one demo user per role

./venv/Scripts/uvicorn app.main:app --reload --port 8000
```

- API docs: http://localhost:8000/docs
- Demo logins (development only): phones `9000000001` (facilitator), `9000000002` (FRC member), `9000000003` (GS secretary), `9000000004` (admin), all with PIN `123456`
- Phone over USB: `adb reverse tcp:8000 tcp:8000`, then the app uses `http://localhost:8000`

The reviewed SQL for each migration is kept in `migrations/sql/`.

## Layout

```
app/
  main.py          app factory; mounts /api/v1 and, if enabled, the legacy routes
  config.py        settings (VANMITRA_* env vars / .env)
  db.py            engine + per-request session
  errors.py        uniform error body: {error, rule?, message_key, details}
  auth/            PIN hashing, JWT, Principal (role x village), route dependencies
  models/          SQLAlchemy tables
  schemas/         request/response models
  api/v1/          routers
  legacy/          old Model A endpoints: frozen, removed once the app migrates (B-04)
migrations/        Alembic (+ sql/ rendered SQL for review)
scripts/           seed_demo.py
tests/             unit/ and api/ (no database) · db/ (needs VANMITRA_TEST_DATABASE_URL)
```

## Endpoints (Stage 0)

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/health` | none | Always 200; reports `database: ok \| unavailable` |
| POST | `/api/v1/auth/login` | none | `{phone, pin}` → access + refresh tokens |
| POST | `/api/v1/auth/refresh` | refresh token | New token pair |
| GET | `/api/v1/me` | access token | User + roles valid today, per village |

Every error has the same body, so the app can show a local-language message:

```json
{ "error": "NOT_AUTHENTICATED", "message_key": "auth.required", "details": {} }
```

Errors caused by a legal rule also carry `"rule": "Rule 3(1)"`.

## Checks

```bash
./venv/Scripts/ruff check app tests scripts migrations
./venv/Scripts/ruff format --check app tests scripts migrations
./venv/Scripts/mypy app scripts
./venv/Scripts/pytest -q                               # db tests skip without a test database
```

To run the database tests, point `VANMITRA_TEST_DATABASE_URL` at a **throwaway** database. The tests migrate it up and back down to empty. CI does this automatically (`.github/workflows/backend-ci.yml`).

## Settings

| Variable | Default | Notes |
|---|---|---|
| `VANMITRA_DATABASE_URL` | local compose DB | `postgresql+psycopg://…` |
| `VANMITRA_JWT_SECRET` | dev value | **Must** be set when `VANMITRA_ENV=production` (start-up refuses otherwise) |
| `VANMITRA_ENABLE_LEGACY_API` | `true` | `false` skips loading the ML models: faster start, no old AI endpoints |
| `VANMITRA_CORS_ORIGINS` | `["*"]` | JSON list |
