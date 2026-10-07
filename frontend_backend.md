# VanMitra — Complete Frontend & Backend Integration Blueprint (`frontend_backend.md`)

> **Target Audience:** Kaushal (Frontend Lead)  
> **Repository Branch:** `kaushal-dev` (Frontend) & `soham_backend` (Backend)  
> **Backend Stack:** FastAPI · MongoDB Atlas (Replica Set) · PyMongo Store · Shapely 2.0 & PyProj (EPSG:32643 UTM 43N) · JWT Authentication  
> **Frontend Stack:** Flutter 3.x · Riverpod · Hive (Offline Storage) · HTTP Client  
> **Purpose:** Exhaustive, step-by-step implementation guide detailing **what is happening in the backend**, **what needs to be built in the frontend**, **where in `vanmitra_tem/lib/` to build it**, and **the statutory FRA legal rules** guiding every screen.

---

## 1. Quick Start & Connection Setup

### 1.1 Backend Connectivity
The backend runs FastAPI on port `8010` (or `8000`).

- **Physical Android Tablet / Phone over USB:**
  ```bash
  adb reverse tcp:8010 tcp:8010
  ```
  Base URL in Flutter: `http://127.0.0.1:8010/api/v1`
- **Android Emulator:**
  Base URL in Flutter: `http://10.0.2.2:8010/api/v1`
- **Wi-Fi / LAN (Real Tablet without USB cable):**
  Find your backend PC's local IP (e.g., `192.168.1.5`): `http://192.168.1.5:8010/api/v1`
- **Flutter Run Parameter:**
  ```bash
  flutter run --dart-define=VANMITRA_API_BASE_URL=http://127.0.0.1:8010
  ```
- **Health Check Endpoint:**
  `GET /api/v1/health` → `{"status": "ok", "database": "ok", "version": "1.0.0"}`

### 1.2 Development Demo Logins (All PINs: `123456`)
These accounts are pre-seeded in the database for instant testing:
| Phone | Name | Role | Access Level | Jurisdiction |
|---|---|---|---|---|
| `9000000001` | Demo Village User | `villager` | Level 1 (Villager) | Ozhar village |
| `9000000002` | Demo Village User 2 | `villager` | Level 1 (Villager) | Ozhar village |
| `9000000003` | Demo Gram Sabha (Ozhar) | `gram_sabha` | Level 2 (Gram Sabha) | Ozhar village |
| `9000000004` | Demo Admin (back-office) | `admin` | Admin | System management only |
| `9000000005` | Demo SDO (Jawhar) | `sdo` | Level 3 (Sub-Division) | Jawhar taluka (Palghar) |

### 1.3 Uniform API Error Response Structure
Every endpoint returns errors in the exact same schema. If status is `409`, it is a **statutory legal violation** under FRA Rules:
```json
{
  "error": "FRC_TOO_FEW_WOMEN",
  "message_key": "frc.too_few_women",
  "rule": "Rule 3(1)",
  "details": { "women_count": 3, "required": 4 }
}
```
> **UI Rule:** Always display the plain-language message (e.g. Marathi or English) and render a small chip showing the rule badge: `[Rule 3(1)]`. Never show a raw crash or empty alert.

---

## 2. Core Philosophy & Non-Negotiable UX Principles

1. **The System Records and Checks; People Decide:**
   - There are **no AI eligibility scores**, no "approval probability gauges", and no automatic passes or rejections.
   - Completeness is shown strictly as a documentation checklist: e.g. *"Documentation Completeness: 7 of 10 items recorded"*, followed by the exact missing items with statutory rule references.
2. **One Primary Action Per Screen:**
   - Big, full-width button at the bottom of the screen (min height 48–56 dp) for primary actions.
3. **Paper-First & Signed Scans:**
   - Every major legal milestone (Call for claims, Elder statement, Joint inspection, Meeting resolution) ends with: **Print/Generate Document → Physical Signatures/Thumbprints → Upload Signed Scan**.
   - An action is only marked complete once the signed scan is uploaded.
4. **Resubmission Window is Loud:**
   - When a claim is returned by the Gram Sabha or SDO, the villager has **60 days** to correct and resubmit. A prominent deadline banner must show the days remaining (`days_left`).
5. **Dynamic Button Rendering (`allowed_actions`):**
   - The backend sends an `allowed_actions` array on every case response (`["submit"]`, `["approve", "return", "reject"]`, etc.).
   - The frontend must only show action buttons present in this array!

---

## 3. Architecture & Target Directory Structure

Build your features inside `vanmitra_tem/lib/` using this clean feature-based layout:

```
vanmitra_tem/lib/
├── core/
│   ├── api/
│   │   ├── api_client.dart          # Base HTTP client with Bearer token injector & error handling
│   │   └── api_endpoints.dart       # String constants for all URLs
│   ├── auth/
│   │   ├── auth_state.dart          # Riverpod state: token, current user, active role
│   │   └── auth_storage.dart        # Encrypted Hive token storage
│   ├── models/                      # Shared models (CaseOut, Village, etc.)
│   └── theme/                       # Noto Sans Devanagari typography, contrast tokens
├── features/
│   ├── auth/                        # Login & Villager Self-Registration
│   ├── case_hub/                    # My Claims, Review Queue, Stepper Dashboard
│   ├── form_a/                      # IFR (Individual Forest Rights) Claim
│   ├── form_b/                      # CR (Community Rights) Claim
│   ├── form_c/                      # CFR (Community Forest Resource) & Members
│   ├── frc/                         # Forest Rights Committee Constitution & Intimation
│   ├── claim_call/                  # 3-Month Window, Extension & Acknowledgement Slip
│   ├── evidence/                    # Rule 13 Media Capture, Elder Audio, Verifications
│   ├── mapping/                     # GPS Walk, Boundary Segments, Landmarks, Use Zones, Disputes
│   ├── verification/                # Joint Field Inspection (Revenue + Forest)
│   ├── gram_sabha/                  # Meeting Setup, Attendance, Quorum Engine, Resolution
│   ├── workflow/                    # Approve, Return (Remarks), Reject Dialogs
│   └── documents/                   # Printable HTML Previews (Annexures, G-Series)
└── shared/widgets/
    ├── step_card.dart               # 6-step progress card
    ├── completeness_widget.dart     # Advisory checklist with Rule tags
    ├── deadline_banner.dart         # 60-day return countdown banner
    └── rule_badge.dart              # Chips like [Rule 3(1)], [Rule 12(1)(g)]
```

---

## 4. Module Breakdown & What Kaushal Needs to Build

---

### Module 0: Authentication, Registration & Jurisdiction (`lib/features/auth/`)

#### Backend Mechanics
- Passwords are 6-digit numeric PINs hashed with BCrypt.
- Standard JWT access token (`access_token`, 30 min expiry) and refresh token (`refresh_token`, 30 days).
- Level 1 `villager` can **self-register** by picking their village.
- Official logins (`gram_sabha`, `sdo`) are provisioned by admin.
- `GET /api/v1/me` returns the caller's active user object along with their list of `roles`, each scoped by `village_id` (village level) or `taluka`/`district` (SDO level).

#### Endpoints
- `GET /api/v1/public/villages` → List of registered villages `[{id, name_en, name_mr, taluka, district, gram_panchayat}]`.
- `POST /api/v1/auth/register` → Body: `{"phone": "9876543210", "pin": "123456", "name": "Ramu Bhoye", "village_id": "<uuid>"}`. Returns tokens.
- `POST /api/v1/auth/login` → Body: `{"phone": "9000000001", "pin": "123456"}`. Returns `{"access_token": "...", "refresh_token": "...", "expires_in": 1800}`.
- `POST /api/v1/auth/refresh` → Body: `{"refresh_token": "..."}`. Returns new token pair.
- `GET /api/v1/me` → Returns user profile and role grants.

#### What to Build in Frontend
1. **Login Screen (`login_screen.dart`):**
   - Clean 10-digit phone field and 6-digit PIN input with show/hide toggle.
   - Quick-fill buttons for testing demo users (`Villager`, `Gram Sabha`, `SDO`).
2. **Registration Screen (`register_screen.dart`):**
   - Full name, Phone, PIN confirmation.
   - Village dropdown populated via `/public/villages`.
3. **User State Provider (`auth_provider.dart`):**
   - Saves tokens in encrypted Hive box.
   - Loads `/api/v1/me` on startup. Displays current logged-in role banner in app header.

---

### Module 1: The Case Hub & 6-Step Dashboard (`lib/features/case_hub/`)

#### Backend Mechanics
- A `ClaimCase` belongs to one of three types: `ifr` (Individual), `cr` (Community Rights), or `cfr` (Community Forest Resource).
- Lifecycle states: `draft` → `gs_review` → `sdo_review` → `district_review` → `title_issued` (or `rejected` / `expired`).
- Response returns `allowed_actions: ["submit"]` or `["approve", "return", "reject"]`.
- Returned claims include `returned: {by_role, by_name, remarks, returned_on, resubmit_by, days_left}`.

#### Endpoints
- `GET /api/v1/cases/mine` → Cases created by the logged-in user.
- `GET /api/v1/villages/{village_id}/cases` → All cases in the village visible to the user's role.
- `GET /api/v1/review/queue` → Cases waiting for **current user's approval** across their jurisdiction (oldest first).
- `POST /api/v1/villages/{village_id}/cases` → Body: `{"claim_type": "ifr" | "cr" | "cfr"}`. Opens a fresh draft claim.
- `GET /api/v1/cases/{id}` → Full summary for the case.

