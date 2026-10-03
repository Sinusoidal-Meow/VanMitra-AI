# API contract: the statutory procedure around a claim (BACKEND_PLAN Stages 1–5)

These endpoints run alongside the Module 3 workflow ([API_MODULE3.md](API_MODULE3.md)).
They record **how** a claim was prepared (the FRC, the call for claims, the evidence
and who verified it, the letters sent), so the Gram Sabha's file holds up on review.
Base path `/api/v1`. Errors use the usual `{error, message_key, details}` body. When a
rule of the FRA Rules is broken the status is **409** and the body also carries `rule`
(for example `"Rule 3(3)"`).

Documentation completeness (R1–R10) is **advisory**. It never blocks an action and is
never shown as a score.

## 1. Village registry and Forest Rights Committee (Stage 1)

| Method | Path | Who | Notes |
|---|---|---|---|
| POST | `/admin/villages` | admin | Village or hamlet (`parent_village_id`); creates its Gram Sabha |
| PATCH | `/admin/villages/{id}` | admin | |
| GET | `/villages/{id}` · `/villages/{id}/hamlets` | anyone with a role covering the village | |
| POST | `/villages/{id}/frc/check` | gram_sabha | Dry-run of the composition rules, without saving |
| POST | `/villages/{id}/frc` | gram_sabha | Constitute the FRC. 10–15 members, ≥⅔ ST (when the GS has ST members), ≥⅓ women, separate chair and secretary. Breaking a rule gives 409 `Rule 3(1)` |
| GET | `/villages/{id}/frc` · `/frc/history` | role in village | |
| POST | `/villages/{id}/frc/intimation` | gram_sabha | Date the chair and secretary were intimated to the SDLC |
| GET / PUT | `/cases/{id}/claimants` | view / claimant while drafting | Gram Sabha members who are claimants. Used for recusal and for the elder check |

## 2. Call for claims and acknowledgement (Stage 2) [Rule 11]

| Method | Path | Who | Notes |
|---|---|---|---|
| POST | `/villages/{id}/claim-calls` | gram_sabha | `called_on`, `place_of_filing`, `notice_displayed_on?`, `cfr_determination_on?`. Window = 3 months [11(1)(a)] |
| GET | `/villages/{id}/claim-calls/current` · `/claim-calls` | role in village | `closes_on`, `days_remaining`, `is_open` |
| POST | `/villages/{id}/claim-calls/current/extend` | gram_sabha | `extended_to`, `reason`, `resolution_ref`. 409 `Rule 11(1)(a)` unless later than the current close |
| POST | `/villages/{id}/claim-calls/current/displayed` | gram_sabha | Date the notice was put up |
| GET | `/cases/{id}/acknowledgement` | case viewers | G4 receipt data: `serial` (`<LGD or village code>/<year>/<nnnn>`, per Gram Sabha), `acknowledged_on`, `filed_within_window`, `documents_received`. 409 `NOT_YET_FILED` before submit |

The serial is issued on **submit** (`POST /cases/{id}/submit`) and never changes after
that. The case is linked to the call for claims that was current when it was filed.

## 3. Media and the evidence ledger [Rule 13]

| Method | Path | Who | Notes |
|---|---|---|---|
| POST | `/media` | any login | multipart `file` (+ `captured_at`, `gps_lat`, `gps_lon`, `gps_accuracy_m`). JPEG/PNG/WebP/PDF/audio only (415), up to 20 MB (413). Content-addressed by SHA-256 |
| GET | `/media/{id}` · `/media/{id}/file` | uploader, or anyone who can see a case that uses the file | |
| POST | `/cases/{id}/evidence` | claimant while `draft`; gram_sabha while `gs_review` | `rule_ref` (13(1)(a)…13(2)(e)), `kind`, `description`, `media_id?`, `source_office?`, `ref_no?`, `doc_date?`, GPS. Elder statement: `kind=elder_statement`, `rule_ref=13(1)(i)`, `elder_member_id`, `transcript`, `signed_scan_media_id`. 409 `Rule 13(1)(i)` if the elder is a claimant |
| GET | `/cases/{id}/evidence[?include_superseded=true]` | case viewers | Each item has `verified` and its `verifications` |
| POST | `/cases/{id}/evidence/{eid}/correct` | as for adding | Body as for adding, plus `correction_reason`. Adds a new row that supersedes the old one. Nothing is edited |
| POST | `/cases/{id}/evidence/{eid}/verify` | gram_sabha, in `gs_review` | `remarks?`. A verifier who is a claimant in the case is refused with 409 `Rule 3(3)`, and the recusal is recorded |
| GET | `/cases/{id}/readiness` | case viewers | R1–R10 with rule and `message_key` (CFR gets all ten; Forms A/B get R1, R5, R6, R7, R9) |

