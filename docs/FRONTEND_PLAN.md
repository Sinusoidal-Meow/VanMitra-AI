# VanMitra — Frontend Plan (CFR Claim Module)

> **Owner:** Kaushal · **Support and review:** Ishan · **Status:** v0.1 draft
> Read [`PROJECT_PLAN.md`](PROJECT_PLAN.md) first. This document never overrides it.

The app is used in the field by an NGO worker, FRC members and the Gram Sabha Secretary, often with no network, in bright sunlight, on a cheap phone. It has to look **professional enough for a government partner** and be **simple enough for a first-time smartphone user**.

---

## 1. Where we start from

The existing Flutter app is in `vanmitra_tem/` (Flutter 3.x, Riverpod, Hive, Firebase). What changes:

| Existing | Action | Why |
|---|---|---|
| 12 roles in `lib/models/user_role.dart` | **Reduce to 3**: `facilitator`, `frcMember`, `gsSecretary` | PROJECT_PLAN §3 |
| `ClaimStatus` enum (25 states) in `lib/models/claim.dart` | **Replace** with the 18 states in PROJECT_PLAN §4.2 | Must match the backend exactly |
| CFR stages in `cfr_workflow_service.dart` | Rework: the order becomes verification → findings → resolution; transitions call the backend | Rule 12(1), 12(2), 12(1)(g) |
| Role dashboards for SDLC/DLC/DFO/Collector/SLMC (`screens/cfr/dashboards/`) | **Remove.** Replace with a "Record an order received" flow | Rule R1: the app never decides |
| In-app Annexure IV signing (`signature_service.dart`) | **Remove** officer signing; replace with "upload signed title" | Rule R1, R4 |
| `evidence_strength_gauge.dart`, any "score" / "eligible" text | **Remove.** Replace with the "Documentation completeness: X of 10" checklist | Rule R2 |
| "Form B" in the CFR create screen | **Change to Form C** | Rule 11(4) |
| Direct Firestore writes for claims | Replace with calls to the backend API + the Hive outbox | PROJECT_PLAN §6, D2 (**decided:** PostgreSQL + PostGIS is the system of record) |
| Face-recognition attendance, notice board, Module B map | Keep; label face recognition as *facilitation*; manual attendance is the legal record | D5 |

---

## 2. App structure

```
lib/
├── core/
│   ├── api/            # generated/handwritten API client, error mapping (rule → message)
│   ├── sync/           # Hive outbox, sync worker, conflict inbox
│   ├── storage/        # encrypted Hive boxes
│   ├── l10n/           # ARB files: app_mr.arb, app_hi.arb, app_en.arb
│   └── theme/          # colours, text sizes, large-text / high-contrast modes
├── features/
│   ├── auth/           # login (phone + PIN), role/village picker
│   ├── village/        # Step 1: village profile, members, FRC
│   ├── claim_call/     # Step 2: notice, intimations, acknowledgement
│   ├── evidence/       # Step 3a: capture, tag, verify, elder statements
│   ├── mapping/        # Step 3b: boundary walk, landmarks, use zones, disputes
│   ├── verification/   # Step 4: field verification sheet
│   ├── gram_sabha/     # Step 5: meetings, attendance, quorum, resolution
│   ├── tracking/       # Step 6: submission, orders, clocks, petitions, title
│   ├── documents/      # preview / print / share / scan signed copy back
│   └── case_home/      # the case dashboard (6-step progress + completeness)
└── shared/widgets/     # StepCard, ChecklistItem, RuleChip, DeadlineBanner, SignatureBlockNote…
```

Each feature keeps the same pattern: `data/` (API + Hive), `providers/` (Riverpod), `screens/`, `widgets/`.

---

## 3. Screens by role

