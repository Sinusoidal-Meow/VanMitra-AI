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