#### What to Build in Frontend
1. **Home / Cases Screen (`cases_list_screen.dart`):**
   - Tabs: **My Claims** (for villagers), **Village Claims** (overview), and **Review Queue** (prominently badge count for Gram Sabha and SDO!).
   - Floating Action Button: "+ Open New Claim" (dialog to pick Form A `ifr`, Form B `cr`, or Form C `cfr`).
2. **Case Stepper Dashboard (`case_home_screen.dart`):**
   - Displays Claimant Name, Claim Type, and Current State badge (`DRAFT`, `GRAM SABHA REVIEW`, `SDO REVIEW`).
   - If returned: Render **`DeadlineBanner`** showing reviewer remarks and "X days left to resubmit".
   - 6 Step Progress Cards:
     1. **Step 1: Claim Form** (Form A, B, or C filled)
     2. **Step 2: Evidence Pool** (photos, documents, elder statement)
     3. **Step 3: Boundary & Landmarks** (CFR mapping)
     4. **Step 4: Field Verification** (Joint Revenue & Forest report)
     5. **Step 5: Gram Sabha Meeting** (Quorum & Resolution)
     6. **Step 6: Status & Title Certificate** (SDO approval & Title Draft)
   - Bottom Action Bar: dynamically renders buttons present in `allowed_actions`.

---

### Module 2: Claim Forms A, B, and C (`lib/features/form_a/`, `form_b/`, `form_c/`)

#### Backend Mechanics
- Only the creator can edit, and only while the case is in `draft`.
- Once submitted, form is locked (returns 409 if edited).
- Returned case goes back to `draft`, making it editable again.

#### Form A (IFR — Individual Forest Rights)
- **Endpoint:** `GET /api/v1/cases/{id}/form-a`, `PUT /api/v1/cases/{id}/form-a`
- **Fields:**
  - Claimant Names (`list[str]`), Spouse Name, Parents Name, Address.
  - Category: `is_scheduled_tribe` (`bool`), `is_otfd` (`bool`), `spouse_is_scheduled_tribe` (`bool`).
  - Family Members: `[{seq, name, age, relation}]`.
  - Claim Items: `[{claim_code, extent_ha, details}]` where claim codes are: `habitation`, `self_cultivation`, `disputed_lands`, `pattas_leases`, `conversion_forest_villages`, `other_traditional_rights`.

#### Form B (CR — Community Rights)
- **Endpoint:** `GET /api/v1/cases/{id}/form-b`, `PUT /api/v1/cases/{id}/form-b`
- **Fields:**
  - Claimant Names, FDST/OTFD community flags.
  - Rights Claimed (`rights`): list of right entries (`nistar`, `minor_forest_produce`, `grazing`, `water_bodies`, `fish_products`, `pastoralist_routes`, `biodiversity`, `other`).
  - Maharashtra field practice per right: Survey/compartment numbers, total area in ha, 4 boundary landmarks (East, West, North, South चतु:सीमा), annual quantity used.

#### Form C (CFR — Community Forest Resource)
- **Endpoint:** `GET /api/v1/cases/{id}/form-c`, `PUT /api/v1/cases/{id}/form-c`
- **Fields:**
  - `resolution_statement` (Default Marathi/English text passed by FRC).
  - `approx_area_ha` and `area_description` (words describing boundary until polygon is mapped).
  - `pastoral_seasonal_use` (`bool`) & `seasonal_use_details`.
  - `khasra_compartment_numbers` (`list[str]`).
  - `landmarks`: `[{seq, side: "east"|"west"|"north"|"south"|"within", kind, name, description}]`.
  - `bordering_villages`: `[{seq, name, shares_resources, sharing_details}]`.
- **Gram Sabha Member Roster:**
  - `GET /api/v1/villages/{village_id}/members`
  - `POST /api/v1/villages/{village_id}/members` → Body: `{"name": "Asha Bhoye", "gender": "female"|"male"|"other", "category": "st"|"otfd"|"other"}`.

#### What to Build in Frontend
- Multi-step, card-based form editors with auto-save or "Save Draft" button.
- Clean add/remove dialogs for Family Members, Right Items, Landmarks, and Bordering Villages.
- Member Roster Screen (`members_screen.dart`): shows member sheet (Form C item 5) with ST/OTFD tags and active status toggle.

---

### Module 3: FRC Constitution & Intimation (`lib/features/frc/`)

#### Backend Mechanics (Rule 3)
- FRC must have between **10 and 15 members**.
- If Gram Sabha has ST members, **at least 2/3 of FRC must be ST**.
- **At least 1/3 of FRC must be women**.
- Chairperson and Secretary must be two different people.
- `POST /villages/{id}/frc/check` runs a dry-run check without saving. If rules are broken, returns `409` with `rule: "Rule 3(1)"` and exact counts.

#### Endpoints
- `POST /api/v1/villages/{id}/frc/check` → Dry run verification.
- `POST /api/v1/villages/{id}/frc` → Body: `{"chair_member_id": "...", "secretary_member_id": "...", "member_ids": ["...", "..."]}`.
- `GET /api/v1/villages/{id}/frc` → Active FRC details and composition statistics.
- `POST /api/v1/villages/{id}/frc/intimation` → Body: `{"intimated_on": "2026-09-01"}` (Date FRC sent to SDLC).