| Screen | Facilitator | FRC Member | GS Secretary |
|---|:---:|:---:|:---:|
| Login, choose village | ✅ | ✅ | ✅ |
| Case home (6 steps + completeness) | ✅ | ✅ | ✅ |
| Village profile / hamlets | ✏️ | 👁️ | 👁️ |
| Member roster | 👁️ | 👁️ | ✏️ |
| FRC constitution | 👁️ | 👁️ | ✏️ |
| Call for claims, acknowledgement | draft | ✏️ | ✏️ (extension) |
| Evidence capture | ✏️ | ✏️ | — |
| Verify evidence (attest) | — | ✏️ (not if claimant) | — |
| Boundary walk, landmarks, use zones | ✏️ | ✏️ | 👁️ |
| Field verification sheet | — | ✏️ (not if claimant) | — |
| Meeting, attendance, quorum, resolution | 👁️ | 👁️ | ✏️ |
| Submit packet | — | ✏️ | — |
| Record an order received | — | ✏️ | — |
| Deadlines, petitions | 👁️ | ✏️ | 👁️ |
| Documents (print / scan back) | ✏️ | ✏️ | ✏️ |

✏️ = can act · 👁️ = view only · — = hidden

---

## 4. UX rules (non-negotiable)

1. **One thing per screen.** One main button, at the bottom, full width.
2. **The case home is always a 6-step progress list** (PROJECT_PLAN §4.1). The current step is highlighted; finished steps show a tick and a date.
3. **Completeness, never a score.** Show *"Documentation completeness: 8 of 10"*, then the list of missing items. Each item has a one-line instruction and a small rule chip, e.g. `Rule 12(1)(g)`. No percentages, gauges, stars or colours that suggest pass or fail.
4. **Blocked actions explain themselves.** When the server returns a rule error, show in plain Marathi *what* is missing and *how* to fix it, e.g. *"FRC needs at least 4 women. Now: 3."* Never show a raw error code.
5. **Deadlines are loud.** A countdown banner appears on the case home whenever a legal clock is running, and it turns stronger at days 30, 45, 55 and 58.
6. **Orders are uploaded, never decided.** The "Record an order" flow asks for: the scan, the order date, **the date it was told to the claimant in person**, whether reasons were given, and the grounds. There are no Approve or Reject buttons anywhere.
7. **Paper first.** Every legal step ends with "Print → sign → scan the signed copy". The step is not complete until the signed scan is attached.
8. **Offline is normal.** Show a small sync indicator (✓ synced / ⏳ waiting / ⚠ needs attention), not blocking dialogs. Every field action works offline.
9. **Accessible outdoors.** Minimum tap target 48 dp (prefer 56); body text at least 16 sp; large-text and high-contrast modes; icons always come with text.
10. **Language.** Marathi is the default. Every string lives in ARB files, with no hard-coded text. Numbers and dates are shown in the local format.
11. **Label facilitation features.** Things with no legal basis (face attendance, AI transcription) carry a small "Helper" tag.
12. **Disclaimer** on every document preview: *"Community record prepared with VanMitra. Not a government document."*

### Visual style
- Keep the existing VanMitra header (वनमित्र | VanMitra) and the saffron/green accent line.
- Neutral, calm backgrounds. Colour is only for status: green = done, amber = needs attention, red = a deadline or an adverse order. Never use red for "incomplete".
- Use Noto Sans Devanagari for all text.

---

## 5. Offline and sync

- Every create or edit writes to Hive **first**, then goes into the **outbox** with a UUIDv7 ID and an idempotency key.
- The sync worker drains the outbox to `POST /api/v1/sync/batch` when online. It retries with backoff and never drops items.
- Media uploads are **chunked and resumable** with a checksum, so a dropped 2G connection doesn't lose a scan.
- **Conflict inbox:** if the server reports a conflict on a signed record, show it to the user in a "Needs attention" list. Never overwrite automatically.
- Encrypted Hive boxes, with the key kept in Android Keystore (`flutter_secure_storage`).
- After a successful sync and verification, identity-document images are removed from the device.
- Map tiles for the district are downloaded before a field visit (offline tile pack).

