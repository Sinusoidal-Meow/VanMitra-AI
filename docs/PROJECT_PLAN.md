# VanMitra — CFR Claim Module: Project Plan

> **Status:** v0.1 draft for team review · **Owner:** whole team
> **Source of truth for the law:** `VanMitra_CFR_Claim_Module.pdf` (the "Spec") and `cfr_workflow.pdf` (the "Reference Sheet").
> **Companion documents:** [`BACKEND_PLAN.md`](BACKEND_PLAN.md) · [`FRONTEND_PLAN.md`](FRONTEND_PLAN.md)

This is the plan everyone follows. If something here is wrong, change the document through a pull request first, then change the code. Do not let the code and this plan disagree.

---

## 1. What we are building

VanMitra is an app that helps a village prepare, file and track a **Community Forest Resource (CFR) claim** under **Section 3(1)(i) of the Forest Rights Act, 2006**, using **Form C**. It will be used together with the government and a partner NGO.

A CFR claim is not a land-ownership claim. The village is asking for recognition of its right to **protect, regenerate, conserve and manage** its customary forest. A rejected claim hurts the whole village, not one family. A missing signature, a quorum that was never recorded or a missed 60-day deadline can be enough to get a claim rejected, so the app has to get the procedure exactly right.

### What VanMitra is, and what it is not

| VanMitra **is** | VanMitra **is not** |
|---|---|
| A community-side record and preparation tool | A government system of record |
| A checklist that tells the village what is still missing | A judge of eligibility or an approver of claims |
| A generator of the paper documents the law requires | A replacement for signed paper documents |
| A tracker of legal deadlines | A decision-maker at any stage |

All legal decisions stay with the **Gram Sabha, SDLC, DLC and SLMC**. The app only *records* decisions, and only from an uploaded order document.

### Scope for this build

- **In scope:** the CFR claim (Form C), from setting up the village to recording the right in government records.
- **Designed for, but not built now:** individual claims (Form A) and community-rights claims (Form B). The data model keeps a `claim_type` field so these can be added later without a redesign.
- **Out of scope for now:** post-title forest management (CFRMC), satellite monitoring, the quarterly SLMC reports, the Section 8 notice and the AI legal chat assistant. These are listed under Stage 7 (Later).

---

## 2. The ten rules we never break

These come from Section 2.3 of the Spec. Every pull request is checked against them.

| # | Rule | What it means in code and UI |
|---|---|---|
| R1 | **The app never decides a claim.** | No role can set an outcome. Outcomes are recorded only from an uploaded authority order. |
| R2 | **No scores, no "eligible".** | Readiness is always shown as **"Documentation completeness: 8 of 10 items"**, with the missing items named. Never a percentage, score, "eligible", "approved" or "valid". |
| R3 | **Satellite and GPS data is supporting evidence only.** | Geo evidence is marked `is_substitutable = false` and can never meet the two-evidence test on its own. |
| R4 | **Paper is the real record.** | Every legal document is printable with a signature or thumb-impression block. The app stores the *scan of the signed original*. |
| R5 | **The NGO cannot bypass the Gram Sabha.** | The facilitator can only create drafts. Submission needs an FRC user, and a resolution needs the Gram Sabha Secretary. |
| R6 | **No committee below the Gram Sabha decides anything.** | There is no block-level or beat-level decision role at all. |
| R7 | **Legal deadlines are never lost silently.** | Every adverse order starts a visible countdown, with alerts on day 30, 45, 55 and 58. |
| R8 | **Records are tamper-evident.** | Evidence, meetings, resolutions and workflow events are append-only and hash-chained. A correction is a new row that points to the old one. |
| R9 | **Community data is private.** | Personal data, exact boundary coordinates and elders' statements are never exposed publicly and are shared only with consent. |
| R10 | **The village can work offline for weeks.** | Everything needed to prepare a claim works offline. Only sync and AI help need a network. |

**Traceability rule:** every screen, field and state change must point to a numbered provision of the Act, the Rules or the Guidelines. A feature that cannot be traced is a *facilitation* feature, and the UI must label it as such.

---

## 3. Roles: reduced from 12 to 3

The current app has 12 roles, including SDLC, DLC, DFO, Collector and others. Those are **government offices**. Under Rule R1 they should not act inside our app, so we remove them as app roles. Government officers receive the printed packet, as the law intends, and their orders are uploaded into the app as documents.