GPS points and satellite items are stored but are **not substitutable**: they never
count towards the two-evidence test (R1). Media must be uploaded by the person adding
the evidence.

## 4. Letters (G-series correspondence)

| Method | Path | Who | Notes |
|---|---|---|---|
| POST | `/villages/{id}/letters` | gram_sabha | `template` (`g2_intimation_adjoining` needs `neighbour_village`), `addressee`, `subject`, `body?`, `case_id?`, `records_requested[]` |
| GET | `/villages/{id}/letters[?case_id=&template=]` | role in village | `reminder_due` when there is no reply by `reminder_on` |
| POST | `/letters/{id}/dispatch` | gram_sabha | `dispatched_on`, `reminder_after_days` (default 30) |
| POST | `/letters/{id}/response` | gram_sabha | `received_on` (not before dispatch), `outcome` |

R8 is met when every bordering village on Form C has a dispatched G2 intimation.

## 5. Tamper evidence

Evidence, verifications, workflow events and ledger links are **append-only**: a
database trigger refuses UPDATE and DELETE. Each is also linked into the Gram Sabha's
hash chain: `record_hash = SHA256(canonical_json(row) ‖ previous hash)`.

| Method | Path | Who | Notes |
|---|---|---|---|
| GET | `/villages/{id}/ledger/verify` | role in village | `ok`, `length`, `head`. If the chain is broken: `broken_at_seq`, `broken_entity`, `reason` (`record altered`, `record missing`, `chain link broken`) |

## 6. Boundary, landmarks, use zones, walks (Stage 3) [Rule 12(1)(f)(g)]

CFR cases only. The Gram Sabha maps while the case is a draft, and while the case is in
`gs_review`. Geometry is GeoJSON in `[lon, lat]` (EPSG:4326). Areas are in hectares,
computed in UTM 43N. The polygon is **never clipped** to forest or legal layers.

| Method | Path | Notes |
|---|---|---|
| POST | `/cases/{id}/boundary` | `polygon` (GeoJSON Polygon; rings are closed for you), `source` (`gps_walk` / `sketch_digitised` / `imported`), `segment_breaks` (vertex indices of the outer ring where segments start; `[0]` = one segment), `vertex_accuracy_m[]?` (points over 15 m are counted in `accuracy_stats.over_limit`). Each save makes a **new version**. Landmarks and use zones of the previous draft carry over where their segment still exists. Invalid shapes (self-crossing, fewer than 3 points) return 422 `INVALID_GEOMETRY` with the PostGIS reason. Overlaps with neighbours are checked at once (see §7) |
| GET | `/cases/{id}/boundary` | Current version: geometry, `area_ha`, segments (with `length_m`, `landmark_count`), landmarks, use zones, `segments_without_landmark`, `open_disputes` |
| GET | `/cases/{id}/boundary/versions` | All versions, oldest first |
| POST / DELETE | `/cases/{id}/boundary/landmarks[/{lid}]` | `segment_seq`, `name`, `kind` (as on Form C), `lat`, `lon`, `photo_media_id?`, `evidence_id?`. Response has `distance_to_segment_m`. Each segment needs at least one landmark (BR-08, readiness R4) |
| POST / DELETE | `/cases/{id}/boundary/use-zones[/{zid}]` | `use_type` (grazing, mfp, water, fishing, fuelwood, sacred, shifting_cultivation, habitat, other), `polygon`, `name?`, `season?`, `user_hamlets[]` [Rule 13(2)(b)]. `within_boundary` tells you if the zone lies inside the claim |
| POST / GET | `/cases/{id}/boundary/walks` | The walk of the customary boundary (source of G9): `walked_on`, `participants[]` (`name`, `gs_member_id?`, `role` elder/frc/member/other), `trace?` (LineString), `notes?` |