#### What to Build in Frontend
1. **FRC Setup Screen (`frc_screen.dart`):**
   - Multi-select member picker from the Gram Sabha roster.
   - Dedicated dropdowns for Chairperson and Secretary.
   - Live Statutory Quota Indicator:
     - Total count: `12 / 10-15` (Green check if valid).
     - ST quota: `83% (≥ 66% required)` (Rule 3(1) chip).
     - Women quota: `41% (≥ 33% required)` (Rule 3(1) chip).
   - "Constitute FRC" button that validates via `/frc/check` before final save.
   - SDLC Intimation Date picker.

---

### Module 4: Call for Claims & Acknowledgement Slip (`lib/features/claim_call/`)

#### Backend Mechanics (Rule 11)
- The Gram Sabha makes a public call for claims for a **minimum of 3 months**.
- On submission of any claim, the backend automatically issues an **official written acknowledgement serial** (Format: `<Village>/<Year>/<Serial>`, e.g., `OZHAR/2026/0001`).

#### Endpoints
- `POST /api/v1/villages/{id}/claim-calls` → Body: `{"called_on": "2026-09-01", "place_of_filing": "Gram Panchayat Office", "notice_displayed_on": "2026-09-02"}`. Window is automatically 3 months.
- `GET /api/v1/villages/{id}/claim-calls/current` → Returns `closes_on`, `days_remaining`, `is_open`.
- `POST /api/v1/villages/{id}/claim-calls/current/extend` → Body: `{"extended_to": "2026-12-31", "reason": "Monsoon delay", "resolution_ref": "Res 4/2026"}`.
- `GET /api/v1/cases/{id}/acknowledgement` → Returns acknowledgement serial, date, filed within window, list of received documents.

#### What to Build in Frontend
1. **Notice Board Screen (`claim_call_screen.dart`):**
   - Displays Active Call banner: "Call open until 1 Dec 2026 (45 days remaining)".
   - Button for Gram Sabha: "Extend Window" with reason dialog.
2. **Acknowledgement Slip Card (`acknowledgement_card.dart`):**
   - Rendered upon submission: Displays official serial, date, QR/barcode-like style, and "Print Receipt (G4)" button.

---

### Module 5: Media Capture & Evidence Pool (`lib/features/evidence/`)

#### Backend Mechanics (Rule 13)
- Media file upload via multipart `POST /api/v1/media` (JPEG, PNG, WebP, PDF, Audio up to 20MB). Calculates SHA-256 for integrity.
- Evidence entry `POST /api/v1/cases/{id}/evidence`:
  - `rule_ref`: specific Rule 13 subclause (e.g. `13(1)(a)` govt records, `13(1)(c)` physical structures, `13(1)(i)` elder statements).
  - Elder Statement: requires `elder_member_id`, `transcript`, and `signed_scan_media_id`. Elder **cannot be a claimant** in this case (returns 409 Rule 13(1)(i) otherwise).
- Verifications: In `gs_review`, FRC members attest evidence. FRC members who are claimants must recuse themselves (409 Rule 3(3)).
- Advisory Completeness: `GET /api/v1/cases/{id}/readiness` checks Rules R1 to R10 (at least 2 independent pieces of evidence, boundary closed, etc.).

#### Endpoints
- `POST /api/v1/media` → Multipart `file`, optional `captured_at`, `gps_lat`, `gps_lon`. Returns `{"id": "<uuid>", "sha256": "..."}`.
- `GET /api/v1/media/{id}/file` → Stream download of media file.
- `POST /api/v1/cases/{id}/evidence` → Body:
  ```json
  {
    "rule_ref": "13(1)(c)",
    "kind": "photo",
    "description": "Ancient burial site and cattle shed",
    "media_id": "<uuid>",
    "gps_lat": 19.9234,
    "gps_lon": 73.2341
  }
  ```
- `GET /api/v1/cases/{id}/evidence` → List of evidence items with verification stamps.
- `POST /api/v1/cases/{id}/evidence/{eid}/verify` → FRC attestation.
- `GET /api/v1/cases/{id}/readiness` → Returns `{done: 7, total: 10, items: [{id: "R1", ok: true, rule: "Rule 13(1)", message_key: "..."}]}`.

#### What to Build in Frontend
1. **Evidence Capture Flow (`evidence_capture_screen.dart`):**
   - Options: Camera Photo (with auto-GPS), PDF Document Scan, or Elder Voice Recording.
   - For Voice: Audio recorder widget that uploads audio to `/media` and captures Marathi/English summary text.
   - Evidence Tagging Dropdown: Rule 13 options in plain Marathi/English (e.g. "Govt Record / वन हक्क दाखला", "Traditional Boundary Landmark / पारंपरिक सीमा", "Elder Testimony / ज्येष्ठांचे मौखिक पुरावे").
