# API contract: Form C (Community Forest Resource claim) and the member roster

> **Owner:** Soham (backend) · **Consumer:** Kaushal (frontend) · **Status:** v1, implemented on `soham_backend`
> **Source form:** FRA Rules (amended 2012), Annexure I, **Form C: Claim Form for Rights to Community Forest Resource** [Sec 3(1)(i); Rule 11(1) and (4)], printed page 30 of `FRARulesBook_Highlighted.pdf`. Field reference: `1mitra.md` §6.3.
> Every call needs `Authorization: Bearer <access_token>`. Same error body as everywhere: `{error, message_key, rule?, details}`.

## Who can do what

| Role | Create CFR case | Edit Form C | Edit roster | Read |
|---|:---:|:---:|:---:|:---:|
| `facilitator` (NGO) | ✅ | ✅ (drafts only) | ❌ | ✅ |
| `frc_member` | ✅ | ✅ (FRC prepares Form C, Rule 11(4)) | ❌ | ✅ |
| `gs_secretary` | ❌ | ❌ | ✅ (Rule 11(6)) | ✅ |
| No role in the village | ❌ | ❌ | ❌ | ❌ (404 / 403) |

## Form C field → API field

| Printed Form C item | API field | Notes |
|---|---|---|
| 1. Village / Gram Sabha · 2. Gram Panchayat · 3. Tehsil/Taluka · 4. District | `header.*` (read-only) | From the village registry |
| 5. Names of Gram Sabha members with ST/OTFD status (separate sheet) | `member_sheet {total, st, otfd, members[{name, category}]}` (read-only) | Generated from the **roster** (below). "Presence of a few ST/OTFD is sufficient." |
| 5a. Resolving statement ("We, the undersigned residents … under Section 3(1)(i).") | `resolution_statement` | Starts as the printed text; FRC may edit or replace with Marathi. Sending `null` restores the printed text. |
| 5b. Map of the CFR: location and landmarks within the customary boundary, or seasonal use of landscape (pastoral); need not match legal boundaries | `area_description`, `approx_area_ha`, `pastoral_seasonal_use`, `seasonal_use_details`, `landmarks[{side, kind, name, description}]` | `side` ∈ `east, west, north, south, within` (the four boundaries, चतु:सीमा). `kind` ∈ `river, stream, spring, pond, sacred_place, sacred_grove, burial_ground, well, road, compartment_pillar, hill, other`. The GPS polygon comes in the mapping stage. |
| 6. Khasra / Compartment No.(s), if any and if known | `khasra_compartment_numbers: string[]` | **Optional by design**: never show as required. Duplicates removed, order kept. |
| 7. Bordering villages (i), (ii), (iii)… incl. sharing of resources | `bordering_villages[{name, shares_resources, sharing_details}]` | |
| 8. List of evidence in support (Rule 13) | `evidence[{rule_ref, description}]` | Same 14 `rule_ref` values as Form B |
| Signature / thumb impression | *(none)* | On the printed form (rule C4) |

## Endpoints

| Method | Path | Who | Purpose |
|---|---|---|---|
| GET | `/api/v1/forms/form-c/fields` | logged in | Default statement, boundary sides, landmark kinds, Rule 13 tags, minimums (2 general, 1 CFR) |
| POST | `/api/v1/villages/{village_id}/cases` `{"claim_type":"cfr"}` | facilitator / FRC | Opens a CFR case with an empty Form C draft (`cr` still opens Form B) |
| GET | `/api/v1/cases/{case_id}/form-c` | any role in village | Draft + member sheet + completeness |
| PUT | `/api/v1/cases/{case_id}/form-c` | facilitator / FRC | Replace the draft (only while `state = draft`) |
| GET | `/api/v1/villages/{village_id}/members[?include_inactive=true]` | any role in village | Roster |
| POST | `/api/v1/villages/{village_id}/members` `{name, gender, category}` | GS Secretary | Add member (`gender`: female/male/other; `category`: st/otfd/other) |
| PATCH | `/api/v1/members/{member_id}` `{name?, gender?, category?, active?}` | GS Secretary | Correct or deactivate (members are never deleted) |

### Example `PUT /cases/{id}/form-c`
```json
{
  "resolution_statement": null,
  "area_description": "Customary forest east and south of Ozar up to the Nagdevta stream",
  "approx_area_ha": 318.4,
  "pastoral_seasonal_use": false,
  "landmarks": [
    {"side": "east",  "kind": "stream",       "name": "नागदेवता नाला"},
    {"side": "west",  "kind": "sacred_place", "name": "वाघोबा देवस्थान"},
    {"side": "north", "kind": "road",         "name": "Jawhar road"},
    {"side": "south", "kind": "pond",         "name": "मोठा तलाव"},
    {"side": "within","kind": "sacred_grove", "name": "देवराई", "description": "Old grove near the spring"}
  ],
  "khasra_compartment_numbers": ["156", "157"],
  "bordering_villages": [{"name": "Chambharshet", "shares_resources": true, "sharing_details": "Shared grazing"}],
  "evidence": [
    {"rule_ref": "13(1)(a)", "description": "7/12 extract, survey no. 110"},
    {"rule_ref": "13(1)(i)", "description": "Statement of elders (not claimants)"},
    {"rule_ref": "13(2)(a)", "description": "Nistar patrak of the village"}
  ]
}
```

## Documentation completeness (advisory, never a score, never blocks saving)

| ID | Checks | Item | Rule | `message_key` |
|---|---|---|---|---|
| FC-1 | Village, GP, taluka, district present | 1–4 | 11(1) | `form_c.village_details_incomplete` |
| FC-2 | Roster has members, at least one ST or OTFD | 5 | Form C item 5 | `form_c.member_sheet_missing_st_otfd` |
| FC-3 | Resolving statement present | 5a | Sec 3(1)(i) | `form_c.resolution_statement_missing` |
| FC-4 | Area described | 5b | 12(1)(g) | `form_c.area_not_described` |
| FC-5 | A landmark on each of east, west, north, south | 5b | 12(1)(g) | `form_c.boundary_landmarks_missing` |
| FC-6 | At least one bordering village | 7 | 11(1)(b) | `form_c.no_bordering_village` |
| FC-7 | ≥ 2 evidences under 13(1) | 8 | 11(1)(a), 13(3) | `form_c.fewer_than_two_general_evidences` |
| FC-8 | ≥ 1 evidence under 13(2) (CFR character) | 8 | 13(2) | `form_c.no_cfr_evidence` |

Item 6 (khasra) is deliberately not checked, because the form says "if any and if known". A new draft shows **2 of 8**: FC-1 from the registry and FC-3 from the printed statement.