The approved version is frozen (`status` becomes `gs_approved`, and `sealed_hash` is set)
when the Gram Sabha resolution approves it (Stage 4). Changes after that return 409
`BOUNDARY_FROZEN`.

## 7. Overlaps and disputes [Rule 12(3)] (BR-09)

Saving a boundary compares it with the current CFR boundaries of **other Gram Sabhas**.
Every overlap larger than 1 m² opens a dispute, which both villages see through their
own case. A dispute stays **open** (readiness R10 fails) until one of these is true:

- a joint meeting is recorded with outcome `agreed_shared` or `agreed_adjusted`, or
- the dispute has been referred to the SDLC.

If the overlap disappears because a boundary is redrawn, the open dispute is emptied
(`overlap_ha` = 0) and stops blocking.

| Method | Path | Who | Notes |
|---|---|---|---|
| GET | `/cases/{id}/disputes` | case viewers | `neighbour_village`, `overlap` (GeoJSON), `overlap_ha`, `is_open` |
| POST | `/cases/{id}/boundary/conflicts/check` | gram_sabha | Re-runs the overlap test |
| POST | `/cases/{id}/disputes/{did}/joint-meeting` | gram_sabha of either village | G17: `held_on`, `findings`, `outcome` (`agreed_shared` / `agreed_adjusted` / `not_resolved`), `record_media_id?`. Can be recorded again while `not_resolved` |
| POST | `/cases/{id}/disputes/{did}/sdlc-referral` | gram_sabha of either village | `referred_on`, `ref`. Allowed after a `not_resolved` joint meeting, or 30 days after detection [Rule 14(7)]. Otherwise 409 `Rule 12(3)` |

## 8. Field verification (Stage 4) [Rule 12(1), 12A(1)(2)] (BR-07)

| Method | Path | Notes |
|---|---|---|
| POST | `/cases/{id}/verification` | gram_sabha, case in `gs_review`. `visit_on`, `observations`, `presence[]` (`name`, `designation?`, `department` forest/revenue/frc/other), `forest_signed` / `forest_absence_recorded`, `revenue_signed` / `revenue_absence_recorded`, `signed_scan_media_id` (required when anyone signed), `intimation_id` (the G7 letter). Each department must have **signed or be recorded absent**. An absence needs a **dispatched G7 letter sent before the visit** (409 `Rule 12A(1)(2)`). A claimant in the case is refused (409 `Rule 3(3)`). Each visit is a new row with the next `attempt_no`; nothing is edited |
| GET | `/cases/{id}/verification` | All visits. `complete` is true when both departments are covered. `finality_note` is true on a second visit with an absence: the Gram Sabha decision is final [Rule 12A(2)] |

## 9. Meetings, quorum and resolutions (Stage 4) [Rule 4(2); Sec 6(1)] (BR-03)

| Method | Path | Notes |
|---|---|---|
| POST / GET | `/villages/{id}/meetings` | `held_on`, `place`, `notice_on?` (not after the meeting), `agenda`. `registered_count` is the active roster that day |
| GET | `/meetings/{id}` | Counts: `present_count`, `women_present`, `resolutions` |
| PUT | `/meetings/{id}/attendance` | `present_member_ids[]`. Marks every active member present or absent (manual register). Locked once a resolution exists (409 `ATTENDANCE_LOCKED`) |
| GET | `/meetings/{id}/quorum[?case_id=]` | The three tests. `t1` present ≥ ⌈registered/2⌉, `t2` women ≥ ⌈present/3⌉, `t3` claimants present ≥ ⌈claimants/2⌉ (needs `case_id`) |
| POST | `/meetings/{id}/resolutions` | `case_id` (in `gs_review`), `decision_text`, `votes_for`, `votes_against`, `signed_scan_media_id?`. All three tests must pass (409 `QUORUM_FAILED`, with the failing tests). Simple majority of those voting (409 `MOTION_NOT_CARRIED`). The quorum arithmetic of the day is stored on the resolution and never recomputed. For a **CFR** claim it also approves the current boundary: each segment needs a landmark (409 `Rule 12(1)(g)`), no overlap may be open (409 `Rule 12(3)`); the boundary is then **frozen** and sealed. The number is `n/year`, per Gram Sabha |
| GET | `/cases/{id}/resolutions` | |