| # | App role | Who holds it | Can do | Cannot do |
|---|---|---|---|---|
| 1 | **Facilitator** | Trained NGO field worker | Set up the village profile; create draft cases; capture evidence, photos, GPS points and elders' audio; prepare documents for printing; run the completeness check | Sign anything; record a resolution; mark a claim submitted; change a signed record |
| 2 | **FRC Member** (chair and secretary are flags on the member) | Elected Forest Rights Committee member | Acknowledge claims; verify and attest evidence; lead the boundary walk; record field verification; author Form C; mark submission; record orders received from authorities | Verify a claim in which they are a claimant [Rule 3(3)]; pass a resolution |
| 3 | **Gram Sabha Secretary** | Secretary of the Gram Panchayat [Rule 11(6)] | Maintain the member roster; record the FRC constitution; create meetings; record attendance and quorum; record and publish resolutions | Change evidence or verification records |

**Also:**
- **Admin** is a back-office account for the implementation team (districts, master data, officer addresses). It is not an app role, and it cannot edit case content or records.
- **One person can hold more than one role** in a small village, but the conflict-of-interest rules still apply.
- **Villagers and government officers** do not log in during this build. A read-only "authority viewer" link and a public village status page are planned for Stage 7.

**Mapping from the current 12 roles:** `villager` → removed (reads the public status later) · `frc` → **FRC Member** · `forestOfficer`, `revenueOfficer`, `sdlc`, `dlc`, `dfo`, `tribalWelfare`, `collector`, `recordOfficer`, `slmc` → removed (their actions become *uploaded documents*) · `admin` → back-office only · **Facilitator** and **Gram Sabha Secretary** → new.

---

## 4. The claim workflow

### 4.1 What the user sees: 6 simple steps

The legal process has 14 stages. To keep the app easy to understand, the UI groups them into **6 steps**. Each step shows a checklist with a short instruction in the local language.

| Step | Name in the app | Legal stages covered (Spec §5.1) | Main output |
|---|---|---|---|
| 1 | **Set up the village** | 0 Preparation · 1 FRC constitution | Village profile, member roster, valid FRC certificate (G3) |
| 2 | **Call for claims** | 2 Calling of claims · 3 Claim registration | Notice (G1), intimations (G2), acknowledgement (G4) |
| 3 | **Collect evidence and map the forest** | 4 Evidence · 5 Boundary · 6 Overlap | Evidence schedule, CFR map (G10), boundary record (G9) |
| 4 | **Field verification** | 7 Field verification | Signed verification sheet or recorded absence (G8) |
| 5 | **Gram Sabha approval** | 8 Findings and map · 9 Resolution | Findings (G14), quorum sheet (G12), resolution (G13) |
| 6 | **Submit and track** | 10 Submission · 11 SDLC · 12 DLC · 13 Title and record | Covering letter (G15), orders, deadlines, petitions, title |

### 4.2 Claim state machine (internal)

The backend runs an explicit state machine (Spec §6.2). Every change writes a `workflow_event` row recording who acted, on what authority, with what order reference, and which legal clock it starts.

```
DRAFT → EVIDENCE_COLLECTION → MAPPING_IN_PROGRESS ⇄ DISPUTE_JOINT_HEARING
      → FRC_VERIFICATION → GS_READY → GS_RESOLVED → SUBMITTED_SDLC
      → SDLC_UNDER_EXAM → SDLC_FORWARDED → DLC_UNDER_CONSIDERATION
      → TITLE_APPROVED → (SURVEY_PENDING) → RECORD_UPDATED → CFR_ACTIVE

Detours the law provides for:
  SDLC_UNDER_EXAM / DLC_UNDER_CONSIDERATION → REMANDED_TO_GS   (Rule 12A(6): sent back, NOT rejected)
  SDLC_UNDER_EXAM / DLC_UNDER_CONSIDERATION → MODIFIED_REJECTED → PETITION_FILED → back to SDLC/DLC
```

