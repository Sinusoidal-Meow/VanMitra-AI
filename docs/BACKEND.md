# VanMitra Backend: a plain-language guide

This is the guide to the backend **as it is built today**. Read it first if you are new.
`BACKEND_PLAN.md` is the older plan written before the build; this file describes what
actually exists. The exact request and response shapes are in the API docs listed in §11.

---

## 1. What the backend is for

VanMitra helps a village file a claim under the **Forest Rights Act (FRA) 2006**, and
helps the officials above the village review it.

The backend is a web service (an API) that the phone app talks to. It:

- keeps the **claim forms**: Form A (one person's land), Form B (community rights) and
  Form C (the community forest resource, called CFR);
- moves a claim through **review**: the village, then the sub-division, then the district;
- records the **procedure the law requires** around a Form C claim: the forest rights
  committee, evidence, the boundary map, the site visit, the Gram Sabha meeting and its
  vote, and the printable documents;
- keeps the record **tamper-evident**, so nobody can quietly change what was recorded.

One rule runs through everything: **the system records and checks; people decide.**
Completeness checks only tell you what is missing. They never give a score or decide
eligibility.

---

## 2. The big picture

```
 Phone app (Flutter)
        |  HTTPS / JSON  (login token on every request)
        v
 +-----------------------------------------------+
 |  FastAPI  (app/api/v1/*)                      |   <- the "doors": URLs, who may enter
 |     |                                         |
 |     v                                         |
 |  domain/   pure rules, no database            |   <- the "law": quorum, FRC, workflow...
 |  services/ rules that need the database       |
 |     |                                         |
 |     v                                         |
 |  models/   collections -> MongoDB (Atlas)     |   <- the "memory": data and GeoJSON
 +-----------------------------------------------+
        |
        +--> media_store/   (uploaded scans and photos, kept on disk)
```

Why it is split this way: the **rules of the law live in `domain/`** with no database in
sight, so they are easy to read and to test. The **API layer only checks who is asking**
and calls the rules.

---

## 3. Who can log in, and what they can do

Everyone logs in with a **phone number and a 6-digit PIN**. Each login has a role, and a
role covers a **place** (a village, a taluka or a district).

| Level | Role | Covers | Main job |
|---|---|---|---|
| Village | **villager** | their village | Files Form A or Form B; adds evidence while drafting |
| Village | **gram_sabha** | their village | Runs the Gram Sabha: Form C, the FRC, meetings, boundary, resolutions; reviews claims |
| Sub-division | **sdo** | a taluka | Reviews claims the Gram Sabha forwarded |
| District | **collector**, **dfo**, **tribal_welfare_officer** | a district | All three review and approve; the title is issued when all three have |

An official only ever sees cases **in their own area**, and only once a case has reached
their level. A person from another village gets "not found", not "forbidden".

Demo logins (development only): phones `9000000001` to `9000000008`, PIN `123456`.

---

## 4. The life of a claim

```
 draft  --submit-->  gs_review  --approve-->  sdo_review  --approve-->  district_review
   ^                    |                         |                          |
   |                    +------- return ----------+------- return -----------+
   +--- return (to the claimant) ...                                          |
                                                                 all three approve
                                                                              v
                                                                        title_issued
 Any reviewer may also reject (with written reasons) -> rejected
```

- **Submit** is done by the person who started the claim.
- **Approve** moves it up one level. At the district, **each of the three officers
  approves once**; the title is issued when all three have.
- **Return** sends it back **one level down**, with remarks.
- **Reject** needs written reasons and ends the claim.
- Every action is saved in the case **history** (who, in which role, what, when, remarks).

### Extra rule for Form C (CFR) claims
The Gram Sabha **cannot forward a Form C claim** to the SDO until:

1. a Gram Sabha **resolution** has passed with full quorum;
2. that resolution has **approved the boundary** (this freezes it);
3. the **field verification** is closed (the Forest and Revenue officials signed, or their
   absence is recorded);
4. there is **no open boundary overlap dispute** with a neighbouring village.

`GET /cases/{id}/approval-check` lists what is still missing. Form A and Form B claims
do not have this extra rule.

---

## 5. What each part of the procedure does

The backend was built in stages. Each row says what the stage covers and where the
details are.

| Stage | Covers | Key rules |
|---|---|---|
| **Module 3** | Three-level logins, Forms A/B/C, review workflow, title draft (Annexure II, III, IV) | |
| **1. Village & FRC** | Villages and hamlets; the Forest Rights Committee must be properly made up (10 to 15 members, at least two-thirds ST, at least one-third women, chair and secretary separate); which Gram Sabha members are claimants in a case | Rule 3 |
| **2. Claims & evidence** | Call for claims (3-month window, extension needs reasons); written acknowledgement with a serial number; uploaded files; the evidence list tagged by Rule 13 clause; verification; letters sent and tracked; documentation completeness checks R1 to R10 | Rules 11, 13 |
| **3. The map** | The claimed boundary (drawn with GPS, stored as a map shape), split into segments; a landmark for each segment; use zones (grazing, water, and so on); the boundary walk with the elders; **overlap with a neighbour opens a dispute** until a joint meeting or a referral to the SDLC | Rule 12(1)(g), 12(3) |
| **4. Site visit & Gram Sabha** | Field verification with Forest and Revenue officials; Gram Sabha meetings with an attendance register; the **three quorum tests**; resolutions; the approval guard in §4 | Rules 4(2), 12A |
| **5. Documents & follow-up** | Printable pages G4, G7-type letters, G8, G9, G10 (map sheet), G12, G13, G17; legal clocks (claim window, 60-day petition, 30-day mutual solution, 3-month record update); after the title: certified copy, record entry, closing the file | Rules 8(i), 12A(9) |

### The three quorum tests (Rule 4(2))
All three must pass before a resolution on a claim can be recorded:

1. members present are **at least half** of the registered members;
2. women present are **at least one-third** of those present;
3. claimants present are **at least half** of the claimants in that case.

The numbers are saved with the resolution on the day and **never recalculated**.

### Documentation checks R1 to R10
Advisory only. They list what is missing, for example "fewer than two verified Rule 13(1)
evidences" or "a boundary segment has no landmark". They never block anything and are
never shown as a score.

---

## 6. Keeping the record trustworthy

- **Append-only.** Evidence, verifications, resolutions, site-visit records and the case
  history cannot be edited or deleted. A database trigger refuses any change. A
  **correction is a new record** that points at the old one and gives a reason.
- **Hash chain.** Every such record is linked into a chain for its Gram Sabha:
  `hash(n) = SHA-256( record n  +  hash(n-1) )`. If anyone alters an old record, the
  chain breaks. `GET /villages/{id}/ledger/verify` re-checks the whole chain and names the
  first broken record.
- **Frozen boundary.** Once the Gram Sabha approves a boundary it is sealed with a hash
  and can no longer be edited. A new version needs a new resolution.
- **Files are content-addressed.** An uploaded file is stored under its SHA-256, so the
  stored bytes can be checked later.
- **GPS and satellite items never count on their own** towards the two-evidence test.

---

## 7. Where things are (folder map)

All backend code is in `vanmitra_backend/app/`.

```
app/
  main.py            starts the app and registers the routers
  config.py          settings, read from environment variables (prefix VANMITRA_)
  db.py              database connection
  errors.py          the error format every endpoint returns
  storage.py         saving and finding uploaded files
  geo.py             map helpers (GeoJSON in, segments out)
  documents.py       the printable G-series pages

  api/v1/            THE DOORS: one file per area
     auth, admin, members, villages (FRC), cases, form_a/b/c, workflow,
     claim_calls (call for claims + letters), media, evidence,
     boundary, gramsabha (visit, meetings, resolutions), documents, followup, health
  auth/              login, passwords (Argon2), who-may-do-what (principal.py)
  domain/            THE LAW, pure rules with no database
     workflow, frc, quorum, readiness, clocks, dates, form_a, form_b, form_c
  services/          rules that need the database
     cases, ledger (hash chain), readiness, boundary (map queries),
     gramsabha, acknowledgement, title
  models/            THE TABLES (SQLAlchemy)
     people, claims, procedure, boundary, enums
  schemas/           THE SHAPES of requests and responses (Pydantic)
  legacy/            the old AI endpoints, kept until the app moves off them

migrations/          database changes, in order (0001 to 0010) + the SQL for each in migrations/sql/
tests/unit/          fast tests, no database
tests/db/            tests against a real PostgreSQL + PostGIS
scripts/seed_demo.py demo villages and users
```

**Rule of thumb for adding a feature:** put the legal rule in `domain/`, the table in
`models/`, the request/response shape in `schemas/`, the URL in `api/v1/`, and add a test.

---

## 8. The data, in groups

| Group | Collections (plain names) |
|---|---|
| **People & places** | villages (and hamlets), Gram Sabhas, Gram Sabha members, users, user roles |
| **The claim** | claim cases, Form A, Form B, Form C (and their parts), workflow events |
| **Committee & claimants** | FRCs and their members, claimants per case, recusals |
| **Claim procedure** | calls for claims, letters, uploaded files, evidence, evidence verifications |
| **The map** | boundaries (versioned), segments, landmarks, use zones, boundary walks, disputes |
| **Gram Sabha decisions** | site-visit records, meetings, attendance, resolutions |
| **After the title** | title follow-up (certified copy, survey, record entry, closed on) |
| **Integrity** | ledger entries (the hash chain) |

Ids are **UUIDv7** (time-ordered), so the app can later create records offline without
clashing.

---

## 9. Running it on your computer

**Needed:** Python 3.12 and MongoDB (MongoDB Atlas or local replica set).

```bash
# 1. configure MongoDB connection in .env
cd vanmitra_backend
# Edit .env and set VANMITRA_MONGODB_URI

# 2. ensure MongoDB indexes and seed initial demo data
./venv/Scripts/python -m scripts.seed_demo

# 3. start the API (port 8010; port 8000 is used by another project here)
./venv/Scripts/python -m uvicorn app.main:app --host 0.0.0.0 --port 8010
```

- **Slow start?** The old AI endpoints load a model first (about 40 seconds). For a fast
  start set `VANMITRA_ENABLE_LEGACY_API=false` in `.env`.
- **Settings** go in `vanmitra_backend/.env` (copy `.env.example`). Never commit `.env`.
- **Check it works:** open `http://localhost:8010/api/v1/health`. It should say
  `"database":"ok"`. Interactive docs are at `/docs`.
- **From a USB-connected phone:** the app calls `127.0.0.1:8000`; forward that to the
  backend with `adb reverse tcp:8000 tcp:8010`. Run it again after unplugging.
  The app must be built with `--dart-define=VANMITRA_API_BASE_URL=http://127.0.0.1:8000`.

---

## 10. Testing and CI

```bash
cd vanmitra_backend
./venv/Scripts/ruff check app tests scripts
./venv/Scripts/ruff format --check app tests scripts
./venv/Scripts/mypy app scripts
./venv/Scripts/pytest -q
```

- The **database tests** (`tests/db/`) run when `VANMITRA_TEST_MONGODB_URI` points
  at a **throwaway** MongoDB database.
- **GitHub CI** (`.github/workflows/backend-ci.yml`) runs linting, formatting, type check,
  and unit and API tests on every push.

---

## 11. Where the details are

| Need | Read |
|---|---|
| Module 3: logins, Forms A/B/C, workflow, title draft | `docs/API_MODULE3.md` |
| Form B and Form C fields | `docs/API_FORM_B.md`, `docs/API_FORM_C.md` |
| Everything in the procedure (Stages 1 to 5) | `docs/API_PROCEDURE.md` |
| The legal source (Act, Rules, forms) | `1mitra.md` |
| The original plan and open decisions | `docs/BACKEND_PLAN.md` |

---

## 12. Rules for working on this backend

- **Database is MongoDB:** documents use Pydantic models with `Store` unit of work.
  Geometries use Shapely 2.0 with PyProj metric projections (EPSG:32643 UTM 43N).
- **Indexes:** defined in `INDEXES` in `app/mongo.py` and applied with `python -m scripts.setup_mongo`.
- **Personal data stays out of git:** claim photos, `.env` and `google-services.json`.
- **Rule violations return status 409** with a `rule` field (for example `"Rule 3(3)"`).

---

## 13. Not built yet

- Offline sync from the phone (`/sync/batch`).
- Consent records, audit log and row-level security (the planned "Stage 6").
- Orders from outside the app (remand, adverse orders) and their petition clocks. In this
  module officials act inside the app instead.
- PDF output (documents are printable HTML) and G1, G2, G3, G11, G14, G15, G16, G20.
- Sending reminders (the clocks work out the dates; nothing sends a notification yet).
- Demo seed data for the new procedure.
- **Open decision (B-13):** where neighbouring villages' official boundaries come from.
  Until it is settled, an overlap is only detected against claims already in the system.
- App screens for the Stage 1 to 5 features.