2. **Evidence Gallery Screen (`evidence_list_screen.dart`):**
   - Thumbnail cards showing description, date, Rule chip, and Verification status.
   - For Gram Sabha role: "Attest / Verify" button.
3. **Readiness Checklist Widget (`readiness_widget.dart`):**
   - Clean list of 10 legal requirements showing Green Check / Orange Circle, rule reference badge, and guidance text.

---

### Module 6: Boundary Mapping, Landmarks, Use Zones & Disputes (`lib/features/mapping/`)

#### Backend Mechanics (Rule 12(1)(f)(g), Rule 12(3))
- Geometry is **GeoJSON Polygon** `[lon, lat]` in EPSG:4326.
- Area in hectares is calculated by the backend in UTM 43N (metric projection).
- `segment_breaks`: vertex indices where boundary segments start (for 4 sides).
- `landmarks`: Each segment **must have at least 1 landmark** (stream, sacred tree, hillock, boundary stone) with lat/lon and photo.
- `use_zones`: Polygons inside CFR marked for Grazing, Minor Forest Produce (MFP), Sacred Groves, Water Sources.
- **Overlap & Dispute Engine (Rule 12(3)):**
  - Saving a boundary automatically checks all neighbouring Gram Sabhas.
  - Overlap > 1 m² automatically registers an official `Dispute` between both villages!
  - Resolution requires joint meeting (`resolved_by_joint_meeting`) or boundary adjustment.
- **Freezing:** Passing the Gram Sabha resolution freezes the boundary (`gs_approved`). Subsequent edits return 409 `BOUNDARY_FROZEN`.

#### Endpoints
- `POST /api/v1/cases/{id}/boundary` → Body:
  ```json
  {
    "polygon": {
      "type": "Polygon",
      "coordinates": [[[73.1, 19.1], [73.2, 19.1], [73.2, 19.2], [73.1, 19.2], [73.1, 19.1]]]
    },
    "source": "gps_walk",
    "segment_breaks": [0, 1, 2, 3],
    "vertex_accuracy_m": [3.2, 2.8, 4.1, 3.5]
  }
  ```
  Returns `BoundaryOut` with calculated `area_ha`, `segments`, and any `disputes_opened`.
- `GET /api/v1/cases/{id}/boundary` → Current active boundary, segments, landmarks, use zones, and open disputes.
- `POST /api/v1/cases/{id}/boundary/landmarks` → Body: `{"segment_seq": 0, "name": "Nala Odha", "kind": "stream", "lat": 19.12, "lon": 73.15, "photo_media_id": "<uuid>"}`.
- `POST /api/v1/cases/{id}/boundary/use-zones` → Body: `{"use_type": "grazing"|"mfp"|"sacred"|"water", "name": "Gavthan Charai", "polygon": {...}}`.
- `POST /api/v1/cases/{id}/boundary/walks` → Body: `{"walked_on": "2026-09-15", "participants": [{"name": "Elders & FRC", "role": "elder"}], "notes": "Walked traditional bounds"}`.
- `POST /api/v1/cases/{id}/disputes/{dispute_id}/resolve` → Resolves boundary conflict with neighbour.

#### What to Build in Frontend
1. **Interactive Map Screen (`boundary_map_screen.dart`):**
   - Supports: (a) Live GPS Boundary Walk (records points as you walk perimeter), (b) Manual Tap-to-Draw Polygon.
   - Visual layers:
     - Outer boundary line (with segment color coding).
     - Landmarks pinned with icons (tree, mountain, river).
     - Customary Use Zones filled with subtle pastel color overlays.
   - Shows computed Area (e.g. `245.50 ha`).
2. **Segment & Landmark Sheet (`landmark_sheet.dart`):**
   - Lists Segment 1 (North), Segment 2 (East), etc.
   - Prompts user if a segment has 0 landmarks (warns that Rule BR-08 requires at least 1).
   - "Pin Landmark" button: takes camera photo, records GPS, asks for landmark name & type.
3. **Boundary Dispute Alert Banner:**
   - Displays if backend reports `open_disputes > 0`: "Warning: 1.4 ha overlaps with neighbouring village (Kharonda). Boundary dispute opened [Rule 12(3)]."

---

### Module 7: Joint Field Verification (`lib/features/verification/`)

#### Backend Mechanics
- Joint on-site inspection conducted with Forest & Revenue officials.
- Verification record requires: visit date, observations, presence list (Officer names + Department), signatures obtained (`forest_signed: bool`, `revenue_signed: bool`), and the uploaded scanned report.

#### Endpoints
- `POST /api/v1/cases/{id}/verification` → Body:
  ```json
  {
    "visit_on": "2026-09-20",
    "observations": "Boundary verified in presence of RFO and Talathi",
    "presence": [
      { "name": "S. Patil", "department": "forest" },
      { "name": "V. Deshmukh", "department": "revenue" }
    ],
    "forest_signed": true,
    "revenue_signed": true,
    "signed_scan_media_id": "<uuid>"
  }
  ```