---

## 6. Capture details

| Capture | Must record |
|---|---|
| Photo (13(1)(c), 13(2)(c)) | GPS, accuracy (m), bearing, time, short description, Rule 13 tag |
| Document scan (13(1)(a),(b),(d),(f)) | Edge detection/deskew, issuing office, reference no., date, Rule 13 tag; OCR fills fields as a *suggestion* |
| Elder statement (13(1)(i)) | Audio → transcript (Helper) → edit → print → read back → sign/thumb → scan. Blocked if the elder is a claimant |
| Boundary walk | GPS trace with **accuracy per point**; points worse than the threshold are drawn differently; named elders present |
| Landmark | Name, photo, point, which segment; at least one per segment (BR-08) |
| Use zone (13(2)(b)) | Type, polygon or points, season, which hamlets use it |

---

## 7. Testing

| Kind | What |
|---|---|
| Unit | Providers, the outbox, error-to-message mapping, the quorum display maths (mirrors the server) |
| Widget | Every step screen, including blocked and empty states, in mr/hi/en |
| Integration (`integration_test/`) | **Offline path:** airplane mode → capture a full evidence set → reconnect → everything synced |
| Devices | One low-end Android phone (2 GB RAM) + the emulator, every stage demo |
| Golden screenshots | Case home and completeness list in Marathi |

---

## 8. Stage checklists

### Stage 0: Foundations
- [ ] Reduce roles to 3; remove the SDLC/DLC/DFO/Collector/SLMC dashboards
- [ ] Remove score gauges and "eligible" wording
- [ ] API client + mock server (from the backend's OpenAPI examples)
- [ ] Login (phone + PIN) → village picker → case home shell
- [ ] ARB files for mr/hi/en; theme with large-text mode
- [ ] Fix the Gradle wrapper URL (it points at `D:\gradle-8.14-all.zip`); keep `google-services.json` out of git

### Stage 1: Village and FRC
- [ ] Village profile + hamlets
- [ ] Member roster (gender, ST/OTFD)
- [ ] FRC constitution with a **live** composition check (the server's `/frc/check`)
- [ ] Print G3 → scan the signed copy

### Stage 2: Case and evidence
- [ ] Create case (Form C); claim window countdown
- [ ] Acknowledgement receipt
- [ ] Evidence capture (photo, scan, GPS, audio) with Rule 13 tagging, **offline**
- [ ] FRC "verify" action with recusal
- [ ] Completeness checklist
- [ ] Outbox + sync indicator + conflict inbox
- [ ] Letters G1/G2/G5/G6: preview, print, mark dispatched

### Stage 3: Mapping
- [ ] Offline tile pack download
- [ ] Boundary walk (trace + waypoints + accuracy)
- [ ] Landmarks per segment; use zones
- [ ] Overlap warning → dispute screen → joint meeting record
- [ ] G9/G10 preview

### Stage 4: Verification and Gram Sabha
- [ ] Site-visit intimation (G7); verification sheet (G8) with signature/absence per department
- [ ] Meeting creation + notice (G11)
- [ ] Attendance (manual; face as a Helper) + **live 3-test quorum panel**
- [ ] Resolution recording (blocked if quorum fails) + G12/G13/G14

### Stage 5: Submit and track
- [ ] Submission packet preview (G15 index) + upload the SDLC acknowledgement
- [ ] "Record an order received" flow (with the communication date)
- [ ] Timeline + deadline banners + push alerts
- [ ] Petition (G16) preview; remand checklist
- [ ] Title upload; survey pending; record entry; case closed

### Stage 6: Hardening
- [ ] Marathi review with the NGO (every screen, every document)
- [ ] Accessibility pass (tap targets, contrast, text scale 200%)
- [ ] Low-end device performance (case home under 300 ms)
- [ ] Crash reporting; release signing; Play Store internal track
