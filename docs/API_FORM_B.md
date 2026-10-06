# API contract: Form B (Community Rights claim)

> **Owner:** Soham (backend) · **Consumer:** Kaushal (frontend) · **Status:** v1, implemented on `soham_backend`
> **Source form:** FRA Rules 2007 (amended 2012), Annexure I, **Form B: Claim Form for Community Rights** [Rule 11(1)(a) and (4)], printed page 29 of `FRARulesBook_Highlighted.pdf`.
> Live schema: `http://localhost:8000/docs` (OpenAPI). Every call needs `Authorization: Bearer <access_token>` from `POST /api/v1/auth/login`.

> ⚠️ **Roles and workflow superseded by [`API_MODULE3.md`](API_MODULE3.md)** (three levels: village user · Gram Sabha · SDO · district officers). The form fields below are unchanged.

## Who can do what

| Role | Create case | Edit Form B draft | Read |
|---|:---:|:---:|:---:|
| `facilitator` (NGO) | ✅ | ✅ (drafts only, rule R5) | ✅ |
| `frc_member` | ✅ | ✅ (FRC prepares Form B on behalf of the Gram Sabha, Rule 11(4)) | ✅ |
| `gs_secretary` | ❌ | ❌ | ✅ |
| Anyone without a role in that village | ❌ | ❌ | ❌ (404) |

## Form B field → API field

| Printed Form B item | API field | Input on screen |
|---|---|---|
| 1. Name of the claimant(s) | `claimant_names: string[]` | List of names; usually the Gram Sabha / community name |
| 1(a) FDST community: Yes/No | `is_fdst_community: bool \| null` | Yes / No (null = not answered) |
| 1(b) OTFD community: Yes/No | `is_otfd_community: bool \| null` | Yes / No |
| 2. Village · 3. Gram Panchayat · 4. Tehsil/Taluka · 5. District | `header.*` (**read-only**) | Shown, never typed: comes from the village registry |
| Nature of community rights enjoyed: | `rights: {code: {details, items[]}}` | One card per right; the user switches on the ones the community enjoys |
| ↳ 1. Community rights such as nistar [Sec 3(1)(b)] | `nistar` | |
| ↳ 2. Rights over minor forest produce [Sec 3(1)(c)] | `minor_forest_produce` | `items` = produce names (mahua, tendu…) |
| ↳ 3(a). Uses or entitlements (fish, water bodies) [Sec 3(1)(d)] | `water_bodies` | `items` = ponds / streams |
| ↳ 3(b). Grazing [Sec 3(1)(d)] | `grazing` | `items` = grazing areas |
| ↳ 3(c). Traditional resource access for nomadic and pastoralist [Sec 3(1)(d)] | `nomadic_pastoral_access` | |
| ↳ 4. Community tenures of habitat and habitation for PTGs and pre-agricultural communities [Sec 3(1)(e)] | `habitat` | |
| ↳ 5. Right to access biodiversity, intellectual property and traditional knowledge [Sec 3(1)(k)] | `biodiversity_knowledge` | |
| ↳ 6. Other traditional right [Sec 3(1)(l)] | `other_traditional` | |
| 7. Evidence in support (Rule 13) | `evidence: [{rule_ref, description}]` | List; `rule_ref` picked from the 14 Rule 13 sub-clauses |
| 8. Any other information | `other_information: string \| null` | Free text |
| Signature / thumb impression | *(none)* | On the **printed** form (rule R4); signed scan upload comes later |

### Per-right details (Maharashtra field practice, all optional)

Real Maharashtra claim files record each right in a table, *लाभ घेतलेल्या सामूहिक हक्कांचे स्वरूप*. Each entry in `rights` may carry:

| Field | Meaning | Example |
|---|---|---|
| `survey_compartment_numbers: string[]` | सर्व्हे / कं. नंबर (duplicates removed) | `["156", "157", "158"]` |
| `total_area_ha` | एकूण क्षेत्र (हे.आर.) | `748.23` |
| `common_use_area_ha` | परंपरागत सामूहिक वापराचे क्षेत्र | `600` |
| `boundaries: {east, west, north, south}` | चतु:सीमा: a landmark on each side | `{"east": "Maraban", "south": "Talav"}` |
| `annual_quantity` | परिमाण (वार्षिक) | `"As much as is available and used"` |

They come back on each claimed right in `GET`, and they fill the **Annexure III title's boundaries** (`9_boundaries`). When none are given, the title says *"As described in the claim and the Gram Sabha resolution"*.

`details` is required for a right that is switched on (1–4000 chars, any language). Leave a right **out** of `rights` if it is not claimed. `items` is optional (up to 50 short labels).

## Endpoints

