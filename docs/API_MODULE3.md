# API contract: Module 3 (FRA claims: Forms A, B, C with three-level review)

> **Owner:** Soham (backend) · **Consumer:** Kaushal (frontend) · **Status:** v1 on `soham_backend`
> Base URL `/api/v1`. Every call except `public/*`, `auth/register` and `auth/login` needs `Authorization: Bearer <access_token>`. Every error has the same body: `{error, message_key, rule?, details}`.
> Field-by-field form contracts: [`API_FORM_B.md`](API_FORM_B.md), [`API_FORM_C.md`](API_FORM_C.md). Form A is below. **The roles in those two files are superseded by §1 here.**

## 1. Logins: three levels, six roles

| Level | Role (`role`) | Who | Jurisdiction | Account created by |
|---|---|---|---|---|
| 1 · Village | `villager` | Village user / claimant | one village | **self-registration** |
| 1 · Village | `gram_sabha` | Gram Panchayat / Gram Sabha office | one village | admin |
| 2 · Sub-division | `sdo` | Sub-Divisional Officer (SDLC chair) | one taluka of a district | admin |
| 3 · District | `collector` | District Collector / Deputy Commissioner | one district | admin |
| 3 · District | `dfo` | Divisional Forest Officer / DCF | one district | admin |
| 3 · District | `tribal_welfare_officer` | District Tribal Welfare Officer | one district | admin |

Admin (`is_admin`) is back-office only: it creates accounts and never sees case content.

## 2. The claim path

```
village user ──submit──▶ GRAM SABHA ──approve──▶ SDO ──approve──▶ DISTRICT ──all 3 approve──▶ TITLE ISSUED
 (draft)                 (gs_review)            (sdo_review)     (district_review)            (title_issued)
     ▲   return (remarks)     │   return → gs_review   │   return → sdo_review   │
     └────────────────────────┘                        │                         │
                       reject (written reasons) ───────┴─────────────────────────┴──▶ REJECTED
```

| State | Waiting for | Allowed actions |
|---|---|---|
| `draft` | the claimant | edit the form · `submit` |
| `gs_review` | `gram_sabha` of the village | `approve` → `sdo_review` · `return` → `draft` · `reject` |
| `sdo_review` | `sdo` of the taluka | `approve` → `district_review` · `return` → `gs_review` · `reject` |
| `district_review` | each of `collector`, `dfo`, `tribal_welfare_officer` of the district | `approve` (once each; after all three → `title_issued`) · `return` → `sdo_review` · `reject` |
| `title_issued` | — | read the title draft |
| `rejected` | — | final in this module |

- **Who opens which form:** Form A (`ifr`) by the village user; Form B (`cr`) by the village user or the Gram Sabha; Form C (`cfr`) by the Gram Sabha.
- **Editing:** only the claimant who opened the case, only in `draft`. A `return` to `draft` makes it editable again.
- **Remarks:** `return` and `reject` need `remarks` (≥ 5 characters). A rejection's remarks are its written reasons [Rule 12A(7)].
- **District round:** a `return` from the district restarts the round, so all three officers approve again after the SDO re-forwards.
- **Who sees a case:** the claimant always. The Gram Sabha sees it once it's filed to them, the SDO once it reaches the SDO, district officers once it reaches the district. They keep seeing it after a return. Anyone else gets `404`.
- **`allowed_actions`** on every case response tells the app which buttons to show to the current user.

## 3. Endpoints

### Accounts
| Method | Path | Who | Purpose |
|---|---|---|---|
| GET | `/public/villages` | anyone | Villages for the registration picker (id, names, GP, taluka, district) |
| POST | `/auth/register` | anyone | `{name, phone, pin, village_id}` → creates a `villager`, returns tokens. `409 PHONE_ALREADY_REGISTERED` |
| POST | `/auth/login` | all roles | `{phone, pin}` → `{access_token, refresh_token, expires_in}` |
| POST | `/auth/refresh` | all | `{refresh_token}` → new pair |
| GET | `/me` | all | `{id, name, phone, is_admin, roles:[{role, level, village_id, village_name_*, taluka, district, valid_from, valid_to}]}` |
| POST | `/admin/users` | admin | `{name, phone, pin, role, village_id? , taluka?, district?}`. Village roles need `village_id`; `sdo` needs `taluka`+`district`; district roles need `district` |
| GET | `/admin/users` | admin | All accounts with role and jurisdiction |

### Cases
| Method | Path | Who | Purpose |
|---|---|---|---|
| POST | `/villages/{village_id}/cases` | `villager` / `gram_sabha` of the village | `{claim_type: "ifr" \| "cr" \| "cfr"}` → new case with an empty form |
| GET | `/cases/mine` | anyone | Cases I opened |
| GET | `/villages/{village_id}/cases` | any role covering the village | Cases of the village I may see |
| GET | `/review/queue` | `gram_sabha`, `sdo`, district officers | Cases waiting for **my** approval, oldest first |
| GET | `/cases/{id}` | who may see it | Case summary (below) |
| GET / PUT | `/cases/{id}/form-a` · `/form-b` · `/form-c` | read: who may see it · write: claimant in `draft` | The form for that claim type (`409 NOT_A_FORM_x_CASE` on the wrong one) |
| GET | `/forms/form-b/fields` · `/forms/form-c/fields` | logged in | Vocabularies for building the screens |
| GET / POST | `/villages/{village_id}/members` | read: any role · add: `gram_sabha` | Gram Sabha roster (Form C member sheet) |
| PATCH | `/members/{id}` | `gram_sabha` | Correct or deactivate a member |