- `GET /api/v1/cases/{id}/verification` → Read inspection proceedings.

#### What to Build in Frontend
- **Field Verification Form (`verification_screen.dart`):**
  - Date picker for inspection date.
  - Presence list builder (Add official name, pick "Forest Department" or "Revenue Department").
  - Observations multi-line text input.
  - Signature check toggles: "Forest Official Signed" & "Revenue Official Signed".
  - Camera button: "Upload Scanned & Signed Joint Inspection Report".

---

### Module 8: Gram Sabha Meeting, Quorum & Resolution (`lib/features/gram_sabha/`)

#### Backend Mechanics (Rule 4(2))
- Gram Sabha meeting must satisfy statutory quorum before passing resolutions:
  - **Overall Attendance ≥ 50%** of total Gram Sabha members.
  - **Women Attendance ≥ 33%** of present attendees.
- Resolution approval freezes the CFR boundary polygon and unlocks forwarding to SDO.

#### Endpoints
- `POST /api/v1/villages/{village_id}/meetings` → Body: `{"held_on": "2026-09-25", "place": "Gram Panchayat Hall", "agenda": "CFR Boundary and Claim Approval"}`. Returns `meeting_id`.
- `PUT /api/v1/meetings/{meeting_id}/attendance` → Body: `{"present_member_ids": ["<uuid>", "<uuid>", ...]}`. Returns attendance count and gender breakdown.
- `GET /api/v1/meetings/{meeting_id}/quorum` →
  ```json
  {
    "total_members": 120,
    "present_count": 68,
    "present_women": 28,
    "quorum_met": true,
    "overall_pct": 56.6,
    "women_pct": 41.1,
    "rules": { "overall_50_met": true, "women_33_met": true }
  }
  ```
- `POST /api/v1/meetings/{meeting_id}/resolutions` → Body:
  ```json
  {
    "case_id": "<uuid>",
    "decision_text": "Gram Sabha unanimously approves Form C and the mapped CFR boundary",
    "votes_for": 68,
    "votes_against": 0,
    "approves_boundary": true,
    "signed_scan_media_id": "<uuid>"
  }
  ```

#### What to Build in Frontend
1. **Meeting Setup Screen (`meeting_screen.dart`):**
   - Meeting date, location, and agenda.
2. **Attendance Roster Screen (`attendance_screen.dart`):**
   - Displays all Gram Sabha members with checkboxes.
   - Quick filters: "All", "Women", "ST".
   - (Optional Facilitation Helper): Face recognition / photo attendance to help check boxes quickly.
3. **Live Quorum Status Card (`quorum_gauge_widget.dart`):**
   - Shows live attendance metrics as checkboxes are ticked:
     - Total: `68 / 120 (56.6%)` → Green Check (≥ 50% Rule 4(2)).
     - Women: `28 / 68 (41.1%)` → Green Check (≥ 33% Rule 4(2)).
   - If quorum is not met, banner shows in Orange: *"Cannot pass legal resolution: need 4 more women members"*.
4. **Resolution Drafting Screen (`resolution_screen.dart`):**
   - Decision statement input, Votes For / Votes Against.
   - "Upload Signed Gram Sabha Resolution Scan" button.

---

### Module 9: Workflow Transitions & Approval Pipeline (`lib/features/workflow/`)

#### Backend Mechanics
- Workflow actions are submitted via dedicated endpoints:
  - `POST /api/v1/cases/{id}/submit` (Claimant in `draft`)
  - `POST /api/v1/cases/{id}/approve` (Reviewer in `gs_review` or `sdo_review`)
  - `POST /api/v1/cases/{id}/return` (Reviewer: requires `remarks` ≥ 5 chars)
  - `POST /api/v1/cases/{id}/reject` (Reviewer: requires written reasons `remarks` [Rule 12A(7)])
- Form C approval in `gs_review` automatically verifies:
  1. Boundary approved in resolution (`GS_RESOLUTION_MISSING`)
  2. Field verification closed (`FIELD_VERIFICATION_MISSING`)
  3. No open disputes (`OPEN_DISPUTES_REMAIN`)

#### What to Build in Frontend
1. **Dynamic Action Bar (`workflow_action_bar.dart`):**
   - Appears at the bottom of the Case Screen.
   - Maps backend `allowed_actions`:
     - `"submit"` → Green button: **"दाखल करा / Submit Claim"**
     - `"approve"` → Green button: **"मंजूर करा / Approve & Forward"**
     - `"return"` → Amber button: **"त्रुटींसाठी परत पाठवा / Return with Remarks"**
     - `"reject"` → Red outlined button: **"नाकारणे / Reject with Reasons"**
