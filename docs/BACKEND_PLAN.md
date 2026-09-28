# VanMitra — Backend Plan (CFR Claim Module)

> **Owner:** Soham · **Support and review:** Ishan · **Status:** v0.1 draft
> Read [`PROJECT_PLAN.md`](PROJECT_PLAN.md) first. This document never overrides it.

The backend is the **system of record** for the claim module. It enforces every hard block, runs the state machine and the legal clocks, keeps the hash-chained records and generates the G-series documents. The app should never be the only place a rule is enforced: if the app is wrong, the server must still refuse.

---

## 1. Where we start from

`vanmitra_backend/` today is a **stateless** FastAPI service with no database:

| Existing endpoint | Keep? | Action |
|---|---|---|
| `GET /api/v1/health` | ✅ | Keep |
| `POST /api/v1/eligibility-check` | ❌ | **Remove.** Breaks rule R1 (the app never decides eligibility) |
| `POST /api/v1/verify-document` (OCR) | ✅ | Move into `assist/`; output is metadata only |
| `POST /api/v1/generate-draft` | ⚠️ | Replace with the Form C document generator (`documents/`) |
| `POST /api/v1/transcribe` | ✅ | Move into `assist/` (elder statements) |
| `POST /api/v1/analyze-rejection`, `/generate-appeal` | ⚠️ | Replace with order recording + G16 petition (Stage 5); keep OCR as an assistant |
| `GET/POST /api/v1/notices` | ✅ | Keep for now (not part of the claim module) |
| `/api/v1/satellite-*` | ⏸️ | Leave as is; post-title only (Stage 7) |
| `ScoringAgent`, `EligibilityAgent`, `evidence_weights.json`, `eligibility_rules.json` | ❌ | **Remove from the claim flow.** Breaks rule R2 (no scores) |

---

## 2. Project structure

```
vanmitra_backend/
├── app/
│   ├── main.py                 # FastAPI app, routers, middleware
│   ├── config.py               # settings from env (pydantic-settings)
│   ├── db.py                   # SQLAlchemy engine/session
│   ├── auth/                   # JWT, password/PIN hashing, role + village scoping
│   ├── models/                 # SQLAlchemy tables (one file per area)
│   ├── schemas/                # Pydantic request/response models
│   ├── api/v1/                 # routers: villages, frc, cases, evidence, boundary,
│   │                           #          verification, meetings, orders, documents, sync
│   ├── domain/                 # PURE rules, no DB or HTTP (easy to test)
│   │   ├── frc_rules.py        #   BR-01, BR-02
│   │   ├── quorum.py           #   Rule 4(2) three tests (BR-03)
│   │   ├── completeness.py     #   10 checks C-1…C-10
│   │   ├── state_machine.py    #   states, allowed transitions, guards
│   │   ├── clocks.py           #   legal deadlines and alert days
│   │   └── ledger.py           #   hash-chain computation
│   ├── services/               # use-cases combining domain + DB
│   ├── geo/                    # PostGIS queries: overlap, adjacency, area (UTM)
│   ├── documents/              # G-series: HTML templates (mr/hi/en) → PDF (WeasyPrint)
│   │   └── templates/
│   ├── storage/                # file storage (local disk → MinIO)
│   └── assist/                 # OPTIONAL AI helpers (OCR, speech-to-text); can be switched off
├── migrations/                 # Alembic
├── tests/
│   ├── domain/                 # unit + property tests for rules
│   ├── api/                    # API tests against a PostGIS test container
│   └── golden/                 # expected PDFs/HTML for every G-document
├── docker-compose.yml          # api + postgis (+ minio later)
├── Dockerfile
└── requirements.txt
```

**Key design rule:** everything in `domain/` is plain Python functions with no database or web imports. That is where the law lives, and it must have the most tests.

---

## 3. Data model

These are the core tables, from Spec §6.5 and the section 4 field lists. Field lists are a starting point; check them against Figure 7 of the Spec before writing the migrations.

> **Legend:** 🔗 = append-only and hash-chained (never `UPDATE`, never `DELETE`)

