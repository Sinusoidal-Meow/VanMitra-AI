# VanMitra: Frontend ↔ Backend Guide (`frontend_backend.md`)

> **For:** Kaushal (frontend) · Ishan · Soham (backend)
> **Last rewritten:** 8 October 2026, on branch `soham_backend`
> **App:** Flutter (`vanmitra_tem/`) · Riverpod · `http`
> **Server:** FastAPI (`vanmitra_backend/`) · MongoDB Atlas · JWT login
>
> This guide has three parts:
> - **Part A:** how to connect the app to the server.
> - **Part B:** the **village user's app**, screen by screen and button by button: what each button does, which Dart method runs, and which server call it makes.
> - **Part C:** every server endpoint the app uses.
>
> The Gram Sabha and SDO screens get their own designs later. Until then they keep their current screens.

---

## ⚠️ Temporary test setting: village user may open Form C

By law, Form C (Community Forest Resource claim) is prepared and filed by the Gram Sabha through its FRC [Rule 11(4)]. **For testing only**, the server currently lets a village user open Form C too, so the whole Form C flow can be tried from the villager login.

- **Switch:** `villager_opens_form_c` in `vanmitra_backend/app/config.py` (env `VANMITRA_VILLAGER_OPENS_FORM_C`). Default `true` for now.
- **To go back to the legal rule:** set `VANMITRA_VILLAGER_OPENS_FORM_C=false` in `vanmitra_backend/.env` and restart the server. The app needs no change: if the server refuses, the chooser shows the server's message.
- What the claimant (here the villager) may do on their own Form C **while it is a draft**:
  - fill Form C;
  - add evidence;
  - map the boundary;
  - pin landmarks;
  - mark use zones;
  - record the boundary walk.
- What stays with the **Gram Sabha** during its review:
  - field verification;
  - the meeting and its resolution;
  - approving the claim.

  The villager sees these records read-only.

---

# Part A: Connecting the app

## A1. Server address

The server runs on the PC on port **8010**. A phone on USB reaches it through `adb reverse`:

```bash
adb reverse tcp:8000 tcp:8010        # phone's 127.0.0.1:8000 → PC's 8010 (redo after replugging)
flutter build apk --debug --dart-define=VANMITRA_API_BASE_URL=http://127.0.0.1:8000
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

`ApiEndpoints.baseUrl` accepts the address with or without `/api/v1`. Health check: `GET /api/v1/health` returns `{"status":"ok","database":"ok",...}`.

## A2. Demo logins (PIN `123456`)

| Phone | Role in app | Server role | Village |
|---|---|---|---|
| `9000000001` | Village user | `villager` | Ozhar |
| `9000000002` | Village user 2 | `villager` | Ozhar |
| `9000000003` | Gram Sabha | `gram_sabha` | Ozhar |
| `9000000004` | Admin | `admin` | (none) |
| `9000000005` | SDO (Jawhar) | `sdo` | Jawhar taluka |

`/me` returns `roles` as a list. In the app, `gram_sabha` maps to `UserRole.frc` and `sdo` to `UserRole.sdlc`. The village id comes from `User.backendVillageId`.

## A3. Errors

Every error has the same body: `{error, message_key, rule?, details}`. A `409` means a legal rule was not met.
- Show plain words, plus a small rule chip (for example `[Rule 3(1)]`) when `rule` is present.
- Never show a raw crash.
- In Dart, `ApiClient` throws `ApiException` (`statusCode`, `error`, `messageKey`, `rule`, `details`).

## A4. Rules every screen follows

1. **The app records and checks. People decide.** There are no AI scores and no "chance of approval". Completeness is shown only as a checklist, for example "6 of 10 recorded", with the rule for each missing item.
2. **Buttons come from the server.** On a claim, only the actions listed in `allowed_actions` are shown (`submit`, `approve`, `return`, `reject`).
3. **Sent-back claims are loud.** A returned claim shows the reviewer's remarks and **days left** (60-day window).
4. **Paper first.** Signed scans (verification report, resolution, elder statement) are uploaded as photos.

---

# Part B: The village user's app, button by button

Entry: `lib/screens/home/villager_home_screen.dart` → `VillagerHomeScreen`. It is an `IndexedStack` of five tabs, all sharing one bottom bar (`AnimatedBottomNavBar`).

Every villager screen uses the same frame (`PortalFrameScaffold`):
- green header with the app name and the village, a status dot, and a language button;
- the notice strip (`NoticeBoardWidget`);
- a breadcrumb;
- the content;
- the dark-green footer ("Helpline: 1800-209-6060 | Forest Rights Act 2006 | Privacy Policy");
- the bottom bar.

Shared look, from `lib/widgets/villager_ui/`:
- `NatureBanner`: a light landscape strip with hills, sun, trees and a small house;
- `LeafCorner`: faint decorative leaves;
- `VillagerEmptyState`: a round icon with leaves, a title, a line of text and an optional orange button.

## B0. Frame (on every screen)

| Element | Method | What happens |
|---|---|---|
| Back arrow (pushed screens) | `Navigator.pop` | Goes back. |
| Settings / profile icon in header | `_PortalFrameScaffoldState._toggleSettings()` | Opens the settings panel (theme, profile shortcut). |
| Language button `EN ▾` | `AppHeader` → `localeProvider` | Switches English / मराठी. |
| Notice strip `×` | `noticesProvider.notifier.dismissNotice(id)` | Hides that notice; the counter (e.g. `3/4`) moves on. |
| Breadcrumb "Dashboard" | `_BreadcrumbBar` → `Navigator.pop` (as many times as needed) | Goes back to the dashboard. |

## B1. Bottom bar

| Item | Method | Opens |
|---|---|---|
| Dashboard (floating orange button) | `_VillagerHomeScreenState.setState(_currentTab = 0)` | Dashboard tab |
| Claims | `… _currentTab = 1` | **My Claims** (B3) |
| Profile | `… _currentTab = 2` | **Profile & Settings** (B6) |
| Gram Sabha | `… _currentTab = 3` | **Gram Sabha Records** (B5) |
| Atlas Map | `… _currentTab = 4` | `BoundaryMapScreen` (village atlas, unchanged) |

## B2. Dashboard tab (`_HomeTab`)

From top to bottom:
1. Green hero with nature layers.
2. Glass profile card.
3. S-curve.
4. Next Meeting card.
5. **Claims** heading with "Quick Actions".
6. Three claim cards.
7. Gram Sabha shortcuts.
8. Satellite parcel card.

**Removed (8 Oct 2026):** the statistics row (Approved Claims, Hectares Area, Meeting Records).

| Button / card | Method | Server call | What happens |
|---|---|---|---|
| Avatar on glass card | `onSwitchTab(AppTab.profile.index)` | none | Opens Profile tab. |
| Leaf emblem on glass card | `Navigator.pushNamed(AppRouter.fraRightsInfo)` | none | "Know your rights" page. |
| **Next Meeting** card | `onSwitchTab(AppTab.sabha.index)` | `GET /villages/{vid}/meetings` (to fill the card) | Shows the next meeting date and place from the server, or "No meetings scheduled". Tap opens the Gram Sabha tab. |
| "Quick Actions" label | `onSwitchTab(AppTab.claims.index)` | none | Opens My Claims. |
| **File New Claim** | `startNewBackendClaim(context, ref)` (`features/case_hub/new_claim.dart`) | `POST /villages/{vid}/cases {"claim_type": "cr"\|"cfr"}` | Chooser with **Form B (community rights)** and **Form C (community forest resource)**. **Form A is no longer offered.** After choosing, the claim is opened on the server and its claim page (B4) opens. |
| **Form B / C · Community claims** | `onSwitchTab(AppTab.claims.index)` | none | Opens My Claims, where all your community claims are listed. |
| **Evidence Checklist (Rule 13)** | `openEvidenceForMyClaim(context, ref)` (`new_claim.dart`) | `GET /cases/mine` | One open claim: opens its Evidence screen (B4.2). Several: a sheet to pick the claim. None: the Rule 13 guide, with a "File New Claim" button. |
| Gram Sabha Records | `onSwitchTab(AppTab.sabha.index)` | none | Gram Sabha tab. |
| Self check-in | `Navigator.pushNamed(AppRouter.selfCheckin, arguments: meeting.id)` | (existing attendance flow) | Only when a meeting is open today; otherwise a message. |
| Village map | `onSwitchTab(AppTab.map.index)` | none | Atlas Map tab. |
| Know your rights | `Navigator.pushNamed(AppRouter.fraRightsInfo)` | none | FRA guide. |
| Satellite parcel card | `Navigator.pushNamed(AppRouter.alertHistory)` | (Module B, offline seed) | Satellite alert history. |

## B3. My Claims tab (`features/case_hub/cases_list_screen.dart` → `CasesListScreen`)

Layout: breadcrumb "Dashboard › My Claims", `NatureBanner`, search box with a ⋮ menu, status chips, the claim cards (or the empty state), and an orange **+ File New Claim** button at the bottom right.

| Button | Method | Server call | What happens |
|---|---|---|---|
| (screen opens / pull down) | `_loadData()` | `GET /cases/mine` (village user). Gram Sabha / SDO also: `GET /villages/{vid}/cases`, `GET /review/queue` | Loads the claims. |
| Search box | `_onSearchChanged(text)` | none | Filters by claimant name, form letter, village, or status. |
| ⋮ menu → Refresh | `_loadData()` | as above | Reloads. |
| ⋮ menu → Newest first / Oldest first | `_setSort(newestFirst)` | none | Sorts by date opened. |
| ⋮ menu → My claims / Village claims / Review queue *(Gram Sabha and SDO only)* | `_setSource(_Source)` | none | Switches which list is shown. |
| Chip **✓ N Approved** | `_toggleFilter(_StatusFilter.approved)` | none | Shows only claims with a title issued. Tap again to clear. |
| Chip **◷ N Pending** | `_toggleFilter(_StatusFilter.pending)` | none | Draft, or waiting at Gram Sabha, SDO or district. |
| Chip **⊗ N Rejected** | `_toggleFilter(_StatusFilter.rejected)` | none | Rejected or expired. |
| "N Claims" counter | (display) | none | Number of claims in the current list. |
| A claim card | `_openCase(item)` | none | Opens the claim page (B4), then reloads on return. |
| **File New Claim** (empty state) and **+ File New Claim** (floating) | `_openNewClaim()` → `startNewBackendClaim(…, onChanged: _loadData)` | `POST /villages/{vid}/cases` | Same chooser as the dashboard: Form B or Form C. |

A claim card shows:
- the form letter;
- the claimant (or "Draft: name not filled yet");
- the form name;
- a coloured status pill;
- the date opened;
- the "sent back · N days left" pill when returned.

## B4. Claim page (`features/case_hub/case_home_screen.dart` → `CaseHomeScreen`)

Layout:
- a breadcrumb: "Dashboard › My Claims › Form C";
- a summary card on a nature banner, with the form, state, claimant and village;
- the sent-back banner, if the claim was returned;
- the **steps** list;
- the action bar.

The steps depend on the form:
- **Form C (cfr):** six steps. 1 Form · 2 Evidence · 3 Boundary · 4 Field verification · 5 Gram Sabha decision · 6 Status & title.
- **Form B (cr):** four steps. 1 Form · 2 Evidence · 3 Gram Sabha decision · 4 Status & title.

Each step's status comes from server data. `_loadCase()` loads, in parallel:
- `GET /cases/{id}`;
- `GET /cases/{id}/evidence`;
- `GET /cases/{id}/boundary` (Form C);
- `GET /cases/{id}/verification` (Form C);
- `GET /cases/{id}/resolutions`.

| Button | Method | Server call | What happens |
|---|---|---|---|
| ↻ (header) | `_loadCase()` | as above | Reloads. |
| 🕘 History (header) | `_showHistory()` | `GET /cases/{id}/history` | Sheet listing every action: who, which role, remarks, date. |
| Step **1 · Claim form** | `_openClaimForm()` | Form B: `GET/PUT /cases/{id}/form-b`. Form C: `GET/PUT /cases/{id}/form-c` | Opens the form (B4.1). Editable only while a draft; otherwise read-only. |
| Step **2 · Evidence (Rule 13)** | `_openEvidence()` | see B4.2 | Opens the evidence screen. |
| Step **3 · Boundary & landmarks** *(Form C)* | `_openBoundary()` | see B4.3 | Opens the boundary map. |
| Step **4 · Field verification** *(Form C)* | `_openVerification()` | `GET /cases/{id}/verification` | Read-only record of the joint visit (B4.4). |
| Step **Gram Sabha decision** | `_openGramSabhaDecision()` | `GET /cases/{id}/resolutions`, `GET /cases/{id}/approval-check` | Read-only resolution(s) and what the Gram Sabha still needs (B4.5). |
| Step **Status & title** | `_openStatus()` | `GET /cases/{id}/acknowledgement`, `GET /cases/{id}/title-draft` | Receipt number, the title draft once at district level, and history (B4.6). |
| **Submit claim** (action bar, shown if `submit` ∈ `allowed_actions`) | `_handleSubmit()` | `POST /cases/{id}/submit` | Asks to confirm, then sends the claim to the Gram Sabha. The form locks and a receipt number is issued. |
| Approve / Return / Reject *(reviewers only)* | `_handleApprove()` / `_handleReturn()` / `_handleReject()` | `POST /cases/{id}/approve` · `/return {remarks}` · `/reject {remarks}` | Return needs remarks (5+ characters) and gives the villager 60 days. Reject needs written reasons [Rule 12A(7)]. |

### B4.1 Form C screen (`features/form_c/form_c_screen.dart` → `FormCScreen`)

The sections follow the printed Form C, in order:
1. Village details (read-only from the registry).
2. Gram Sabha member sheet: counts, the first names, and **Manage member list** (`MembersScreen`).
3. Resolving statement (5a).
4. The area, with landmarks per side (5b).
5. Khasra / compartment numbers (6, optional).
6. Bordering villages (7).
7. Evidence list (8).

A completeness card at the top shows "N of 8 recorded" with each missing item and its rule.

| Button | Method | Server call | What happens |
|---|---|---|---|
| (opens) | `_load()` | `GET /cases/{id}/form-c` | Fills every field. |
| Manage member list | `_openMembers()` | `GET /villages/{vid}/members` | Member sheet (adding members is the Gram Sabha's job). |
| Restore printed text | `_restoreStatement()` | none (sent on save as `null`) | Puts back the printed resolving statement. |
| Pastoral / seasonal use switch | `setState(_pastoral = v)` | none | Shows the seasonal-use details box. |
| **+ Add landmark** | `_addLandmark()` | none | New row: side (E/W/N/S/inside), kind, name, description. |
| 🗑 on a row | `_removeLandmark(i)` / `_removeVillage(i)` / `_removeEvidence(i)` | none | Removes the row. |
| **+ Add bordering village** | `_addVillage()` | none | New row: name, "shares resources", details. |
| **+ Add evidence** | `_addEvidence()` | none | New row: Rule 13 tag and description (the actual photos go in Step 2). |
| **Save draft** (bottom) | `_save()` | `PUT /cases/{id}/form-c` | Saves; completeness refreshes. A 409 is shown as plain text. |

### B4.2 Evidence screen (`features/evidence/evidence_screen.dart` → `EvidenceScreen`)

Layout:
- the readiness checklist ("N of 10 recorded", or of 5 for Form B), with rule chips;
- the evidence cards: photo thumbnail, Rule 13 chip, kind, description, GPS, date, "Verified by FRC" stamp;
- **+ Add evidence**.

| Button | Method | Server call | What happens |
|---|---|---|---|
| (opens / pull down) | `_load()` | `GET /cases/{id}/evidence`, `GET /cases/{id}/readiness` | Loads the list and the checklist. |
| **+ Add evidence** (only while you may add) | `_addEvidence()` → `AddEvidenceSheet` | none yet | Opens the add sheet. |
| Sheet: Rule 13 picker | `setState(_rule = …)` | none | 14 sub-clauses in plain words. |
| Sheet: kind chips (Photo / Document scan / Written note / Elder statement) | `setState(_kind = …)` | none | The elder statement asks for the elder (from the member list), the transcript and the signed scan. |
| Sheet: **Take photo** | `_pickImage(ImageSource.camera)` | none | Camera; GPS is taken at the same time (`_captureGps()`). |
| Sheet: **From gallery** | `_pickImage(ImageSource.gallery)` | none | Picks an image. |
| Sheet: **Use my location** | `_captureGps()` | none | Fills lat / lon / accuracy (Geolocator). |
| Sheet: **Save evidence** | `_save()` | `POST /media` (multipart, with GPS) then `POST /cases/{id}/evidence` | Uploads the file, then records the evidence item. The server keeps a SHA-256 hash for integrity. |
| Tap a photo thumbnail | `_viewPhoto(mediaId)` | `GET /media/{id}/file` | Full-screen photo. |

### B4.3 Boundary screen (`features/mapping/boundary_screen.dart` → `BoundaryScreen`), Form C only

Layout:
- a map (OpenStreetMap / satellite toggle) showing:
  - the saved boundary, each side in its own colour;
  - landmarks as pins;
  - use zones as pale fills;
  - your position;
- an info strip: area in hectares, number of sides, "sides without a landmark", open disputes;
- the tool buttons;
- lists of landmarks, use zones, walks and disputes.

| Button | Method | Server call | What happens |
|---|---|---|---|
| (opens) | `_load()` | `GET /cases/{id}/boundary` (404 = none yet), `GET /cases/{id}/boundary/walks`, `GET /cases/{id}/disputes` | Shows what is saved. |
| 🛰 / 🗺 basemap | `_toggleBasemap()` | none | Satellite ↔ street map. |
| ◎ My location | `_centerOnMe()` | none | Centres the map on your GPS position. |
| **Draw on map** | `_startDrawing(_DrawTarget.boundary)` | none | Each tap adds a corner point. |
| **Walk with GPS** | `_startGpsWalk()` | none | Records a point every few metres as you walk the boundary, with accuracy. |
| Undo point | `_undoPoint()` | none | Removes the last point. |
| Clear | `_clearPoints()` | none | Starts again. |
| **Save boundary** | `_saveBoundary()` | `POST /cases/{id}/boundary` | Needs at least 3 points. The ring is split into the four sides (चतु:सीमा) using `segment_breaks`. The server works out the area in hectares and opens a dispute if it overlaps a neighbour's claim. |
| **Add landmark** | `_addLandmark()` → `_LandmarkSheet` | `POST /cases/{id}/boundary/landmarks` (+ `POST /media` for the photo) | Choose the side, kind and name. Position = your GPS position, or the map centre. Optional photo. |
| **Add use zone** | `_startDrawing(_DrawTarget.useZone)`, then `_saveUseZone()` | `POST /cases/{id}/boundary/use-zones` | Draw the zone, then choose its use (grazing, minor forest produce, water, sacred…), name and season. |
| **Record boundary walk** | `_recordWalk()` → `_WalkSheet` | `POST /cases/{id}/boundary/walks` | Date, who walked (names and roles), notes. If a GPS walk was just made, its trace is attached. |

While the claim is not your draft (submitted, or the boundary was approved by the Gram Sabha), the screen is view-only and the tool buttons are hidden.

### B4.4 Field verification (read-only, `features/case_hub/case_stage_screens.dart` → `VerificationRecordScreen`)

Shows each visit:
- the date;
- who was present (Forest / Revenue / FRC);
- the observations;
- "Forest signed" and "Revenue signed" ticks;
- the signed report photo;
- "Complete" or "Still open".

The Gram Sabha records this; its screen comes with the Gram Sabha design.

### B4.5 Gram Sabha decision (read-only, `GramSabhaDecisionScreen`)

Shows:
- each resolution: number, decision, votes for and against, the quorum proof (present, women present, passed) and the signed scan;
- for Form C, the approval checklist: resolution passed, boundary approved, verification complete, no open disputes, each with its rule.

### B4.6 Status & title (`ClaimStatusScreen`)

Shows:
- the receipt (acknowledgement) number and date, once submitted;
- the title draft (Annexure III / IV) once the claim reaches the district;
- the full history timeline.

## B5. Gram Sabha Records tab (`features/gram_sabha_records/gram_sabha_records_screen.dart` → `GramSabhaRecordsScreen`)

Layout:
- header title "ग्रामसभा | Gram Sabha Records";
- notice strip;
- `NatureBanner`;
- two tabs, **Upcoming (येणारी बैठक)** and **Past (मागील नोंदी)**, with an orange underline;
- meeting cards, or the empty state "No meetings scheduled yet."

| Button | Method | Server call | What happens |
|---|---|---|---|
| (opens / pull down) | `ref.refresh(villageMeetingsProvider(vid))` | `GET /villages/{vid}/meetings` | Upcoming = today or later; Past = before today. |
| Tab Upcoming / Past | `TabController` | none | Switches the list. |
| A meeting card | `_showMeeting(meeting)` | `GET /meetings/{id}/quorum` (only if attendance was recorded) | Sheet with the date, place, agenda, attendance, women present and quorum result. |

## B6. Profile & Settings tab (`screens/profile/profile_screen.dart` → `ProfileScreen`)

Layout:
- breadcrumb "Dashboard › Profile & Settings";
- a green hero card with nature layers: avatar, "Hello, name", role pill, village;
- **Cloud Sync & Offline Storage Diagnostics** card;
- **Account Preferences & Documents** tiles;
- Logout.

| Button | Method | Server call | What happens |
|---|---|---|---|
| **Trigger Immediate Cloud Sync** | `_handleManualSync()` | `CloudSyncService.syncPendingItems()` and `GET /health` | Sends anything saved offline, checks the server, and updates the "Synced" chip. |
| **My Documents & FRA Claims** | `_openMyClaims()` | none | Village user: switches to the Claims tab (callback from the home screen). Otherwise: pushes `CasesListScreen`. |
| **Resolution Ledger & Chain Integrity** | `_openLedger()` → `LedgerCheckScreen` | `GET /villages/{vid}/ledger/verify` | Re-checks the village's tamper-evident record chain. Shows "Intact: N records" or where it breaks. |
| Help & Legal Aid | `Navigator.pushNamed(AppRouter.fraRightsInfo)` | none | Legal aid info. |
| **Logout** | `_confirmLogout()` → `authProvider.notifier.logout()` | none | Ends the session and goes back to the start screen. |

---

# Part C: Server endpoints used by the app

All paths below start with `/api/v1`. All need `Authorization: Bearer <access_token>` except the public ones.

### Auth and user
| Method | Path | Who | Purpose |
|---|---|---|---|
| GET | `/public/villages` | public | Villages for sign-up |
| POST | `/auth/register` | public | Village user signs up `{phone, pin, name, village_id}` |
| POST | `/auth/login` | public | `{phone, pin}` → tokens |
| POST | `/auth/refresh` | public | New tokens |
| GET | `/me` | logged in | Profile and `roles` |

### Claims and workflow
| Method | Path | Who | Purpose |
|---|---|---|---|
| POST | `/villages/{vid}/cases` `{"claim_type"}` | village user: `cr`, `cfr` (cfr = test setting) · Gram Sabha: `cr`, `cfr` | Open a claim |
| GET | `/cases/mine` | logged in | Claims I opened |
| GET | `/villages/{vid}/cases` | role in village | Village claims (by visibility) |
| GET | `/review/queue` | Gram Sabha / SDO | Waiting for me, oldest first |
| GET | `/cases/{id}` | viewers | Summary, `allowed_actions`, `returned` |
| POST | `/cases/{id}/submit` · `/approve` · `/return` · `/reject` | per `allowed_actions` | Move the claim (`remarks` for return and reject) |
| GET | `/cases/{id}/history` | viewers | Every action |
| GET | `/cases/{id}/acknowledgement` | viewers | Receipt (after submit) |
| GET | `/cases/{id}/title-draft` | viewers | Annexure title draft (district stage onward) |

### Forms
| Method | Path | Purpose |
|---|---|---|
| GET / PUT | `/cases/{id}/form-b` | Form B draft (claimant edits while draft) |
| GET / PUT | `/cases/{id}/form-c` | Form C draft (claimant edits while draft) |
| GET | `/forms/form-c/fields` | Printed statement, sides, landmark kinds, Rule 13 tags |
| GET | `/villages/{vid}/members` | Gram Sabha member list |
| POST / PATCH | `/villages/{vid}/members`, `/members/{id}` | Gram Sabha keeps the list |

### Evidence and media
| Method | Path | Purpose |
|---|---|---|
| POST | `/media` (multipart: `file`, optional `captured_at`, `gps_lat`, `gps_lon`, `gps_accuracy_m`) | Upload a photo, PDF or audio (≤ 20 MB). Returns `{id, sha256, …}` |
| GET | `/media/{id}/file` | Download (with the token) |
| POST | `/cases/{id}/evidence` `{rule_ref, kind, description, media_id?, gps_*?, elder_member_id?, transcript?, signed_scan_media_id?}` | Add evidence (claimant while draft; Gram Sabha in review) |
| GET | `/cases/{id}/evidence` | List with verification stamps |
| POST | `/cases/{id}/evidence/{eid}/verify` | Gram Sabha attests (claimants recuse) |
| GET | `/cases/{id}/readiness` | Checklist R1–R10 (Form C) or the 5 that apply (Form B) |

### Boundary (Form C)
| Method | Path | Purpose |
|---|---|---|
| POST | `/cases/{id}/boundary` `{polygon, source, segment_breaks, vertex_accuracy_m?}` | Save a boundary version (polygon is GeoJSON, `[lon, lat]`) |
| GET | `/cases/{id}/boundary` | Current version: area, segments, landmarks, use zones, `segments_without_landmark`, `open_disputes` |
| GET | `/cases/{id}/boundary/versions` | All versions |
| POST | `/cases/{id}/boundary/landmarks` `{segment_seq, name, kind, lat, lon, photo_media_id?}` | Pin a landmark on a side |
| POST | `/cases/{id}/boundary/use-zones` `{use_type, name?, polygon, season?, user_hamlets[]}` | Mark a use zone |
| GET / POST | `/cases/{id}/boundary/walks` `{walked_on, participants[], trace?, notes?}` | Boundary walk with elders (G9) |
| GET | `/cases/{id}/disputes` | Overlaps with neighbours [Rule 12(3)] |
| POST | `/cases/{id}/disputes/{did}/joint-meeting`, `/sdlc-referral` | Gram Sabha settles or refers a dispute |

### Gram Sabha (read by everyone in the village; written by the Gram Sabha)
| Method | Path | Purpose |
|---|---|---|
| GET / POST | `/cases/{id}/verification` | Joint field visit record (POST: Gram Sabha) |
| GET / POST | `/villages/{vid}/meetings` | Meetings (POST: Gram Sabha) |
| GET | `/meetings/{mid}` · `/meetings/{mid}/quorum` | Meeting and quorum (≥ 50% present, ≥ 1/3 women, claimants) [Rule 4(2)] |
| PUT | `/meetings/{mid}/attendance` | Gram Sabha marks attendance |
| POST | `/meetings/{mid}/resolutions` `{case_id, decision_text, votes_for, votes_against, signed_scan_media_id?}` | Resolution (Form C: freezes the boundary) |
| GET | `/cases/{id}/resolutions` · `/cases/{id}/approval-check` | Resolutions of a claim and what's still needed before forwarding |
| GET | `/villages/{vid}/ledger/verify` | Tamper check of the record chain |

### Documents (printable HTML)
`GET /cases/{id}/documents/{code}?lang=en|mr`, where `code` is one of:
- `g4`: receipt;
- `g8`: verification;
- `g9`: boundary record;
- `g10`: map sheet;
- `g12`: quorum, needs `meeting_id`;
- `g13`: resolution;
- `g17`: joint meeting, needs `dispute_id`.

### Notifications and push
| Method | Path | Purpose |
|---|---|---|
| GET | `/notifications` · POST `/notifications/{id}/read` · `/notifications/read-all` | In-app messages (claim expired, sent back) |
| POST / DELETE | `/devices` | Register the phone for push messages (FCM) |

---

## Status words used in the app

| Server `state` | App label | Chip group |
|---|---|---|
| `draft` | Draft · मसुदा | Pending |
| `gs_review` | With Gram Sabha | Pending |
| `sdo_review` | With SDO | Pending |
| `district_review` | At district | Pending |
| `title_issued` | Title issued · सनद | Approved |
| `rejected` | Rejected · नाकारले | Rejected |
| `expired` | Expired (not resubmitted in 60 days) | Rejected |