2. **Return Dialog (`return_dialog.dart`):**
   - Multi-line text field for remarks explaining what corrections the villager needs to make.
   - Clarifies to the reviewer that the villager will get **60 days** to fix and resubmit.
3. **Reject Dialog (`reject_dialog.dart`):**
   - Mandatory written legal justification field (Rule 12A(7)).
4. **History Log Screen (`case_history_screen.dart`):**
   - Calls `GET /api/v1/cases/{id}/history`.
   - Timeline list showing: Action, Date, Officer Name, Role Badge, and Remarks.

---

### Module 10: Title Certificate & Printable HTML Documents (`lib/features/documents/`)

#### Backend Mechanics
- Once case reaches `district_review` or `title_issued`, `GET /cases/{id}/title-draft` generates the official Annexure draft:
  - Form A → Annexure II (*Title for forest land under occupation*)
  - Form B → Annexure III (*Title to community forest rights*)
  - Form C → Annexure IV (*Title to Community Forest Resources*)
- HTML Document endpoints render print-ready statutory templates with government header and bilingual labels.

#### Endpoints
- `GET /api/v1/cases/{id}/title-draft` → JSON title draft with rights granted, boundary descriptions, and holder names.
- `GET /api/v1/cases/{id}/documents/form-a/html` → Printable Form A HTML.
- `GET /api/v1/cases/{id}/documents/form-b/html` → Printable Form B HTML.
- `GET /api/v1/cases/{id}/documents/form-c/html` → Printable Form C HTML.
- `GET /api/v1/cases/{id}/documents/receipt/html` → Printable G4 Written Acknowledgement slip.
- `GET /api/v1/cases/{id}/documents/title/html` → Printable Annexure Title Certificate.

#### What to Build in Frontend
- **Document Preview Screen (`document_viewer_screen.dart`):**
  - WebView rendering the HTML document directly from the backend endpoint.
  - Top action bar with: **"Print / PDF"** and **"Share"**.
  - Standard footer disclaimer: *"Community record prepared with VanMitra. Not a government document."*

---

## 5. Master API Endpoints Cheat Sheet