| Table | Key columns | Notes |
|---|---|---|
| `village` | `id`, `lgd_code`, `name_mr`, `name_en`, `gram_panchayat`, `taluka`, `district`, `parent_village_id`, `consolidation_status` | Hamlet hierarchy [Rule 2A]; taluka → SDLC, district → DLC |
| `gram_sabha` | `id`, `village_id`, `chain_head_hash` | One hash chain per Gram Sabha |
| `gs_member` | `id`, `gram_sabha_id`, `name`, `gender`, `category` (ST / OTFD / other), `is_claimant`, `active` | Used three times: FRC check, quorum, Form C member sheet |
| `app_user` | `id`, `phone`, `pin_hash`, `name`, `gs_member_id?` | Login identity |
| `user_role` | `user_id`, `village_id`, `role` (`facilitator` / `frc_member` / `gs_secretary`), `valid_from`, `valid_to` | A user can have several roles |
| `frc` | `id`, `gram_sabha_id`, `constituted_on`, `resolution_id`, `composition_proof` (JSON), `sdlc_intimated_on` | Stores the arithmetic proof |
| `frc_member` | `frc_id`, `gs_member_id`, `is_chair`, `is_secretary` | Conflict of interest comes from `gs_member.is_claimant` + the case link |
| `case` | `id` (UUIDv7), `gram_sabha_id`, `claim_type` (`CFR`, later `IFR`/`CR`), `state`, `ack_serial`, `claims_called_on`, `window_ends_on` | CFR cases are owned by the Gram Sabha |
| `case_claimant` | `case_id`, `gs_member_id` | Drives recusal and quorum test 3 |
| `evidence` 🔗 | `id`, `case_id`, `rule_ref` (e.g. `13(1)(b)`), `kind` (scan/photo/gps/audio/text), `media_id`, `source_office`, `ref_no`, `doc_date`, `is_substitutable`, `verified_by`, `verified_at`, `supersedes_id`, `prev_hash`, `record_hash` | `rule_ref` is a controlled list; geo items have `is_substitutable=false` |
| `elder_statement` | `evidence_id`, `elder_gs_member_id`, `audio_media_id`, `transcript`, `signed_scan_media_id` | Blocked if the elder is a claimant in the case |
| `cfr_boundary` | `id`, `case_id`, `version`, `geom` (Polygon, 4326), `source`, `status` (`DRAFT` / `GS_APPROVED` / `TITLED`), `area_ha`, `accuracy_stats`, `valid_from`, `valid_to`, `sealed_hash` | Versioned; approved/titled versions are frozen |
| `boundary_segment` | `boundary_id`, `seq`, `geom` (LineString) | |
| `landmark` | `id`, `boundary_id`, `segment_seq`, `name`, `point`, `photo_media_id`, `evidence_id?` | Rule 13(1)(g)/13(2)(c) items become landmarks too |
| `use_zone` | `id`, `boundary_id`, `use_type` (grazing, MFP, water…), `geom`, `season`, `user_hamlets` | Rule 13(2)(b) |
| `boundary_walk` | `id`, `case_id`, `date`, `participants` (elders, named), `trace` (LineString) | G9 source |
| `adjacency` | `case_id`, `neighbour_gs_id`, `shares_resources`, `intimation_id` | Form C item 7 |
| `dispute` | `id`, `case_id`, `neighbour_gs_id`, `overlap_geom`, `joint_meeting_on`, `outcome`, `sdlc_referral_on` | BR-09 |
| `verification_proceeding` 🔗 | `id`, `case_id`, `visit_on`, `intimation_id`, `observations`, `presence` (JSON), `forest_signed`, `forest_absence_recorded`, `revenue_signed`, `revenue_absence_recorded`, `signed_scan_media_id`, `attempt_no`, … hash cols | BR-07; `attempt_no = 2` + absence → Rule 12A(2) finality note |
| `recusal` | `case_id`, `frc_member_id`, `recorded_at`, `reason` | BR-02 |
| `gs_meeting` 🔗 | `id`, `gram_sabha_id`, `date`, `place`, `notice_on`, `agenda`, `registered_count`, `present_count`, `women_present`, `claimants_total`, `claimants_present`, `quorum_result` (JSON, **stored, not recomputed**), … hash cols | |
| `attendance` | `meeting_id`, `gs_member_id`, `present`, `method` (manual / face) | Manual is the legal record |
| `resolution` 🔗 | `id`, `meeting_id`, `case_id`, `number`, `decision_text` (mr/hi/en), `votes_for`, `votes_against`, `boundary_id`, `signed_scan_media_id`, `supersedes_id`, … hash cols | BR-03 guard |
| `authority_actor` | `id`, `office` (SDLC/DLC/…), `designation`, `department`, `jurisdiction`, `valid_from`, `valid_to` | Configuration, not code; used for addressing letters |
| `authority_order` 🔗 | `id`, `case_id`, `issued_by_actor_id`, `kind` (ack / forward / remand / modify / reject / title / record_entry), `order_date`, `communicated_on`, `reasons_given`, `grounds` (JSON), `scan_media_id`, … hash cols | The **only** way post-submission states change (R1) |
| `workflow_event` 🔗 | `id`, `case_id`, `from_state`, `to_state`, `actor_user_id`, `authority_order_id?`, `reason`, `due_date?`, `created_at`, … hash cols | Audit spine |
| `legal_clock` | `id`, `case_id`, `kind`, `starts_on`, `due_on`, `extended_to?`, `status`, `alerts_sent` | |
| `correspondence` | `id`, `case_id`, `template` (G2/G5/G6/G7/G18…), `addressee_actor_id`, `dispatched_on`, `reminder_on`, `outcome` | Tracked outgoing letters |
| `generated_document` | `id`, `case_id`, `template`, `language`, `media_id`, `generated_at`, `signed_scan_media_id?` | G-series outputs |
| `media` | `id`, `sha256`, `mime`, `size`, `storage_key`, `captured_at`, `gps`, `accuracy_m`, `uploaded_complete` | Files themselves live in storage |
| `consent` | `id`, `gs_member_id`, `purpose`, `given_at`, `withdrawn_at`, `method` (written / oral-recorded) | Stage 6 |
| `audit_log` | `id`, `actor`, `action`, `object`, `purpose`, `at` | Stage 6 |