### `GET /api/v1/forms/form-b/fields`
Static description: the 8 rights in printed order (code, item number, English label, section), the 14 `evidence_rules`, and `min_evidence_items` (2). Build the screen from this, not from hard-coded lists.

### `POST /api/v1/villages/{village_id}/cases`
```json
{ "claim_type": "cr" }
```
→ `201` `{id, village_id, gram_sabha_id, claim_type: "cr", state: "draft", created_at, updated_at}`. Creates an empty Form B draft. `cfr` / `ifr` → `422 CLAIM_TYPE_NOT_AVAILABLE` for now.

### `GET /api/v1/villages/{village_id}/cases`
List of cases in the village, newest first.

### `GET /api/v1/cases/{case_id}/form-b`
```json
{
  "case_id": "…", "state": "draft", "editable": true,
  "header": { "village_id": "…", "village_name_mr": "ओझर", "village_name_en": "Ozhar",
              "gram_panchayat": "Ozhar", "taluka": "Jawhar", "district": "Palghar" },
  "claimant_names": ["Ozhar Gram Sabha"],
  "is_fdst_community": true, "is_otfd_community": false,
  "rights": [
    { "code": "nistar", "form_item": "1", "label_en": "Community rights such as nistar, if any",
      "section": "Section 3(1)(b)", "claimed": true, "details": "Firewood and bamboo", "items": [] },
    { "code": "minor_forest_produce", "form_item": "2", "claimed": false, "details": null, "items": [], "…": "…" }
  ],
  "evidence": [ { "seq": 1, "rule_ref": "13(1)(a)", "description": "Nistar patrak, Revenue Dept." } ],
  "other_information": null,
  "completeness": {
    "done": 4, "total": 5,
    "items": [
      { "id": "B-5", "ok": false, "form_item": "7", "rule": "Rule 11(1)(a), Rule 13(3)",
        "message_key": "form_b.fewer_than_two_evidences" }
    ]
  },
  "updated_at": "…"
}
```
`rights` always lists **all 8** in printed order, so the screen can render them straight away.

### `PUT /api/v1/cases/{case_id}/form-b`
Body = the whole draft (partial drafts are fine; everything is optional). It **replaces** the stored draft and returns the same shape as `GET`.
```json
{
  "claimant_names": ["Ozhar Gram Sabha"],
  "is_fdst_community": true,
  "is_otfd_community": false,
  "rights": {
    "nistar": { "details": "Firewood and bamboo for houses" },
    "minor_forest_produce": { "details": "Mahua flowers and tendu leaves", "items": ["mahua", "tendu"] }
  },
  "evidence": [
    { "rule_ref": "13(1)(a)", "description": "Nistar patrak, Revenue Dept." },
    { "rule_ref": "13(1)(i)", "description": "Statement of an elder (not a claimant)" }
  ],
  "other_information": "Grazing shared with the neighbouring village."
}
```
Errors: `403` (role cannot edit), `404 CASE_NOT_FOUND`, `409 CASE_NOT_EDITABLE` (case left DRAFT), `422 VALIDATION_ERROR` (e.g. duplicate claimant name, unknown right code, bad `rule_ref`, empty `details`).

## Documentation completeness (advisory)

| ID | Checks | Form item | Rule | `message_key` when missing |
|---|---|---|---|---|
| B-1 | At least one claimant name | 1 | 11(1)(a) | `form_b.claimant_names_missing` |
| B-2 | FDST and OTFD questions both answered | 1(a), 1(b) | 11(1)(a) | `form_b.community_status_unanswered` |
| B-3 | Village, GP, taluka, district present in the registry | 2–5 | 11(1)(a) | `form_b.village_details_incomplete` |
| B-4 | At least one community right described | rights 1–6 | Sec 3(1) | `form_b.no_right_described` |
| B-5 | At least two evidence items listed | 7 | 11(1)(a), 13(3) | `form_b.fewer_than_two_evidences` |

Show it as **"Documentation completeness: 4 of 5"** plus the missing items, never as a percentage or score, and never block saving (rules R2 and BR-05). Answering "No" to both FDST and OTFD is still an *answer*: the app never judges eligibility (rule R1).

## Notes

- **Section for item 3:** the printed form cites "Section 3(1)(g)" under 3(c), but fish/water bodies, grazing and nomadic access are rights under **Section 3(1)(d)** (3(1)(g) is conversion of pattas). The API returns 3(1)(d); to be confirmed against the Gazette text before we print the PDF.
- **Labels** are English only for now. Marathi and Hindi labels go in the app's ARB files, taken from the official Marathi notification (Drive: `3. FRA AMMENDMENT 2012_Marathi.pdf`), not machine-translated.
- **Evidence** here is the *list printed on the form*. Capturing the actual scans and photos (the hash-chained evidence ledger) is Stage 2, and each entry will then link to its file.