**Case summary** (every case endpoint and workflow action returns it):
```json
{ "id": "…", "claim_type": "ifr", "form": "A", "state": "district_review",
  "village_id": "…", "village_name_en": "Ozhar", "village_name_mr": "ओझर",
  "taluka": "Jawhar", "district": "Palghar", "claimant_label": "Ramu Bhoye",
  "created_by_user_id": "…", "is_mine": false,
  "allowed_actions": ["approve", "return", "reject"],
  "district_approvals": ["dfo"],
  "created_at": "…", "updated_at": "…" }
```

### Workflow
| Method | Path | Body | Who |
|---|---|---|---|
| POST | `/cases/{id}/submit` | — | the claimant, in `draft` |
| POST | `/cases/{id}/approve` | `{remarks?}` | the reviewer of the current level |
| POST | `/cases/{id}/return` | `{remarks}` | the reviewer of the current level |
| POST | `/cases/{id}/reject` | `{remarks}` | the reviewer of the current level |
| GET | `/cases/{id}/history` | — | who may see the case: `[{action, from_state, to_state, actor_name, actor_role, remarks, at}]` |
| GET | `/cases/{id}/title-draft` | — | who may see the case, from `district_review` on |

Workflow errors: `403 NOT_YOUR_LEVEL` · `403 ONLY_CLAIMANT_CAN_SUBMIT` · `409 NOT_A_DRAFT` · `409 NOT_UNDER_REVIEW` · `409 ALREADY_APPROVED` · `409 CASE_CLOSED` · `422 REMARKS_REQUIRED` (with `rule: "Rule 12A(7)"` for reject).

### Title draft
`GET /cases/{id}/title-draft` → Annexure **II** (Form A, *Title for forest land under occupation*), **III** (Form B, *Title to community forest rights*) or **IV** (Form C, *Title to Community Forest Resources*):
```json
{ "annexure": "Annexure II [Rule 8(h)]", "title": "Title for forest land under occupation",
  "status": "issued",
  "fields": { "1_holders_including_spouse": ["Ramu Bhoye", "Sita Bhoye"], "…": "…", "10_area_ha": 1.25 },
  "declaration": "This title is heritable, but not alienable or transferable …",
  "signatories": [
    {"designation": "Divisional Forest Officer / Deputy Conservator of Forests", "role": "dfo", "name": "…", "signed_at": "…"},
    {"designation": "District Tribal Welfare Officer", "role": "tribal_welfare_officer", "name": "…", "signed_at": "…"},
    {"designation": "District Collector / Deputy Commissioner", "role": "collector", "name": "…", "signed_at": "…"} ],
  "note": "Title draft prepared with VanMitra for printing and signature …" }
```
`status` is `"draft (awaiting district approval)"` until all three have approved. Field keys are numbered in the printed order of the annexure.

## 4. Form A: Claim Form for Rights to Forest Land [Rule 11(1)(a)]

| Printed item | API field |
|---|---|
| 1. Name of the claimant(s) | `claimant_names: string[]` |
| 2. Name of the spouse | `spouse_name` |
| 3. Name of father/mother | `father_mother_name` |
| 4. Address | `address` |
| 5–8. Village, Gram Panchayat, Tehsil/Taluka, District | `header.*` (read-only, from the registry) |
| 9. (a) Scheduled Tribe yes/no · (b) OTFD yes/no · spouse ST | `is_scheduled_tribe`, `is_otfd`, `spouse_is_scheduled_tribe` (`null` = not answered) |
| 10. Other family members with age | `family_members: [{name, age?, relation?}]` |
| Nature of claim on land 1–7 | `claims: {code: {extent_ha?, details}}`. Codes: `habitation` (1a), `self_cultivation` (1b), `disputed_land` (2), `patta_lease_grant` (3), `in_situ_rehabilitation` (4), `displaced_without_compensation` (5), `forest_village` (6), `other_traditional` (7) |
| 8. Evidence in support (Rule 13) | `evidence: [{rule_ref, description}]` |
| 9. Any other information | `other_information` |

The response also gives `claims[]` (all 8 items in print order, with `claimed`), `total_extent_ha`, and `extent_note` (shown when the total exceeds 4 ha, Sec 4(6); never a block). Completeness checks (advisory):
- FA-1 claimant name
- FA-2 address
- FA-3 village details
- FA-4 ST/OTFD answered
- FA-5 at least one claim item
- FA-6 at least two evidences

## 5. Demo logins (development only, PIN `123456`)

| Phone | Role | Jurisdiction |
|---|---|---|
| 9000000001 · 9000000002 | `villager` | Ozhar |
| 9000000003 | `gram_sabha` | Ozhar |
| 9000000005 | `sdo` | Jawhar, Palghar |
| 9000000006 · 9000000007 · 9000000008 | `collector` · `dfo` · `tribal_welfare_officer` | Palghar |
| 9000000004 | admin | — |