**Hash chain** (Spec §6.8):
```
record_hash(n) = SHA256( canonical_json(payload(n)) || record_hash(n-1) )
```
- One chain per Gram Sabha, covering every 🔗 table.
- A database trigger or role grant blocks `UPDATE`/`DELETE` on 🔗 tables.
- A correction is a new row with `supersedes_id` and a reason.
- The chain head is printed in the Gram Sabha register weekly as an offline anchor.

---

## 4. API surface

All endpoints are under `/api/v1`, need a JWT, and are scoped to the user's villages. The contract is published as OpenAPI at `/docs`. The frontend builds against it.

| Stage | Method | Endpoint | Purpose | Guard |
|---|---|---|---|---|
| 0 | POST | `/auth/login` | Phone + PIN → JWT (roles, villages) | |
| 0 | GET | `/me` | Current user, roles, villages | |
| 1 | POST/GET | `/villages`, `/villages/{id}` | Village + hamlet registry | Facilitator |
| 1 | POST/GET | `/gram-sabhas/{id}/members` | Member roster | GS Secretary |
| 1 | POST | `/gram-sabhas/{id}/frc` | Constitute FRC | **BR-01**; GS Secretary |
| 1 | GET | `/gram-sabhas/{id}/frc/check` | Live composition check (for the UI while editing) | |
| 2 | POST | `/cases` | Create case `{claim_type: CFR}` | Facilitator/FRC |
| 2 | POST | `/cases/{id}/acknowledge` | Issue acknowledgement (serial number) | FRC |
| 2 | POST | `/cases/{id}/window/extend` | Extend window (reason + resolution ref) | GS Secretary |
| 2 | POST | `/media` (resumable, chunked) | Upload a file with checksum | |
| 2 | POST | `/cases/{id}/evidence` | Add evidence `{rule_ref, media_id, …}` | |
| 2 | POST | `/cases/{id}/evidence/{eid}/verify` | FRC attests an item | FRC; **BR-02** |
| 2 | GET | `/cases/{id}/completeness` | 10 checks with rule citations + local-language hints | |
| 2 | POST | `/cases/{id}/correspondence` | Create G2/G5/G6 letter; track dispatch | |
| 2 | POST | `/sync/batch` | Offline outbox drain (idempotent, causal order) | |
| 3 | POST | `/cases/{id}/boundary` | Upsert draft polygon (GeoJSON) + segments | |
| 3 | POST | `/cases/{id}/boundary/landmarks`, `/use-zones`, `/walks` | Landmarks, use zones, walk record | |
| 3 | GET | `/cases/{id}/boundary/conflicts` | PostGIS overlap vs neighbours | → dispute (**BR-09**) |
| 3 | POST | `/cases/{id}/disputes/{did}/joint-meeting` | Record joint meeting / SDLC referral | |
| 4 | POST | `/cases/{id}/verification` | Proceeding + signatures / absence | **BR-07**, **BR-02** |
| 4 | POST | `/meetings`, `/meetings/{id}/attendance` | Meeting; attendance returns live quorum | GS Secretary |
| 4 | POST | `/meetings/{id}/resolutions` | Record resolution | **BR-03**; GS Secretary |
| 2–5 | POST | `/cases/{id}/transitions` | Request a state change `{to_state, reason}` | State-machine guards; **no outcome states** |
| 2–5 | POST | `/cases/{id}/documents/{template}?lang=mr` | Render G-document (async) → `generated_document` | **BR-08** for G10 |
| 5 | POST | `/cases/{id}/submit` | Submit to SDLC (upload SDLC acknowledgement) | **BR-04**; FRC |
| 5 | POST | `/cases/{id}/orders` | Record an authority order (order date **and** communication date) | Moves post-submission states; starts clocks (**BR-10**, **BR-12**) |
| 5 | GET | `/cases/{id}/timeline` | Workflow events + legal clocks with days remaining | |
| 5 | POST | `/cases/{id}/close` | Close the case | **BR-13** |
| 2–5 | GET | `/gram-sabhas/{id}/ledger/verify` | Re-verify the hash chain | |

