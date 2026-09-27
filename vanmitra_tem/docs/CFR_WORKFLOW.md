# Community Forest Resource (CFR) Claim Workflow Documentation

## Overview
This document specifies the digital implementation of the role-based Community Forest Resource (CFR) claim workflow under Section 3(1)(i) of the Forest Rights Act (FRA), 2006 for **VanMitra AI**.

---

## 1. Legal Stages & Workflow Sequence

```
[VILLAGE / GRAM SABHA] ──> [FOREST RIGHTS COMMITTEE (FRC)] ──> [JOINT FIELD VERIFICATION]
                                                                        │
                                                                        ▼
[RECORD INCORPORATION] <── [ANNEXURE IV TITLES] <── [DLC ORDER] <── [SDLC REVIEW]
```

### Stage 1: Village / Gram Sabha User
- **Action**: Create CFR Claim (`Form B`).
- **Data Captured**: State, District, Sub-Division, Gram Panchayat, Village, Community Name, Survey No., Area (Sq. Meters), Description.
- **Initial Status**: `DRAFT` → `SUBMITTED_TO_FRC`.

### Stage 2: Forest Rights Committee (FRC)
- **Action**: Inspect customary boundary, record elder statements, upload Rule 13 evidence, prepare FRC findings.
- **Data Captured**: Customary boundary description, bordering villages, Gram Sabha/FRC members present, elders involved in delineation.
- **Status Transition**: `SUBMITTED_TO_FRC` → `FRC_REVIEW` → `GRAM_SABHA_REVIEW`.

### Stage 3: Gram Sabha Review
- **Action**: Hold Gram Sabha meeting, record attendance and quorum, pass resolution.
- **Data Captured**: Meeting date, location, total voters, attendees, women attendees, quorum status, discussion notes, resolution number.
- **Status Transition**: `GRAM_SABHA_REVIEW` → `GRAM_SABHA_APPROVED` or `GRAM_SABHA_RETURNED`.

### Stage 4: Joint Field Verification
- **Action**: Forest Department Field Officer & Revenue Department Field Officer conduct independent site verification.
- **Data Captured**: Officer designation, visit date, site observations, verified area, SHA-256 digital signature hash.
- **Status Transition**: `GRAM_SABHA_APPROVED` → `FIELD_VERIFICATION_PENDING` → `FIELD_VERIFICATION_IN_PROGRESS` → `FIELD_VERIFICATION_COMPLETED` → `SDLC_REVIEW`.

### Stage 5: Sub-Divisional Level Committee (SDLC)
- **Action**: Consolidate boundary maps, verify Gram Sabha & Field reports, prepare draft record.
- **Status Transition**: `SDLC_REVIEW` → `SDLC_APPROVED` / `FORWARDED_TO_DLC` or `SDLC_RETURNED`.

### Stage 6: District Level Committee (DLC)
- **Action**: Inspect complete claim dossier & pass final order (`dlcApproved`, `dlcRemanded`, `dlcModified`, `dlcRejected`).
- **Rule**: Decision reason/remarks are mandatory for Remand, Modify, or Reject decisions.
- **Status Transition**: `FORWARDED_TO_DLC` → `DLC_APPROVED` → `ANNEXURE_IV_PENDING_DFO`.

### Stage 7: Annexure IV Title Signatures
- **Action**: Sequential 3-signatory authorization:
  1. Divisional Forest Officer (DFO / DCF)
  2. District Tribal Welfare Officer (DTWO)
  3. District Collector / Deputy Commissioner
- **Data Captured**: Signer name, designation, timestamp, SHA-256 signature hash.
- **Status Transition**: `ANNEXURE_IV_PENDING_DFO` → `ANNEXURE_IV_PENDING_TRIBAL_WELFARE` → `ANNEXURE_IV_PENDING_COLLECTOR` → `ANNEXURE_IV_COMPLETED` → `RECORD_INCORPORATION_PENDING`.

### Stage 8: Record Incorporation
- **Action**: Record Incorporation Officer enters official land revenue (7/12) and forest register references.
- **Status Transition**: `RECORD_INCORPORATION_PENDING` → `RECORD_INCORPORATED` → `COMPLETED`.

---

## 2. Demo Credentials
For testing and development:

| Role | Demo Email |
|---|---|
| Village / Gram Sabha User | `village.demo@vanmitra.gov.in` |
| Forest Rights Committee (FRC) | `frc.demo@vanmitra.gov.in` |
| Forest Field Officer | `forest.demo@vanmitra.gov.in` |
| Revenue Field Officer | `revenue.demo@vanmitra.gov.in` |
| SDLC | `sdlc.demo@vanmitra.gov.in` |
| DLC | `dlc.demo@vanmitra.gov.in` |
| DFO / DCF | `dfo.demo@vanmitra.gov.in` |
| District Tribal Welfare Officer | `dtwo.demo@vanmitra.gov.in` |
| District Collector | `collector.demo@vanmitra.gov.in` |
| Record Officer | `records.demo@vanmitra.gov.in` |
| State Level Monitoring Committee | `slmc.demo@vanmitra.gov.in` |
| Admin | `admin.demo@vanmitra.gov.in` |