## 10. The Gram Sabha approval guard (BR-04)

For a **CFR** claim, `POST /cases/{id}/approve` by the Gram Sabha (forwarding it to the
SDO) is refused with 409 `GS_PREREQUISITES_MISSING` (the missing items are in
`details.missing`, each with its rule) until all of these hold:

1. a resolution that passed quorum, 2. the boundary approved by that resolution,
3. a closed field verification, 4. no open overlap dispute.

`GET /cases/{id}/approval-check` returns the same list as `{ready, items[]}` so the app
can show it. Form A and Form B claims have no such prerequisites. Readiness R3, R4, R5,
R7 and R10 now reflect the real boundary, verification, resolution and disputes.

## 11. G-series documents (Stage 5)

Printable HTML (autoescaped). Each page has a footer with the case id, the time it was
generated, a SHA-256 of its body and the notice *"Community record prepared with
VanMitra. Not a government document."* Headings are English, or Marathi + English with
`?lang=mr`. The content is only what the Gram Sabha recorded.

| Method | Path | Notes |
|---|---|---|
| GET | `/cases/{id}/documents/g4` | Acknowledgement receipt (409 until filed) |
| GET | `/cases/{id}/documents/g8` | Verification sheets, one block per visit, with the second-absence note |
| GET | `/cases/{id}/documents/g9` | Boundary delineation record: walks, participants, segments, landmarks |
| GET | `/cases/{id}/documents/g10` | CFR map sheet with an SVG of the boundary, numbered landmarks, bordering villages, use zones, resolution number. **409 `Rule 12(1)(g)` while any segment has no landmark (BR-08)** |
| GET | `/cases/{id}/documents/g12?meeting_id=` | Attendance and the three quorum tests |
| GET | `/cases/{id}/documents/g13` | The current resolution with its stored quorum arithmetic |
| GET | `/cases/{id}/documents/g17?dispute_id=` | Joint-meeting record for an overlap |
| GET | `/letters/{id}/document` | A tracked letter (G2, G5, G6, G7, G18) as a page |

## 12. Legal clocks and the record after the title [Rule 8(i), 12A(9)] (BR-13)

| Method | Path | Notes |
|---|---|---|
| GET | `/cases/{id}/timeline` | Running periods: `claim_window` [11(1)(a)], `petition_against_resolution` (60 days from the resolution) [Sec 6(2), 14(1)], `mutual_solution` (30 days per overlap) [14(7)], `record_update` (3 months from the title) [12A(9)]. Each has `starts_on`, `due_on`, `status` (running / overdue / met), `days_remaining`, `next_alert_on` (days 30, 45, 55, 58 of the 60-day clock) |
| GET / PUT | `/cases/{id}/post-title` | After `title_issued`, by gram_sabha, SDO or a district officer: `certified_copy_media_id`, `certified_copy_on`, `survey_letter_id` (G18), `survey_done_on`, `record_entry_on`, `record_entry_ref`, `record_entry_media_id`. Response has `survey_pending`, `record_update_due_on`, `missing`, `can_close` |
| POST | `/cases/{id}/close` | Closes the file. 409 `CANNOT_CLOSE` (with `missing`) unless the certified copy and the record entry are on file (BR-13). A closed case takes no more changes |

Orders from outside the app (BR-10, BR-11, BR-12, BR-14) are not built: in this module
the officials approve, return and reject inside the app, and each action is already
recorded in the case history.