**Error format:** every blocked action returns `409` or `422` with a rule citation, so the app can show it in plain language:
```json
{ "error": "FRC_COMPOSITION_INVALID",
  "rule": "Rule 3(1)",
  "message_key": "frc.too_few_women",
  "details": { "women": 3, "required": 4, "members": 12 } }
```

---

## 5. Core logic: how to implement it

### 5.1 State machine (`domain/state_machine.py`)
- Keep a table of `(from_state, to_state) → guard function`. There are no ad-hoc `if` statements elsewhere.
- **Outcome states** (`SDLC_FORWARDED`, `DLC_UNDER_CONSIDERATION`, `REMANDED_TO_GS`, `MODIFIED_REJECTED`, `TITLE_APPROVED`, `RECORD_UPDATED`) can only be reached through `POST /orders`. `POST /transitions` rejects them (BR-14).
- Every transition writes a `workflow_event` in the same database transaction.

### 5.2 FRC check (`domain/frc_rules.py`, BR-01)
```
10 <= n <= 15
if any ST members: st  >= ceil(2n/3)
women >= ceil(n/3)
```
Return *which* test failed and by how much, not just `false`.

### 5.3 Quorum (`domain/quorum.py`, BR-03)
```
t1 = present            >= ceil(registered / 2)
t2 = women_present      >= ceil(present / 3)
t3 = claimants_present  >= ceil(claimants_total / 2)   # only for resolutions on claims
pass = t1 and t2 and t3
```
Store the inputs **and** the result on `gs_meeting.quorum_result` at the time of the meeting. Never recompute it later.

### 5.4 Completeness (`domain/completeness.py`)
- Returns `{ "done": 8, "total": 10, "items": [{ "id": "C-4", "ok": false, "rule": "12(1)(g)", "hint_key": "…" }] }`.
- Only `verified` evidence counts. `is_substitutable=false` items are never counted towards C-1 or C-2 (BR-06).
- **Advisory only.** It never blocks a transition (BR-05).

### 5.5 Legal clocks (`domain/clocks.py`)
- Adverse order → 60-day clock **from `communicated_on`** (BR-10). If the communication date is missing, the API refuses to save the order.
- Alert days: 30, 45, 55 and 58. A daily background job sends push notifications through FCM.
- The 30-day extension is stored as `extended_to`, with a reference.

### 5.6 Documents (`documents/`)
- One Jinja2 HTML template per G-document per language → WeasyPrint → PDF, with Noto Sans Devanagari embedded.
- Every document has a footer with the case ID, the generation time, the document hash and the disclaimer *"Community record prepared with VanMitra. Not a government document."*
- **Golden-file tests:** render each template with fixed data and compare it with the stored expected output.

### 5.7 Offline sync (`/sync/batch`)
- The device mints **UUIDv7** IDs, so records created offline keep their identity.
- A batch is a list of operations in causal order. Each operation carries an idempotency key, so a batch can be retried safely.
- Append-only rows never conflict. Descriptive fields (for example, village population) use last-writer-wins.
- **An edit to a signed record → a `sync_conflict` for a person**, never an overwrite.

### 5.8 Geo (`geo/`)
- Store geometry in EPSG:4326. Compute area in UTM zone 43N (EPSG:32643) for Palghar and print hectares from that.
- Use `ST_IsValid` before saving, and `ST_Intersects` / `ST_Overlaps` against neighbouring draft and approved polygons.
- Never clip the polygon to forest or legal boundaries.

---

## 6. Security