| State | Owner | Meaning | Allowed next states |
|---|---|---|---|
| `DRAFT` | Facilitator / FRC | Case created; nothing legal has happened yet | `EVIDENCE_COLLECTION` |
| `EVIDENCE_COLLECTION` | FRC | Acknowledgement issued; evidence ledger open | `MAPPING_IN_PROGRESS` |
| `MAPPING_IN_PROGRESS` | FRC + elders | Boundary walk and use-zone capture | `FRC_VERIFICATION`, `DISPUTE_JOINT_HEARING` |
| `DISPUTE_JOINT_HEARING` | FRCs concerned | Overlap with a neighbouring Gram Sabha [Rule 12(3)] | `MAPPING_IN_PROGRESS` (resolved or referred to SDLC) |
| `FRC_VERIFICATION` | FRC + departments | Site visit and verification sheet | `GS_READY` |
| `GS_READY` | FRC | Findings and map ready for the Gram Sabha | `GS_RESOLVED` |
| `GS_RESOLVED` | GS Secretary | Resolution passed with quorum proof | `SUBMITTED_SDLC` |
| `SUBMITTED_SDLC` | FRC | Packet delivered; SDLC acknowledgement scanned | `SDLC_UNDER_EXAM` |
| `SDLC_UNDER_EXAM` | *(SDLC, via uploaded order)* | Under examination | `SDLC_FORWARDED`, `REMANDED_TO_GS`, `MODIFIED_REJECTED` |
| `SDLC_FORWARDED` | *(SDO, via uploaded order)* | Draft record forwarded to the DLC | `DLC_UNDER_CONSIDERATION` |
| `DLC_UNDER_CONSIDERATION` | *(DLC, via uploaded order)* | Final approval pending | `TITLE_APPROVED`, `REMANDED_TO_GS`, `MODIFIED_REJECTED` |
| `REMANDED_TO_GS` | FRC | Sent back for re-verification (not a rejection) | `FRC_VERIFICATION` |
| `MODIFIED_REJECTED` | *(SDLC/DLC order)* | Adverse order; 60-day clock running from personal communication | `PETITION_FILED` |
| `PETITION_FILED` | FRC / Gram Sabha | Petition under Rule 14 or 15 | `SDLC_UNDER_EXAM`, `DLC_UNDER_CONSIDERATION` |
| `TITLE_APPROVED` | *(DLC, Annexure IV uploaded)* | Title issued | `RECORD_UPDATED`, `SURVEY_PENDING` |
| `SURVEY_PENDING` | Land records | Title exists, measurement does not | `RECORD_UPDATED` |
| `RECORD_UPDATED` | *(Revenue + Forest, entry uploaded)* | Right entered in government records | `CFR_ACTIVE` |
| `CFR_ACTIVE` | Gram Sabha | Management phase; this module hands over | — (end of this module) |

States marked *(… via uploaded order)* are **never set by a button press**. They change only when an FRC member uploads the authority's order, acknowledgement or entry, together with its date.

### 4.3 Hard blocks and advisories

**Only these block the workflow.** Everything else is advice.

| ID | Rule | Type |
|---|---|---|
| BR-01 | An FRC needs 10–15 members, at least ⅔ Scheduled Tribes and at least ⅓ women (⅓ women only, if there are no STs) [Rule 3(1)] | Hard block |
| BR-02 | An FRC member who is a claimant cannot sign that case's verification [Rule 3(3)] | Hard block, with a recusal record |
| BR-03 | A resolution cannot be recorded unless all three quorum tests pass [Rule 4(2)] | Hard block |
| BR-04 | A case cannot be submitted without a linked resolution and a Gram Sabha-approved boundary [Sec 6(1), Rule 12(1)(g)] | Hard block |
| BR-05 | Fewer than 2 verified Rule 13(1) evidence items shows the case as *incomplete*, but does not block it | Advisory |
| BR-06 | Satellite or GPS items alone cannot meet the two-evidence test [Rule 12A(11)] | Engine rule |
| BR-07 | Field verification cannot close without departmental signatures or a recorded absence with an intimation reference [Rule 12A(1)(2)] | Hard block |
| BR-08 | Every boundary segment needs at least one landmark before the map sheet is generated [Rule 12(1)(g)] | Hard block (map document) |
| BR-09 | An overlap with a neighbouring polygon forces the dispute state until a joint-meeting record or an SDLC referral exists [Rule 12(3)] | Hard block |
| BR-10 | The limitation clock starts from the date of *communication in person*, never from the order date [Rule 12A(3)] | Data rule |
| BR-11 | A remand is stored as a remand, never as a rejection [Rule 12A(6)] | State rule |
| BR-12 | Every adverse order records whether written reasons were given; if not, that is flagged as an appeal ground [Rule 12A(7)(10)] | Data rule |
| BR-13 | A case cannot close without the certified title copy and the record-incorporation entry [Rule 8(i), 12A(9)] | Hard block |
| BR-14 | No role can set a claim outcome [Rule R1] | Access-control rule |
| BR-15 | A signed record is immutable; corrections create a superseding record with a reason | Integrity rule |