| Category | HTTP Method | Path | Required Role | Summary |
|---|---|---|---|---|
| **Health** | `GET` | `/api/v1/health` | Public | Pings server & MongoDB connection |
| **Villages** | `GET` | `/api/v1/public/villages` | Public | Villages for registration picker |
| **Auth** | `POST` | `/api/v1/auth/register` | Public | Self-register as a `villager` |
| **Auth** | `POST` | `/api/v1/auth/login` | Public | Phone + 6-digit PIN login |
| **Auth** | `POST` | `/api/v1/auth/refresh` | Public | Refresh expired access token |
| **Auth** | `GET` | `/api/v1/me` | Authenticated | Current profile, roles & jurisdiction |
| **Cases** | `POST` | `/api/v1/villages/{vid}/cases` | `villager` / `gram_sabha` | Open a fresh claim (`ifr`, `cr`, `cfr`) |
| **Cases** | `GET` | `/api/v1/cases/mine` | Authenticated | List claims created by caller |
| **Cases** | `GET` | `/api/v1/villages/{vid}/cases` | Role in village | List claims in village |
| **Cases** | `GET` | `/api/v1/review/queue` | `gram_sabha` / `sdo` | Claims waiting for caller's action |
| **Cases** | `GET` | `/api/v1/cases/{id}` | Case Viewers | Case summary, state & `allowed_actions` |
| **Form A** | `GET` / `PUT` | `/api/v1/cases/{id}/form-a` | View / Creator (draft) | Read / update Form A draft |
| **Form B** | `GET` / `PUT` | `/api/v1/cases/{id}/form-b` | View / Creator (draft) | Read / update Form B draft |
| **Form C** | `GET` / `PUT` | `/api/v1/cases/{id}/form-c` | View / Creator (draft) | Read / update Form C draft |
| **Members** | `GET` / `POST` | `/api/v1/villages/{vid}/members` | View / `gram_sabha` | Gram Sabha member sheet |
| **FRC** | `POST` | `/api/v1/villages/{vid}/frc/check` | `gram_sabha` | Dry-run check of FRC statutory rules |
| **FRC** | `POST` | `/api/v1/villages/{vid}/frc` | `gram_sabha` | Constitute FRC (10-15, 2/3 ST, 1/3 women) |
| **FRC** | `GET` | `/api/v1/villages/{vid}/frc` | Role in village | Read current FRC and quota statistics |
| **FRC** | `POST` | `/api/v1/villages/{vid}/frc/intimation` | `gram_sabha` | Record date sent to SDLC |
| **Claim Calls**| `POST` | `/api/v1/villages/{vid}/claim-calls` | `gram_sabha` | Open 3-month claim filing window |
| **Claim Calls**| `GET` | `/api/v1/villages/{vid}/claim-calls/current` | Role in village | Current call & days remaining |
| **Claim Calls**| `POST` | `/api/v1/villages/{vid}/claim-calls/current/extend` | `gram_sabha` | Extend window with resolution ref |
| **Receipt** | `GET` | `/api/v1/cases/{id}/acknowledgement` | Case Viewers | G4 receipt serial & filing data |
| **Media** | `POST` | `/api/v1/media` | Authenticated | Multipart upload (images/PDF/audio ≤20MB)|
| **Evidence** | `POST` | `/api/v1/cases/{id}/evidence` | Creator / `gram_sabha` | Add Rule 13 evidence entry |
| **Evidence** | `GET` | `/api/v1/cases/{id}/evidence` | Case Viewers | List all evidence & verification stamps |
| **Evidence** | `POST` | `/api/v1/cases/{id}/evidence/{eid}/verify` | `gram_sabha` (review) | FRC attestation (claimants recuse) |
| **Readiness** | `GET` | `/api/v1/cases/{id}/readiness` | Case Viewers | 10-point statutory advisory checklist |
| **Boundary** | `POST` | `/api/v1/cases/{id}/boundary` | `gram_sabha` | Save GeoJSON polygon version |
| **Boundary** | `GET` | `/api/v1/cases/{id}/boundary` | Case Viewers | Current polygon, area in ha, segments |
| **Landmarks**| `POST` | `/api/v1/cases/{id}/boundary/landmarks` | `gram_sabha` | Pin landmark on segment with photo |
| **Use Zones** | `POST` | `/api/v1/cases/{id}/boundary/use-zones` | `gram_sabha` | Add grazing/MFP/sacred zone |
| **Walks** | `POST` | `/api/v1/cases/{id}/boundary/walks` | `gram_sabha` | Record boundary walk with elders (G9) |
| **Disputes** | `POST` | `/api/v1/cases/{id}/disputes/{did}/resolve` | `gram_sabha` | Mark overlap dispute resolved |
| **Verification**| `POST` | `/api/v1/cases/{id}/verification` | `gram_sabha` | Record joint Revenue + Forest visit |
| **Meetings** | `POST` | `/api/v1/villages/{vid}/meetings` | `gram_sabha` | Create Gram Sabha meeting |
| **Attendance** | `PUT` | `/api/v1/meetings/{mid}/attendance` | `gram_sabha` | Submit attendee member IDs |
| **Quorum** | `GET` | `/api/v1/meetings/{mid}/quorum` | `gram_sabha` | Live check: ≥50% overall & ≥33% women |
| **Resolutions**| `POST` | `/api/v1/meetings/{mid}/resolutions` | `gram_sabha` | Pass resolution (freezes boundary) |
| **Workflow** | `POST` | `/api/v1/cases/{id}/submit` | Claimant (draft) | Submit claim to Gram Sabha |
| **Workflow** | `POST` | `/api/v1/cases/{id}/approve` | Reviewer | Forward to next level (GS → SDO) |
| **Workflow** | `POST` | `/api/v1/cases/{id}/return` | Reviewer | Return to villager (needs remarks) |
| **Workflow** | `POST` | `/api/v1/cases/{id}/reject` | Reviewer | Reject with written reasons |
| **History** | `GET` | `/api/v1/cases/{id}/history` | Case Viewers | Complete audit timeline |
| **Title Draft**| `GET` | `/api/v1/cases/{id}/title-draft` | Case Viewers | Annexure II, III, or IV title draft |
| **Documents** | `GET` | `/api/v1/cases/{id}/documents/{type}/html` | Case Viewers | Print-ready HTML document |

---

## 6. Checklist of Next Steps for Kaushal

1. **Verify Base Connection:**
   - Run `adb reverse tcp:8010 tcp:8010` (or `8000`).
   - Call `/api/v1/health` and verify `{"status": "ok", "database": "ok"}`.
2. **Auth & Current User Provider:**
   - In `lib/core/auth/`, implement login with phone & PIN, store JWT token, and call `/api/v1/me`.
   - Test login with `9000000001` (Villager) and `9000000003` (Gram Sabha).
3. **Connect Form B & Form C Screens:**
   - Wire up `form_b_screen.dart` and `form_c_screen.dart` to their respective endpoints (`/cases/{id}/form-b`, `/cases/{id}/form-c`).
4. **Build Case Hub Stepper Dashboard:**
   - Implement `case_home_screen.dart` with the 6 step progress cards and dynamic `allowed_actions` buttons.
5. **Implement Boundary Map & Landmarks:**
   - In `lib/features/mapping/`, integrate the GPS polygon walk and landmark pinning sheet.
6. **Implement Quorum Engine in Meeting Attendance:**
   - In `lib/features/gram_sabha/`, connect attendance checkboxes to `/meetings/{id}/attendance` and display live 50% overall / 33% female quorum status.
7. **Document Viewer:**
   - Integrate InAppWebView or browser launcher to preview `/documents/{type}/html`.

---
*Created and maintained by Soham for Kaushal · VanMitra AI Project*