- JWT (short-lived access token + refresh token). PINs are hashed with Argon2.
- Every query is filtered by the user's villages. Add PostgreSQL row-level security in Stage 6.
- No endpoint returns exact geometry or personal documents without a role and a consent check.
- Secrets come only from environment variables (`.env` is never committed).
- CORS limited to the app and the admin origin.

---

## 7. Testing

| Kind | Tool | What |
|---|---|---|
| Unit + property | `pytest` + `hypothesis` | `domain/`: FRC, quorum, completeness, clocks, state machine, hash chain |
| API | `pytest` + `httpx` + PostGIS container (`testcontainers`) | Every endpoint, including every hard block |
| Golden files | `pytest` | Every G-document in mr/hi/en |
| Contract | `schemathesis` against OpenAPI | Stage 2 onwards |

The target is 100% branch coverage on `domain/`, since that is where the legal rules live.

---

## 8. Backend decisions

**How to read the Status column:**
- **☑ Decided:** final. Build on it.
- **◐ Proposed default:** we build on the recommendation unless someone objects in review. To change one, open a `docs/` PR that edits this table.
- **☐ Open:** needs an answer from outside the team (NGO, SDLC or district) before the stage in the "Needed by" column.

Items marked **D1–D6** are the project-level decisions in [`PROJECT_PLAN.md` §9](PROJECT_PLAN.md#9-open-decisions). Keep both tables in step.

### 8.1 Already decided
| # | Decision | Outcome | Date |
|---|---|---|---|
| D2 | Database / system of record | **PostgreSQL 16 + PostGIS 3.4** behind FastAPI; Hive on the device; Firebase for FCM push only | 2026-09-28 (Soham) |

### 8.2 Needed before Stage 0 (these block the skeleton)
| # | Decision | Options | Recommended default | Status |
|---|---|---|---|---|
| B-01 (D1) | App roles | Keep the 3 roles / change them | `facilitator`, `frc_member`, `gs_secretary`. The role list goes into the first migration | ◐ |
| B-02 (D3) | Login method | Phone + PIN · SMS OTP · Keycloak | Phone + PIN (Argon2), JWT access + refresh. OTP needs a paid SMS provider | ◐ |
| B-03 | Who creates accounts | Admin seeds · GS Secretary invites · open sign-up | Admin creates the Facilitator and GS Secretary; the GS Secretary adds FRC members. **No open sign-up** | ◐ |
| B-04 (D6) | Old AI endpoints | Delete now · keep until the app migrates | Keep them working until the frontend moves each screen, then remove `eligibility-check` and scoring. Move OCR and transcription into `assist/` | ◐ |
| B-05 | Where the new code lives | Inside `vanmitra_backend/` · new folder | Inside `vanmitra_backend/`. `railway.toml` already points there | ◐ |
| B-06 | Sync or async database access | SQLAlchemy 2 sync · async | **Sync**. Simpler, and works cleanly with GeoAlchemy2; FastAPI runs it in a thread pool | ◐ |
| B-07 | Existing Firestore data | Migrate · start fresh | Start fresh with a seed script (Ozhar village + demo users). *Confirm there is no real claimant data in Firestore* | ◐ |

### 8.3 Needed before Stage 2 (evidence and sync)
| # | Decision | Recommended default | Status |
|---|---|---|---|
| B-08 | How the app syncs | One idempotent `POST /sync/batch` endpoint (Spec §6.7). **Agree the payload with the frontend lead**, because it shapes the offline outbox | ◐ |
| B-09 | Who creates record IDs | The device generates UUIDv7 (Python: `uuid6` package on 3.12) | ◐ |
| B-10 | File storage | MinIO in Docker Compose from day one, behind a small `storage/` interface | ◐ |
| B-11 | Making records tamper-proof | Block `UPDATE`/`DELETE` on 🔗 tables in the database itself (trigger + role grants), not only in code; hash payloads with RFC 8785 canonical JSON | ◐ |
| B-12 | Background jobs | FastAPI `BackgroundTasks` + APScheduler (daily clock job); Celery + Redis only if the load needs it | ◐ |

### 8.4 Needed before Stage 3 (mapping)
| # | Decision | Recommended default | Status |
|---|---|---|---|
| B-13 | **Where neighbouring villages' boundaries come from** (overlap detection, BR-09) | Ask the NGO or SDLC. Candidates: official village boundary layers (MRSAC, Bhuvan) or the neighbours' own CFR claims. **This is the biggest unknown** | ☐ Ask NGO / SDLC |
| B-14 | GPS accuracy limit for boundary points | 15 m; points worse than this are drawn differently and listed on the map sheet | ◐ |
| B-15 | Offline map tiles | Backend builds a district tile pack (PMTiles/MBTiles) that the app downloads before a field visit | ◐ |

### 8.5 Needed before Stages 4–5
| # | Decision | Recommended default | Status |
|---|---|---|---|
| B-16 (D5) | Face-recognition attendance | Keep as an optional Helper. **Face embeddings stay on the device only**; the server stores just `method = face` on the attendance row. Manual attendance is the legal record | ◐ |
| B-17 | Where the Gram Sabha member list comes from (quorum count) | The electoral roll from the SDLC under Rule 6(b), imported and then corrected by the GS Secretary | ☐ Ask SDLC |
| B-18 | Who checks the Marathi / Hindi document wording | The partner NGO reviews every G-template before golden-file tests lock it in | ☐ Ask NGO |
| B-19 | Deadline alert channel (days 30/45/55/58) | FCM push; add SMS later if the pilot shows push is missed | ◐ |

### 8.6 Needed before the pilot (Stage 6)
| # | Decision | Recommended default | Status |
|---|---|---|---|
| B-20 (D4) | Hosting | One small Indian-region VM with Docker Compose, or a State data centre if offered. Decide who pays | ☐ |
| B-21 | Data-sharing agreement / data responsibility (DPDP Act 2023) | The Gram Sabha owns the data; the NGO and the team are custodians under a written agreement | ☐ Ask NGO |
| B-22 | Backups | Nightly encrypted off-site copy + WAL archiving; name two people who can restore | ☐ |

**This week:** only **B-01 to B-08** matter. B-13 and B-17 depend on the NGO or government, so ask them early. They don't block anything yet.

---

## 9. Stage checklists

### Stage 0: Foundations
- [ ] `docker-compose.yml` with `postgis/postgis:16-3.4` + the API; `.env.example`
- [ ] SQLAlchemy + Alembic; first migration (`village`, `gram_sabha`, `gs_member`, `app_user`, `user_role`)
- [ ] JWT auth, 3 roles, village scoping dependency
- [ ] Error format with rule citations
- [ ] Remove `eligibility-check` and scoring from the claim path; move OCR/transcribe to `assist/`
- [ ] GitHub Actions: ruff, mypy, pytest
- [ ] Seed script: Ozhar village, 1 Gram Sabha, demo members, 3 demo users

### Stage 1: Village and FRC
- [ ] Village/hamlet and member CRUD
- [ ] `frc_rules.py` + tests (all boundary cases: 9/10/15/16 members, ⅔ ST, ⅓ women, no STs)
- [ ] `POST /frc`, `GET /frc/check`
- [ ] G3 template (mr/hi/en) + golden test

### Stage 2: Case and evidence
- [ ] `case`, `evidence`, `elder_statement`, `media`, `correspondence`, `workflow_event` + hash chain + append-only enforcement
- [ ] Resumable media upload with checksum
- [ ] Rule 13 `rule_ref` vocabulary
- [ ] `completeness.py` (C-1, C-2, C-6, C-9 now; the rest as their data arrives)
- [ ] `/sync/batch`
- [ ] G1, G2, G4, G5, G6 + Form C draft

### Stage 3: Mapping
- [ ] Boundary versions, segments, landmarks, use zones, walks
- [ ] Overlap detection → dispute; joint meeting / referral
- [ ] UTM area; validity checks
- [ ] G9, G10 (BR-08), G17

### Stage 4: Verification and Gram Sabha
- [ ] Verification proceeding (BR-07, BR-02, recusal, second-absence note)
- [ ] Meetings, attendance, `quorum.py` (BR-03) + tests
- [ ] Resolutions (links boundary → `GS_APPROVED` and freezes it)
- [ ] All 10 completeness checks
- [ ] G7, G8, G11, G12, G13, G14

### Stage 5: Submit and track
- [ ] Submission (BR-04), G15, G20
- [ ] `authority_order` + order-driven transitions
- [ ] `clocks.py` + daily alert job + FCM
- [ ] Remand checklist; petition G16 (grounds from BR-12 and Rule 12A(10)/(11))
- [ ] Title upload, survey pending (G18), record entry, close (BR-13)

### Stage 6: Hardening
- [ ] Consent, audit log, row-level security
- [ ] Backups (WAL archiving + nightly off-site copy)
- [ ] Security review; rate limits; TLS in deployment
- [ ] Load check: overlap under 2 s for a district