**Quorum, the three tests [Rule 4(2)]:** (1) at least half of all Gram Sabha members present; (2) at least one-third of those present are women; (3) at least 50% of claimants or their representatives present. A resolution passes by simple majority of those present and voting.

**Documentation completeness, the ten checks (Spec §4.6):**

| Check | Test | Rule |
|---|---|---|
| C-1 | At least 2 verified general evidence items (13(1)) | 11(1)(a), 13(3) |
| C-2 | At least 1 verified community-forest evidence item (13(2)) | 13(2) |
| C-3 | Boundary approved by the Gram Sabha | 12(1)(g) |
| C-4 | At least 1 landmark on every boundary segment | 12(1)(g) |
| C-5 | Verification sheet signed by, or absence recorded for, **both** Forest and Revenue | 12A(1)(2) |
| C-6 | A signed elder statement, **or** at least 3 items under 13(1) | 13(1)(i) |
| C-7 | Quorum test passed | 4(2) |
| C-8 | Intimation sent to every adjoining Gram Sabha | 11(1)(b) |
| C-9 | Acknowledgement issued | 11(3) |
| C-10 | No unresolved overlap, or a joint-meeting record exists | 12(3) |

### 4.4 Legal clocks the app runs

| Clock | Length | Starts from | Alerts |
|---|---|---|---|
| Claim filing window [Rule 11(1)(a)] | 3 months (extendable, with written reason and resolution) | Date claims were called | Countdown on the dashboard |
| Petition against a Gram Sabha resolution [Sec 6(2), Rule 14(1)] | 60 days | Resolution date | Shown to the Gram Sabha |
| Petition against an SDLC decision [Sec 6(4), Rule 15(1)] | 60 days | SDLC decision date | Day 30, 45, 55, 58; petition drafted automatically |
| Petition after modification or rejection [Rule 12A(3)] | 60 days (+30 at the committee's discretion) | **Date of communication in person** | Day 30, 45, 55, 58 |
| Hearing notice [Rules 14(2), 15(2)] | At least 15 days before the hearing | Hearing date | Shorter notice is flagged |
| Gram Sabha meeting on a reference back [Rule 14(4)] | Within 30 days | Receipt of the reference | Reminders |
| Inter-Gram Sabha dispute [Rule 14(7)] | 30 days | Joint meeting called | After 30 days, the SDLC decides |
| Record updation after title [Rule 12A(9)] | 3 months or the state cycle, whichever is earlier | Title issue date | Open item until the entry is uploaded |

### 4.5 Documents the app generates (G-series)

Every document is print-ready in **Marathi, Hindi and English**, with a signature or thumb-impression block. The signed paper is scanned back in and hash-sealed.

| Code | Document | Rule | Built in stage |
|---|---|---|---|
| G1 | Notice calling for claims and fixing the CFR date | 11(1)(a)(b) | 2 |
| G2 | Intimation to adjoining Gram Sabhas and the SDLC | 11(1)(b) | 2 |
| G3 | FRC constitution certificate | 3(1)(2) | 1 |
| G4 | Claim acknowledgement receipt | 11(3) | 2 |
| G5 | Request to the SDLC for maps and electoral rolls | 6(b) | 2 |
| G6 | Request for authenticated copies of records | 12(4) | 2 |
| G7 | Intimation of the site visit | 12(1) | 4 |
| G8 | Field verification proceeding sheet | 12(1)(a)–(e), 12A(1) | 4 |
| G9 | Boundary delineation record (named elders) | 12(1)(f) | 3 |
| G10 | CFR map sheet | 12(1)(g) | 3 |
| G11 | Gram Sabha meeting notice and agenda | 4, 11(5) | 4 |
| G12 | Attendance and quorum sheet | 4(2) | 4 |
| G13 | Gram Sabha resolution | Sec 6(1); 12(1)(g) | 4 |
| G14 | FRC findings report | 12(2) | 4 |
| G15 | Submission covering letter and page-numbered index | 11(5) | 5 |
| G16 | Petition to the SDLC or DLC | 14, 15; 12A(3) | 5 |
| G17 | Joint meeting record for conflicting claims | 12(3); 14(7) | 3 |
| G18 | Survey and measurement request | supports 12A(9) | 5 |
| G19 | Section 8 notice to the SLMC | Sec 8 | Later |
| G20 | Complete case file export (one PDF) | Facilitation | 5 |
| — | **Form C** with the member sheet and evidence schedule | 11(1), 11(4) | 2 (draft) → 5 (final) |

---

## 5. Requirements

### 5.1 Functional requirements

| ID | Requirement | Stage |
|---|---|---|
| FR-01 | Login for the three roles, scoped to one village | 0 |
| FR-02 | Village and hamlet registry (LGD code, Gram Panchayat, taluka, district, hamlet hierarchy) [Rule 2A] | 1 |
| FR-03 | Gram Sabha member roster with gender and ST/OTFD category; used by FRC composition, quorum and the Form C member sheet | 1 |
| FR-04 | FRC constitution with the BR-01 check and conflict-of-interest flags | 1 |
| FR-05 | Create a CFR case; claim window timer with a formal extension | 2 |
| FR-06 | Acknowledgement receipt with a serial number | 2 |
| FR-07 | Evidence ledger: every item tagged with its Rule 13 sub-clause; photo, scan, GPS and audio capture; offline | 2 |
| FR-08 | Elder statements: audio → transcript → printed → signed scan; blocked if the elder is a claimant | 2 |
| FR-09 | Documentation completeness check (10 checks, in the local language) | 2 → 4 |
| FR-10 | Outgoing letters (G2, G5, G6, G18) tracked with dispatch date and reminders | 2 |
| FR-11 | Boundary walk (GPS trace plus waypoints), landmarks per segment, use zones, versioned polygons | 3 |
| FR-12 | Overlap detection with neighbouring villages → dispute state → joint meeting record | 3 |
| FR-13 | Field verification: intimation, presence register, department signature blocks or recorded absence | 4 |
| FR-14 | Gram Sabha meeting, attendance, live three-test quorum, resolution | 4 |
| FR-15 | Submission packet (Form C + annexures + index) and SDLC acknowledgement upload | 5 |
| FR-16 | Recording authority orders (with order date **and** communication date); legal clocks; petition draft | 5 |
| FR-17 | Remand re-verification checklist; title upload; survey pending; record incorporation | 5 |
| FR-18 | Hash-chained, append-only records with a "verify integrity" function | 2 → 5 |
| FR-19 | Offline-first sync, with conflicts on signed records sent to a person instead of being overwritten | 2 → 6 |
| FR-20 | Consent capture per person and per sharing event | 6 |

### 5.2 Non-functional requirements

| Area | Requirement |
|---|---|
| Offline | Every claim-critical action works with no network for weeks |
| Device | Works on a 2 GB RAM Android phone with a 720p screen on 2G or patchy 4G; battery-friendly GPS sampling |
| Language | Marathi (primary), Hindi and English; every string in a translation file, no hard-coded text |
| Simplicity | Icon-led navigation, large tap targets, large-text and high-contrast modes, audio guidance planned |
| Performance | Case list and completeness check under 300 ms on the device; overlap check under 2 s; document generation under 10 s (in the background) |
| Security | TLS in transit; encrypted storage on the device and server; role + village scoping enforced on the server; no role can delete a record |
| Privacy | Consent-scoped personal data; masked identity numbers in exports; exact boundaries and sacred sites never public (DPDP Act, 2023) |
| Integrity | SHA-256 hash chain per Gram Sabha; corrections never overwrite |
| Audit | Every state change and every read of personal data is logged with actor, time and purpose |
| Availability | No data loss is acceptable; server target 99% during working hours |

---

## 6. Technology

| Layer | We use | Notes |
|---|---|---|
| Mobile app | **Flutter 3.x** (Dart), **Riverpod** | Existing app in `vanmitra_tem/` |
| On-device storage | **Hive** (cache + offline outbox), encrypted | Existing |
| Maps | **flutter_map** with offline tiles | Existing; MapLibre only if vector tiles are needed |
| Backend API | **FastAPI** on **Python 3.12**, Pydantic v2 | Existing service in `vanmitra_backend/`, extended |
| Database | **PostgreSQL 16 + PostGIS 3.4** | **New.** Needed for overlap detection, area in hectares and transactional records |
| Migrations / ORM | **SQLAlchemy 2 + Alembic** | New |
| Background jobs | FastAPI background tasks (pilot) → Celery + Redis if needed | For OCR, PDFs and speech-to-text |
| Documents (PDF) | **WeasyPrint** HTML templates + Noto Sans Devanagari | Templates are easy to adjust to district practice |
| File storage | Local disk in development → **MinIO** (S3 API) in pilot | Scans, photos and audio |
| Auth | **JWT** issued by the backend; phone + PIN for the pilot | Keycloak/OTP later |
| OCR / speech | Tesseract 5 (eng + mar + hin) / Whisper | Metadata only; the scan is the evidence |
| Push notifications | Firebase Cloud Messaging | Only for deadline alerts |
| Local dev | **Docker Compose** (API + Postgres/PostGIS) | Docker Desktop is installed |
| CI | GitHub Actions: lint, tests, APK build | Stage 0 |

**Decision D2, decided 2026-09-28: the database is PostgreSQL + PostGIS.** The FastAPI + PostgreSQL 16 / PostGIS 3.4 backend is the **system of record** for the claim module. Hive stays as the on-device offline store and outbox. Firebase is kept **only** for push notifications (FCM), plus the existing non-claim features (such as the notice board) until they are migrated. The app stops writing claim data to Firestore.

*Why:* the Spec needs PostGIS overlap and area checks, hard rules enforced on the server, and an append-only hash-chained ledger with database-level protection against updates and deletes. Firestore cannot do these well.

---

## 7. How we build it: stages

Backend and frontend run **in parallel** in every stage. The backend publishes the API for a stage first, as an OpenAPI draft with example responses, so the frontend can build against a mock and never has to wait.

| Stage | Goal | Backend (Soham, Ishan) | Frontend (Kaushal, Ishan) | Exit test (stage is done when…) |
|---|---|---|---|---|
| **0: Foundations** | Everyone on the same base | Project structure, Docker Compose with PostGIS, DB migrations, JWT auth, 3 roles, `/health`, OpenAPI published, CI | Reduce 12 roles to 3; remove decision buttons and score gauges; API client + mock server; theme and translation setup | The app logs in against the new backend with each of the 3 roles |
| **1: Village and FRC** | Stages 0–1 of the claim | Village/hamlet, Gram Sabha, members, FRC with BR-01/BR-02, G3 | Village setup, member roster, FRC screen with a live composition check, print G3 | A valid FRC is saved and an invalid one is refused, with the reason shown |
| **2: Case and evidence** | Stages 2–4 | Case + claim window, acknowledgement, evidence ledger with Rule 13 tags, hash chain, completeness checks C-1/C-2/C-6/C-9, letters G1/G2/G4/G5/G6, sync endpoint | Case creation, evidence capture (camera, scan, GPS, audio) **offline**, completeness checklist, outbox sync | A full evidence bundle is captured offline for one village and synced without loss |
| **3: Mapping** | Stages 5–6 | Boundary versions, landmarks, segments, use zones, PostGIS overlap → dispute, G9/G10/G17 | Boundary walk screen, landmark capture, use-zone drawing, dispute screen, offline map tiles | A boundary is walked, mapped and printed at a scale the Gram Sabha can read |
| **4: Verification and Gram Sabha** | Stages 7–9 | Verification + BR-07, meetings, attendance, 3-test quorum (BR-03), resolution, G7/G8/G11–G14, all 10 checks | Verification sheet flow, meeting and attendance screens, live quorum panel, resolution recording | A Gram Sabha meeting is recorded end to end with a correct quorum calculation |
| **5: Submit and track** | Stages 10–13 | Submission (BR-04), order recording, legal clocks + alerts, remand, petition G16, title, survey G18, record (BR-13), G15/G20 | Submission packet, "Record an order" flow, deadline timeline, petition preview, title upload | A simulated rejection produces a correct petition draft within the limitation period |
| **6: Hardening and pilot** | Ready for real use | Consent, audit logs, backups, security review, golden-file tests for every document | Marathi review with the NGO, accessibility pass, low-end device testing, crash reporting | One village's claim goes from calling of claims to submission, and the SDLC office accepts the packet without procedural objection |
| **7: Later** | After the pilot | CFRMC module, Annexure V quarterly report, coverage dashboard, G19, authority read-only link, legal Q&A assistant, satellite alerts | Matching screens | Separate plan |

Target dates are filled in by the team at the start of each stage:

| Stage | Start | Target end | Actual end |
|---|---|---|---|
| 0 | | | |
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
| 6 | | | |

---

## 8. How we work together

### 8.1 Ownership

| Area | Owner | Support | Reviewer |
|---|---|---|---|
| Backend: API, database, workflow engine, documents | **Soham** | Ishan | Ishan |
| Frontend: Flutter screens, offline sync, UX | **Kaushal** | Ishan | Ishan |
| API contract (`docs/API.md` / OpenAPI) | Soham | Kaushal | Both leads |
| This plan and the rules | Whole team | — | Whole team |

### 8.2 Git process

1. `main` is protected. **No direct pushes.**
2. Branch names: `be/<short-topic>` for backend, `fe/<short-topic>` for frontend, `docs/<topic>` for documents. Example: `be/frc-composition`.
3. One pull request per feature. Keep it small. Link the stage and the rule, for example *"Stage 1 · BR-01 · Rule 3(1)"*.
4. At least **one review** from someone else before merging.
5. Commit messages: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`, e.g. `feat(frc): block FRC with fewer than 1/3 women`.
6. **Never commit** secrets, `google-services.json`, service-account keys, `.env` files or personal data. Machine-specific paths must not be committed either (for example, a Gradle wrapper pointing at `D:\…`).

### 8.3 API contract process

- The backend owns the contract. Any change to a request or response goes into the OpenAPI/`docs/API.md` **first**, in a PR labelled `api-change`.
- The frontend lead approves `api-change` PRs.
- Breaking changes need a version bump (`/api/v1` → `/api/v2`) or a migration note.

### 8.4 Definition of done (every PR)

- [ ] Traces to a stage and a rule (or is labelled *facilitation*)
- [ ] Breaks none of the ten rules in §2 (no scores, no decision buttons, no silent overwrite)
- [ ] Tests added: unit tests for rules; golden-file tests for documents
- [ ] All user-facing text in the translation files (mr, hi, en)
- [ ] Works offline, if it is a field action
- [ ] Reviewed and CI green

### 8.5 Weekly rhythm

- **Start of the week:** agree the week's tasks from the current stage.
- **Mid-week:** a 15-minute sync on API changes and blockers.
- **End of the week:** demo on a real phone and update the stage table.

---

## 9. Open decisions

Backend-specific decisions (B-01 to B-22, including the Stage 0 blockers) are tracked in [`BACKEND_PLAN.md` §8](BACKEND_PLAN.md#8-backend-decisions).

| # | Decision | Recommendation | Decided |
|---|---|---|---|
| D1 | The three app roles in §3 | Facilitator, FRC Member, Gram Sabha Secretary | ☐ |
| D2 | System of record: Firestore or PostgreSQL | PostgreSQL + PostGIS; Firebase for push only | ☑ **Decided 2026-09-28 (Soham):** PostgreSQL 16 + PostGIS 3.4 |
| D3 | Login method for the pilot | Phone number + PIN (OTP needs a paid SMS provider) | ☐ |
| D4 | Hosting for the pilot | One small Indian-region VM with Docker Compose (Railway for development only) | ☐ |
| D5 | Keep face-recognition attendance? | Keep it as an optional *facilitation* feature; manual attendance is the legal record | ☐ |
| D6 | What happens to the existing AI features (eligibility check, evidence scoring)? | Remove "eligibility" and "score" (rules R1/R2); keep OCR, drafting and appeal help as removable assistants | ☐ |

---

## 10. Glossary

| Term | Meaning |
|---|---|
| **CFR** | Community Forest Resource: the customary common forest of the village [Sec 2(a), 3(1)(i)] |
| **Form C** | The claim form for CFR rights [Rule 11(1), 11(4)] |
| **Gram Sabha (GS)** | All adult members of the village; the legal owner of the claim |
| **FRC** | Forest Rights Committee, 10–15 members elected by the Gram Sabha [Rule 3] |
| **SDLC / DLC / SLMC** | Sub-Divisional, District and State Level committees [Sec 6; Rules 5, 7, 9] |
| **Annexure IV** | The CFR title, signed by the DFO, the District Tribal Welfare Officer and the Collector [Rule 8(i)] |
| **Remand** | The claim is sent back to the Gram Sabha for re-verification; this is **not** a rejection [Rule 12A(6)] |
| **Rule 13 evidence** | 13(1)(a)–(i): general evidence; 13(2)(a)–(e): CFR-specific evidence |
| **OTFD** | Other Traditional Forest Dweller |
| **Nistar** | Customary community rights of use |
