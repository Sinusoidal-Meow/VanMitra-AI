# 1mitra — VanMitra Reference

> **What this file is:** the single reference for what VanMitra is, the law it implements, the institutions, forms, documents and procedure it models, and the architecture it follows. It records **no project status and no task list**. Plans, progress and decisions live in the other MD files, which must agree with this one.
>
> **Sources** (all in `documents/`, see §31): Forest Rights Act 2006 and Rules 2008 as amended 2012 (`FRARulesBook_Highlighted.pdf`, Marathi texts), Maharashtra Government Resolutions (`Imp..ALL GRs...FRA 2006.pdf`), *VanMitra CFR Claim Module Specification v1.0* (`VanMitra_CFR_Claim_Module.pdf`), *VanMitra Final Application Architecture* (`vanmitra_architecture.pdf`), *Proposed On-Ground Implementation Scheme* (`FRA_CFR_Implementation_Report (1).pdf`), the CFR reference sheet (`cfr_workflow.pdf`), a real CFR claim packet (images) and `mh_cfr_potential_villages.xlsx`.
>
> **Conventions:** `[Sec 3(1)(i)]` = section of the Act; `[Rule 12A(1)]` = FR Rules 2008 as amended 2012; `[GR 2015]` etc. = Maharashtra Government Resolution (§13.3). **STATUTORY** = the law compels it; **DERIVED** = a design decision implementing the law; **FACILITATION** = a convenience with no statutory basis.

---

## 0. VanMitra in ten lines

0.1 VanMitra is an **offline-first, community-centred digital platform** that supports the on-ground implementation of the Forest Rights Act, 2006, with special emphasis on **Community Forest Rights (CFR)** and community forest governance.
0.2 It is the **community-side evidence, workflow, GIS and governance layer**. It works alongside government processes and never replaces the Gram Sabha, FRC, SDLC, DLC, SLMC, official land survey or cadastral records.
0.3 **It never decides who receives forest rights.** It never determines eligibility, approves, rejects or vests a right.
0.4 Journey it supports: **Awareness → Rights → Claim Facilitation → Recognition → Survey & Mapping → Governance → Forest Management → Sustainable Livelihood.**
0.5 Users: tribal community members, NGO field workers, FRC, CFRMC, Gram Sabha (through its Secretary), and an authorised government coordination view.
0.6 Core claim focus: the **CFR claim (Form C, Sec 3(1)(i))** and the **Community Rights claim (Form B)**, filed in the same cycle as individual claims (Form A).
0.7 Every screen, field, state change and generated document must trace to a numbered provision of the Act, Rules or Guidelines, or be labelled facilitation.
0.8 Signed paper is the legal record. VanMitra prints statutory documents for signature and stores the signed scan.
0.9 Records are tamper-evident (hash-chained, append-only); community data is private and consent-scoped.
0.10 Pilot: **1 partner NGO + 1 village + 1 Gram Sabha**: ओझर (Ozar/Ozhar), Jawhar taluka, Palghar district, Maharashtra (§30).

---

## 1. Design principles (non-negotiable)

| # | Principle | Meaning |
|---|---|---|
| P1 | Community first | Usable by tribal communities, Gram Sabha, FRC, CFRMC members, volunteers and NGO workers; technology adapts to the community. |
| P2 | Offline first | The village must work with no network for weeks; only sync and AI assistance need connectivity. |
| P3 | Human in the loop | AI/digital system → information and recommendation → NGO facilitator → FRC/Gram Sabha verification → statutory authority → official decision. |
| P4 | Government-compatible, not government-replacing | Works around authorised processes; integrations only through authorised APIs and formal permission. |
| P5 | Traceability | Every artefact cites its provision; anything untraceable is labelled facilitation. |
| P6 | Paper is the record | Digital copies supplement, never replace, the signed paper record. |

### 1.1 The ten binding constraints (C1–C10)

| # | Constraint | Expression |
|---|---|---|
| C1 | The system never determines eligibility or approves a claim. | No decision field is writable by any role; decisions are only *recorded* from an authority order document. |
| C2 | Readiness is administrative, not legal. | Shown as **"documentation completeness: X of N items"**; never the words eligible, approved, valid or score; never a percentage. |
| C3 | Satellite and GPS output is supplementary. | Geo evidence carries `is_substitutable = false` and can never alone satisfy Rule 13(3). |
| C4 | Digital records supplement the signed paper record. | Every statutory artefact is printable with a signature/thumb-impression block; the scan of the signed original is stored. |
| C5 | Gram Sabha authority cannot be bypassed by a facilitator. | NGO roles create/draft only; submission needs an FRC actor; a resolution needs the Gram Sabha actor. |
| C6 | No committee below the Gram Sabha may decide a claim. | No block-level or beat-level decision role exists. |
| C7 | Limitation periods are never lost silently. | Every adverse order starts a visible countdown; alerts on day 30, 45, 55, 58. |
| C8 | Records are tamper-evident. | Evidence, meeting, resolution and workflow rows are append-only and hash-chained; corrections supersede. |
| C9 | Community data is not an open dataset. | Personal data, precise boundaries and elder testimony are consent-scoped; never in a public API. |
| C10 | The village works offline for weeks. | Every claim-critical operation is available offline. |

### 1.2 Wording discipline
- Readiness: "Documentation completeness: 8 of 10", never a score, probability or eligibility statement.
- Satellite change: "Potential land-use or vegetation change detected. Field verification recommended." Never "illegal encroachment detected".
- Every export carries: *"Community record prepared with VanMitra. Not a government document."*
- Participatory maps always state their provenance so they cannot be mistaken for a cadastral survey.

---

## 2. Legal foundation

### 2.1 Instruments
| Instrument | Reference |
|---|---|
| The Scheduled Tribes and Other Traditional Forest Dwellers (Recognition of Forest Rights) Act, 2006 | Act 2 of 2007, Gazette 2 Jan 2007 |
| FR Rules, 2007 | G.S.R. 1(E), 1 Jan 2008 |
| FR Amendment Rules, 2012 | G.S.R. 669(E), 6 Sep 2012 (inserted Rules 2A, 12A, 12B, Form C, Annexures IV–V; changed FRC and quorum composition) |
| MoTA Guidelines on implementation | Including letter 23011/16/2015-FRA (23 Apr 2015) on CFR management plans |
| Maharashtra GRs | §13.3 |
| Marathi titles | Act: *अनुसूचित जमाती व इतर पारंपारिक वन निवासी (वनहक्क मान्य करणे) अधिनियम, 2006*; Amendment: *सुधारणा नियम, 2012* |

### 2.2 Key definitions
| Term | Definition |
|---|---|
| Community Forest Resource [Sec 2(a)] | Customary common forest land within the traditional or customary boundaries of the village, or the seasonal use of landscape for pastoral communities, **including reserved forests, protected forests and protected areas** (sanctuaries, national parks) to which the community had traditional access. |
| Gram Sabha [Sec 2(g)] | Village assembly of all adult members, with full and unrestricted participation of women. In non-Panchayat areas: padas, tolas and traditional village institutions. |
| Forest-dwelling ST [Sec 2(c)] | Members/community of Scheduled Tribes who primarily reside in and depend on forests or forest lands for bona fide livelihood needs. |
| OTFD [Sec 2(o)] | Any member/community who for **at least three generations (generation = 25 years) prior to 13 Dec 2005** primarily resided in and depended on forest land for bona fide livelihood needs. |
| Minor forest produce [Sec 2(i)] | All non-timber forest produce of plant origin: bamboo, brushwood, stumps, cane, tussar, cocoons, honey, wax, lac, tendu/kendu leaves, medicinal plants, herbs, roots, tubers and the like. |
| Cut-off date [Sec 4(3)] | Forest land occupation must be prior to **13 December 2005**. |
| Disposal of MFP [Rule 2(1)(d), 2012] | Includes collection, processing, storage, value addition, transport and sale, individually or through cooperatives/federations. |

### 2.3 Rights recognised [Sec 3(1)]
| Clause | Right | Claimed in |
|---|---|---|
| 3(1)(a) | Hold and live in forest land under individual or common occupation for habitation or self-cultivation | Form A |
| 3(1)(b) | Community rights such as **nistar**, by whatever name called (incl. erstwhile princely states, zamindari) | Form B |
| 3(1)(c) | Ownership, access to collect, use and dispose of **minor forest produce** traditionally collected within or outside village boundaries | Form B |
| 3(1)(d) | Other community uses or entitlements: **fish and products of water bodies, grazing** (settled or transhumant), **traditional seasonal resource access of nomadic or pastoralist communities** | Form B |
| 3(1)(e) | Community tenures of **habitat and habitation for PTGs** and pre-agricultural communities | Form B |
| 3(1)(f) | Rights in or over **disputed lands** | Form A |
| 3(1)(g) | Conversion of **pattas, leases or grants** on forest land into titles | Form A |
| 3(1)(h) | Settlement and conversion of **forest villages**, old habitations, unsurveyed villages into revenue villages | Form A / Rule 12B(5) |
| 3(1)(i) | **Right to protect, regenerate, conserve or manage any community forest resource** traditionally protected for sustainable use | **Form C** |
| 3(1)(j) | Rights recognised under State law, Autonomous District Council law or tribal customary law | Form B |
| 3(1)(k) | Access to **biodiversity**, community right to intellectual property and **traditional knowledge** | Form B |
| 3(1)(l) | Any other traditional right customarily enjoyed (excluding hunting/trapping) | Form A / B |
| 3(1)(m) | **In situ rehabilitation** incl. alternative land where illegally evicted/displaced without compensation before 13 Dec 2005 | Form A |
| Sec 4(8) | Land from where displaced without land compensation | Form A |
| Sec 3(2) | Diversion of forest land (< 1 ha, ≤ 75 trees/ha) for 13 public facilities (schools, dispensary, anganwadi, fair-price shop, electric/telecom lines, tanks/minor water bodies, drinking water, pipelines, rain-water harvesting, minor irrigation, non-conventional energy, skill centres, roads, community centres) | Not a claim; DFO-approved with Gram Sabha recommendation |

### 2.4 Character of the rights
- **Individual title (Annexure II):** heritable but **not alienable or transferable** [Sec 4(4)], capped at the area under actual occupation and **4 ha** [Sec 4(6)].
- **CFR title (Annexure IV):** a community title **held by the Gram Sabha**. No conditions may be imposed beyond the Act and Rules [Rule 8(i)].
- **Protection:** no eviction until recognition and verification are complete [Sec 4(5)].
- **Duties of holders and Gram Sabha [Sec 5]:** protect wildlife, forest, biodiversity, catchments and water sources, and habitat. Regulate access and stop destructive practices.
- **Offences and cognizance [Sec 7, 8]:** contravention by an authority or officer is an offence. No court takes cognizance unless a 60-day notice was given to the SLMC and it did not proceed.

### 2.5 Provision-to-feature traceability (controlling table)
| Provision | Law requires | VanMitra feature |
|---|---|---|
| Sec 6(1) | Gram Sabha initiates, receives, consolidates, verifies, maps, resolves, forwards to SDLC | Gram Sabha is case owner; no case leaves `GS_RESOLVED` without a linked resolution and boundary |
| Rule 2A | Hamlets, unrecorded settlements, forest/taungya villages listed and consolidated | Village registry with `parent_village` hierarchy and `consolidation_status` |
| Rule 3(1) | FRC 10–15, ≥ ⅔ ST, ≥ ⅓ women | FRC screen refuses invalid composition; certificate generated |
| Rule 3(3) | Claimant-member must not verify own claim | Conflict-of-interest flag; sign-off hidden; recusal recorded |
| Rule 4(1)(e)(f)(g) | Gram Sabha constitutes protection committee (CFRMC), approves plan, transit permits, income use | Post-title CFRMC module; plan stored against a resolution |
| Rule 4(2) | Quorum ½ members, ⅓ of present women, 50% claimants; simple majority | Quorum calculator blocks resolution if any test fails; arithmetic stored |
| Rule 6(b) | SDLC provides forest/revenue maps and electoral rolls | Tracked request-and-receipt; blocking dependency |
| Rule 11(1)(a) | Claims within 3 months with ≥ 2 Rule 13 evidences; extension with written reasons | Claim-window timer; extension needs reason + resolution reference |
| Rule 11(1)(b) | CFR determination date; intimate adjoining Gram Sabhas and SDLC | Intimation register; adjacency proposed from polygons |
| Rule 11(3) | Every claim acknowledged in writing | Acknowledgement receipt with serial number |
| Rule 11(4) | FRC prepares Form B and Form C on behalf of the Gram Sabha | Form B/C authored by FRC role (RBAC) |
| Rule 11(6) | GP Secretary is Gram Sabha Secretary | GP Secretary is a first-class signing actor for meetings |
| Rule 12(1)(a)–(e) | Site visit after intimation; physical verification; pastoralist/PVTG presence; landmarks | Field-verification workflow, intimation record, presence register, mandatory landmarks |
| Rule 12(1)(f)(g) | Boundary with elders; CFR map with landmarks and 13(2) evidence; simple-majority resolution; may include RF/PF/NP/WLS | Named elders recorded; map invalid without ≥ 1 13(2) evidence and 1 landmark per segment |
| Rule 12(3) | Conflicting boundaries → joint FRC meeting → SDLC | Overlap detection → `DISPUTE` sub-state → joint-meeting record → referral |
| Rule 12(4) | Authenticated copies of records on written request | Records-request generator with follow-up clock |
| Rule 12A(1)(2) | Forest + Revenue officials present and sign; if absent twice, Gram Sabha decision final | Signature block per department or formally recorded absence; second-absence finality note |
| Rule 12A(3) | Modification/rejection communicated in person; petition in 60 days (+30) | Limitation clock from **date of personal communication** |
| Rule 12A(6) | Incomplete resolutions remanded, not rejected | `REMANDED_TO_GS` is a distinct state |
| Rule 12A(7) | DLC records detailed reasons, supplies copy | Order stored; absence of reasons flagged as appeal ground |
| Rule 12A(9) | Final map and record incorporation within the state cycle or 3 months | `RECORD_UPDATED` state with 3-month clock |
| Rule 12A(10) | No rejection on merely technical grounds; no lower committee/officer decides | No role can reject below SDLC; technical-ground order is an appeal trigger |
| Rule 12A(11) | Consider Rule 13 evidence; no particular documentary form; fine receipts etc. not sole basis; satellite only supplements | No mandatory document type; satellite non-substitutable |
| Rule 12B(3)(4) | CFR recognised in all forest villages; reasons recorded where not | District coverage report of omissions |
| Rule 13(3) | Consider more than one evidence | Two-evidence sufficiency check |
| Rule 8(i) | Certified copy of record and Annexure IV title to Gram Sabha | Case cannot close until certified copy uploaded and sealed |
| Rule 16 | Post-claim support and scheme convergence | Convergence register |
| Sec 7, 8 | 60-day notice to SLMC before cognizance | Section 8 notice generator with 60-day clock |

---

## 3. Claim types

| Type | Right | Form | Title | Holder |
|---|---|---|---|---|
| **IFR**: Individual Forest Rights | Sec 3(1)(a)(f)(g)(m), 4(8) | **Form A** [Rule 11(1)(a)] | Annexure II [Rule 8(h)] | Individual/family; heritable, not alienable; ≤ 4 ha |
| **CR**: Community Rights | Sec 3(1)(b)(c)(d)(e)(j)(k)(l); Rule 2(1)(ca) | **Form B** [Rule 11(1)(a), 11(4)] | Annexure III [Rule 8(h)] | Community |
| **CFR**: Community Forest Resource | Sec 3(1)(i) with 2(a) | **Form C** [Rule 11(1), 11(4)] (inserted 2012) | Annexure IV [Rule 8(i)] | Gram Sabha; carries Sec 5 duties and the Rule 4(1)(e) committee obligation |

A village normally files all three in the same claim cycle. They share one Gram Sabha meeting, quorum record and evidence pool. The data model therefore has one `case` table discriminated by `claim_type ∈ {IFR, CR, CFR}`.

---

## 4. Institutions and officers

### 4.1 Village level
| Institution | Constitution | Function | Basis |
|---|---|---|---|
| **Gram Sabha** (ग्रामसभा) | All adult members; convened by the Gram Panchayat | Initiates determination; receives, consolidates, verifies claims; approves map; passes resolution; forwards to SDLC; holds CFR title; regulates access | Sec 2(g), 6(1), 5; Rule 4 |
| **Forest Rights Committee, FRC** (वनहक्क समिती) | 10–15 members elected by the Gram Sabha in its first meeting; **≥ ⅔ ST, ≥ ⅓ women**; chair and secretary intimated to SDLC | Receives and acknowledges claims; record of claims and evidence; site visit; boundary delineation with elders; prepares Form B/C; presents findings | Rule 3, 11(2)–(4), 12(1) |
| **Secretary, Gram Panchayat** | Ex officio | Secretary to the Gram Sabha; custodian of meeting record and resolution register | Rule 11(6) |
| **CFRMC** (सामूहिक वनहक्क व्यवस्थापन समिती) | Constituted by the Gram Sabha from forest-rights holders (Maharashtra: §13.3) | Protection under Sec 5; conservation and management plan integrated with working/micro plan; under Gram Sabha control | Rule 4(1)(e)(f)(g); GR 2015 |
| **Gram Panchayat** | Elected body | Convenes Gram Sabha; lists hamlets for consolidation | Rule 3(1), 2A(a) |

### 4.2 Sub-Divisional Level Committee (SDLC) [Sec 6(3), Rule 5]
| Member | Department | Position | Role |
|---|---|---|---|
| Sub-Divisional Officer (Maharashtra: SDO/Prant Officer) | Revenue | Chairperson | Signs forwarding of claims and draft record to DLC [Rule 6(j)]; presides over petition hearings [Rule 14] |
| Forest officer in charge of sub-division (RFO/ACF as designated) | Forest | Member | Forest maps; verification; departmental view on boundary |
| 3 Block/Tehsil Panchayat members nominated by District Panchayat (≥ 2 ST, ≥ 1 woman) | Panchayati Raj | Members | Community representation |
| Tribal Welfare officer in charge of the sub-division | Tribal/Social Welfare | Member | Awareness, free availability of forms, claimant interest [Rule 6(a)(k)(l)] |

SDLC functions [Rule 6]:
- (b) provide forest and revenue maps and electoral rolls
- (c) collate resolutions
- (d) consolidate maps
- (e) examine veracity
- (f) hear inter-Gram-Sabha disputes
- (g) hear petitions
- (h) coordinate inter-sub-divisional claims
- (i) prepare the block/tehsil-wise draft record
- (j) forward to the DLC through the SDO
- (l) keep Forms A/B/C freely available
- (m) ensure Gram Sabha meetings are free, open, fair and quorate

### 4.3 District Level Committee (DLC) [Sec 6(5), Rule 7]; decision final and binding [Sec 6(6)]
| Member | Department | Position | Role |
|---|---|---|---|
| District Collector / Deputy Commissioner (जिल्हाधिकारी) | Revenue | Chairperson | Final approval; signs Annexure IV; directs record correction [Rule 8(c)(f), 15(6)] |
| Divisional Forest Officer / Deputy Conservator of Forests (उपवनसंरक्षक) | Forest | Member | Signs Annexure IV; final map and record incorporation with Revenue [Rule 12A(9)] |
| 3 District Panchayat members (≥ 2 ST, ≥ 1 woman) | Panchayati Raj | Members | Community representation |
| District Tribal Welfare Officer | Tribal Welfare | Member | Signs title; ensures PVTG habitat and pastoralist claims [Rule 12B(1)(2)] |
| Secretary of the DLC | As designated | Secretary | Records reasons where no CFR right is recognised in a village [Rule 12B(4)]; Maharashtra: report to Nodal Officer, Commissioner Tribal Development, Nashik |

### 4.4 State Level Monitoring Committee (SLMC) [Sec 6(7), Rule 9]
| Member | Position |
|---|---|
| Chief Secretary | Chairperson (signs quarterly return, Annexure V) |
| Secretaries of Revenue, Tribal/Social Welfare, Forest, Panchayati Raj | Members |
| Principal Chief Conservator of Forests | Member |
| 3 ST members of the Tribes Advisory Council | Members |
| Commissioner, Tribal Welfare | Member-Secretary; receives the Sec 8 sixty-day notice |

The SLMC meets at least once every three months. Its quarterly report in Annexure V format covers [Rule 10(c)]: claims filed, accepted, rejected and pending; reasons for rejection; corrective measures; forest land covered; record updation; and CFR area managed and by whom.

### 4.5 Supporting agencies
| Agency | Why it matters |
|---|---|
| Ministry of Tribal Affairs | Nodal agency [Sec 11]; guidelines; quarterly returns |
| Maharashtra Tribal Development Department / Commissionerate, Nashik | State nodal agency; FRC/staff training; CFR omission reports |
| TRTI Pune | Training; member-secretary of the State Steering Committee [GR 2022] |
| Project Officer, ITDP (प्रकल्प अधिकारी, एकात्मिक आदिवासी विकास प्रकल्प) | District-level coordination; awareness and claim camps; Rule 16 convergence; chairs the Taluka Convergence Committee |
| Tahsildar / Circle Officer / Talathi | Revenue record incorporation; 7/12, gaothan, gochar records used as evidence |
| DILR / Bhumi Abhilekh (Maha Abhilekh) | Official measurement and cadastral survey where title exists but boundary is unmeasured |
| RFO, Round Officer, Beat Guard | Field presence at verification; compartment and working-plan records |
| Partner NGO | Facilitation, documentation, capacity building; **no statutory power**; draft-only |

Officer designations vary by state and district, so they are configuration (`authority_actor`), not code, and must be re-verified every transfer season.

---

## 5. Composition and arithmetic rules

| Rule | Test |
|---|---|
| **FRC** [Rule 3(1)] | 10 ≤ n ≤ 15; ST ≥ ceil(2n/3) (where STs exist); women ≥ ceil(n/3); chair and secretary named; members who are claimants are recused from their own claim [Rule 3(3)] |
| **Gram Sabha quorum** [Rule 4(2)] | present ≥ ceil(members/2); women present ≥ ceil(present/3); for resolutions on claims, claimants (or representatives) present ≥ ceil(claimants/2); resolution passes by simple majority of present and voting |
| **CFRMC** [GR 2015] | 5–11 members from rights holders; quorum ≥ ½ of members with ≥ ⅓ of present women; chair, secretary, treasurer elected by majority; ≥ 1 office-bearer a woman; chair must be ST |
| **SDLC/DLC panchayat members** | 3 nominated members, ≥ 2 ST, ≥ 1 woman |

---

## 6. Forms (Annexure I) and titles

### 6.1 Form A: Claim Form for Rights to Forest Land [Rule 11(1)(a)] (नमुना-क, *वन जमिनींच्या हक्कांसाठीच्या दाव्याचा नमुना*)
1. Name of claimant(s)
2. Name of spouse
3. Name of father/mother
4. Address
5. Village
6. Gram Panchayat
7. Tehsil/Taluka
8. District
9. (a) Scheduled Tribe yes/no (attach certificate); (b) OTFD yes/no (if spouse is ST, attach certificate)
10. Other family members with age (children, adult dependents)

**Nature of claim on land:**
1. Extent occupied: (a) habitation, (b) self-cultivation [3(1)(a)]
2. Disputed lands [3(1)(f)]
3. Pattas/leases/grants [3(1)(g)]
4. Land for in situ rehabilitation or alternative land [3(1)(m)]
5. Land displaced from without compensation [4(8)]
6. Land in forest villages [3(1)(h)]
7. Any other traditional right [3(1)(l)]
8. Evidence in support [Rule 13]
9. Any other information

Signature/thumb impression.

### 6.2 Form B: Claim Form for Community Rights [Rule 11(1)(a) and (4)] (नमुना-ख, *सामूहिक हक्कासाठीच्या दाव्याचा नमुना*)
| Item | Field |
|---|---|
| 1 | Name of the claimant(s); (a) FDST community yes/no; (b) OTFD community yes/no |
| 2–5 | Village; Gram Panchayat; Tehsil/Taluka; District |
| **Nature of community rights enjoyed** | |
| 1 | Community rights such as nistar [3(1)(b)] |
| 2 | Rights over minor forest produce [3(1)(c)] |
| 3 | Community rights: (a) uses or entitlements (fish, water bodies); (b) grazing; (c) traditional resource access for nomadic and pastoralist [printed as "Sec 3(1)(g)"; the rights are those of **3(1)(d)**] |
| 4 | Community tenures of habitat and habitation for PTGs and pre-agricultural communities [3(1)(e)] |
| 5 | Right to access biodiversity, intellectual property and traditional knowledge [3(1)(k)] |
| 6 | Other traditional right [3(1)(l)] |
| 7 | Evidence in support [Rule 13] |
| 8 | Any other information |
| — | Signature/thumb impression of the claimant(s) |

**Maharashtra field practice: *लाभ घेतलेल्या सामूहिक हक्कांचे स्वरूप* (nature of community rights enjoyed).** Each right is recorded as a table row with:
- **Name of the community right** (सामूहिक हक्काचे नाव), listing what is used. For nistar: everything named in the village's nistar patrak. For MFP: bamboo, khurti, brushwood, stumps, kosa, honey, wax, lac, tendu leaves, medicines, herbs, roots and tubers, amla, hirda, beheda, ding, biba, charoli, mahua, small timber-free produce.
- **Survey / compartment numbers** (सर्व्हे/कं. नंबर), e.g. 156, 157, 158, 159, 109–112, 189.
- **Area in hectares and ares** (क्षेत्र हे.आर.), total and traditional common-use area.
- **The four boundaries** (चतु:सीमा), each by a prominent landmark: East (पूर्वेस), West (पश्चिम), North (उत्तर), South (दक्षिण).
- **Annual quantity** (परिमाण, वार्षिक), e.g. "as much as is available and used / collected / disposed of".

### 6.3 Form C: Claim Form for Rights to Community Forest Resource [Sec 3(1)(i); Rule 11(1) and 4(a)] (नमुना-ग, *सामुदायिक वन संसाधन हक्कासाठी दाव्याचा नमुना*, inserted 2012)
| Item | Field | Capture rule |
|---|---|---|
| 1 | Village / Gram Sabha | From village registry (LGD/census code); hamlets with parent village [Rule 2A] |
| 2 | Gram Panchayat | Master data, not free text |
| 3 | Tehsil/Taluka | Drives SDLC jurisdiction |
| 4 | District | Drives DLC jurisdiction |
| 5 | Names of Gram Sabha members, **attached as a separate sheet with ST/OTFD status against each**; presence of a few ST/OTFD is sufficient | Generated from the member roster; same roster feeds quorum |
| 5a | Resolving statement: "We, the undersigned residents of this Gram Sabha hereby resolve that the area detailed below and in the attached map comprises our Community Forest Resource over which we are claiming recognition of our forest rights under Section 3(1)(i)." | Standard clause in Marathi/Hindi/English, editable by FRC |
| 5b | **Attached map** of the CFR: location and landmarks within traditional/customary boundaries, or seasonal use of landscape for pastoral communities, traditionally protected/regenerated/conserved/managed; **need not correspond to existing legal boundaries** | Generated map sheet (scale, north arrow, numbered landmark legend); never coerced to cadastral/compartment lines |
| 6 | Khasra/Compartment No.(s), **if any and if known** | Optional, never presented as mandatory |
| 7 | Bordering villages (i), (ii), (iii)… incl. sharing of resources and responsibilities | Proposed from polygon adjacency, confirmed by community, cross-checked with Rule 11(1)(b) intimations |
| 8 | List of evidence in support [Rule 13] | Numbered schedule with the Rule 13 sub-clause against each item |
| — | Signature/thumb impression of the claimant(s) | Printed block; signed sheet scanned back and hash-sealed |

### 6.4 Titles
| Annexure | Title | Fields | Signatories |
|---|---|---|---|
| II [Rule 8(h)] | Title for forest land under occupation (*ताब्यात असलेल्या वनजमिनीचा मालकी हक्क*) | Holder(s) incl. spouse; father/mother; dependents; address; village/Gram Sabha; GP; tehsil; district; ST/OTFD; area; boundaries by landmarks incl. khasra/compartment; "heritable but not alienable or transferable [Sec 4(4)]" | DFO/DCF · District Tribal Welfare Officer · Collector/DC |
| III [Rule 8(h)] | Title to community forest rights (*सामूहिक वनहक्कांचे हक्क*) | Holder(s); village/Gram Sabha; GP; tehsil; district; ST/OTFD; nature of community rights; conditions if any; boundaries incl. customary boundary/landmarks/khasra | Same three |
| IV [Rule 8(i)] | Title to Community Forest Resources (*सामूहिक वन संसाधनांचे हक्कपत्र*) | Village/Gram Sabha; GP; tehsil; district; ST, OTFD or both; boundary description incl. customary boundary, prominent landmarks, khasra/compartment | DFO/DCF · District Tribal Welfare Officer · Collector/DC; **no seal or stamp prescribed**: the annexure ends at "affix our signatures"; title held by the Gram Sabha, no extra conditions |
| V [Rule 10(c)] | Quarterly report format (*त्रैमासिक अहवाल सादर करण्याचे प्रारुप*) | Claims filed/accepted/rejected/pending, rejection reasons, measures, area, record updation, CFR management | SLMC |

---

## 7. Evidence [Rule 13]

At least two evidences accompany a claim [Rule 11(1)(a)]. The Gram Sabha, SDLC and DLC consider more than one [Rule 13(3)].

### 7.1 General evidence [Rule 13(1)]
| Sub-clause | Evidence | Capture |
|---|---|---|
| 13(1)(a) | Public documents and Government records: gazetteers, census, survey and settlement reports, maps, satellite imagery, working/management/micro plans, forest enquiry reports, other forest records, record of rights by whatever name, pattas/leases, committee/commission reports, Government orders, notifications, circulars, resolutions | Scan + source (office, reference no., date); authenticated copies requested under Rule 12(4) |
| 13(1)(b) | Government-authorised documents: voter ID, ration card, passport, house tax receipts, domicile certificates | OCR field extraction; personal identifiers consent-scoped and masked in exports |
| 13(1)(c) | Physical attributes: houses, huts, permanent improvements (levelling, bunds, check dams) | Geotagged photo with bearing and description |
| 13(1)(d) | Quasi-judicial and judicial records incl. court orders and judgments | Scan with case number, forum, date |
| 13(1)(e) | Research studies, documentation of customs and traditions having the force of customary law, by reputed institutions (e.g. Anthropological Survey of India) | Bibliographic record + extract |
| 13(1)(f) | Records, maps, rights, privileges, concessions from erstwhile princely States, provinces or intermediaries | Archive scan + provenance |
| 13(1)(g) | Traditional structures establishing antiquity: wells, burial grounds, sacred places | Geotagged waypoint + photo; also a map landmark |
| 13(1)(h) | Genealogy tracing ancestry to individuals in earlier land records or recognised earlier residents | Family-tree entry linked to the record |
| 13(1)(i) | **Statement of elders other than claimants, reduced in writing** | Audio → transcript → printed, read back, corrected → signed/thumb-marked; the signed sheet is the evidence; blocked if the elder is a claimant |

### 7.2 Community forest resource evidence [Rule 13(2)]
A CFR claim with no Rule 13(2) evidence is not a CFR claim.

| Sub-clause | Evidence | Capture |
|---|---|---|
| 13(2)(a) | Community rights such as nistar, by whatever name called | Nistar records (nistar patrak), khatian-type entries |
| 13(2)(b) | Traditional grazing grounds; areas for roots, tubers, fodder, wild edible fruits and other MFP; fishing grounds; irrigation systems; water sources for human/livestock use; medicinal-plant territories of herbal practitioners | **Use-zone layer**: named polygons/points with season and user hamlets |
| 13(2)(c) | Remnants of community structures, sacred trees, groves (devrai), ponds or riverine areas, burial/cremation grounds | Geotagged waypoints + photos; promoted to landmarks |
| 13(2)(d) | Government records or earlier classification of current reserve forest as protected forest, gochar or other village common land, nistari forest | Archival record request, tracked as a dependency |
| 13(2)(e) | Earlier or current practice of traditional agriculture | Field observation + elder statement, season-tagged |

### 7.3 What committees may not do [Rule 12A(10)(11) and Explanations]
- Insist on a particular form of documentary evidence.
- Reject merely on technical or procedural grounds.
- Use fine receipts, encroacher lists, primary offence reports, forest settlement reports or similar, or their absence, as the **sole** basis of rejection.
- Treat satellite imagery or other technology as a replacement for evidence. It may only supplement.

---

## 8. The real CFR claim packet (field reference)

A Maharashtra CFR/community claim file (sample: village **Chek Sukwasi**, GP Vatrana, Gondpipri taluka, Chandrapur district) contains these eight documents:

| # | Document (as named in the file) | What it is | Evidence / provision |
|---|---|---|---|
| 1 | **7/12 दस्तावेज** (सातबारा उतारा) | Revenue record of rights for a survey number: holder (e.g. "सरकार – महाराष्ट्र शासन वन विभाग"), area (हे.आर.), crop register by year, Talathi signature and seal | 13(1)(a) |
| 2 | **नजरी नकाशा** (sketch / participatory map) | Hand-drawn village map with legend: गावठाण (settlement), रस्ता (road), विहीर (well), शेती (fields), मंदिर (temple), जंगल (forest), तलाव (pond), नाला (stream); compass; forest compartment numbers (e.g. कं.नं. 156–159) | Rule 12(1)(g); Form C item 5b |
| 3 | **निस्तार पत्रक** | Village nistar record listing customary use rights | 13(2)(a) |
| 4 | **फॉर्म 'ख' और फॉर्म 'ग'** | Form B and Form C, incl. the per-right table (survey nos., area, four boundaries, annual quantity) | Rule 11(1)(a), 11(4) |
| 5 | **बुजुर्गों के बयान**: *वडिलधाऱ्या व्यक्तींचे लेखानिविष्ट कथन* (नियम 13 कलम (1) झ अनुसार पुरावा) | Written statement of elders (non-claimants) describing the traditional-use area by its four boundaries (rivers, streams, springs, ponds, deity places); table: name, village, GP, taluka/district, signature/thumb; witnesses' attestation; FRC chair/secretary signatures | 13(1)(i) |
| 6 | **मतदाता सूची** (electoral roll) | Voter list summary for the polling part: male, female, third gender, total (e.g. 280 / 263 / 0 / 543) | Rule 6(b); Gram Sabha membership and quorum base |
| 7 | **राजस्व नकाशा** (revenue map) | Official village (मौजा) map with survey numbers, scale, Talathi and survey officer signatures | 13(1)(a); Form C item 6 |
| 8 | **सरपंचाचे प्रमाणपत्र** (Gram Panchayat certificate) | Certificate on GP letterhead that the claimants named in the community claim (total voters, e.g. 535) are ST (e.g. 50) or OTFD (e.g. 485), dependent on forest for bona fide livelihood | Form B item 1(a)(b); Form C item 5 |

---

## 9. The CFR claim procedure (14 stages)

| Stage | Owner | Statutory content | VanMitra actions | Exit criteria |
|---|---|---|---|---|
| 0 Preparation | NGO; Gram Panchayat | Awareness; hamlets identified [Rule 2A] | Village registry (LGD/census code, households, forest dependency, FRA status), hamlet hierarchy, awareness sessions with women's participation | Village profile complete; intent to claim |
| 1 FRC constitution | Gram Sabha | FRC elected; chair/secretary intimated to SDLC [Rule 3] | Composition validator; G3 certificate; SDLC intimation; conflict flags | Valid FRC; intimation dispatched |
| 2 Calling of claims | Gram Sabha | Claims called; 3-month window; CFR date fixed; adjoining Gram Sabhas and SDLC intimated [Rule 11(1)] | G1 notice, G2 intimations, timer, adjacency suggestion, G5 maps request [Rule 6(b)] | Notice displayed; intimations sent |
| 3 Claim registration | FRC | Claims acknowledged; record of claims and evidence; list of claimants [Rule 11(2)(3)] | Case created; G4 acknowledgement; evidence ledger opened | Acknowledgement number exists |
| 4 Evidence assembly | FRC + NGO | ≥ 2 Rule 13(1); Rule 13(2) evidence; elders' statements [Rule 11(1)(a), 13] | Tagged capture, OCR/STT helpers, duplicate detection, G6 records requests, gap list | Two-evidence and 13(2) checks met, or conscious Gram Sabha decision |
| 5 Boundary delineation | FRC + elders | Customary boundaries with elders [Rule 12(1)(f)] | GPS trace and waypoints; named participants (G9); landmarks; use zones | Closed, valid polygon |
| 6 Overlap reconciliation | FRCs concerned | Joint meeting; findings in writing; SDLC if unresolved [Rule 12(3)] | Intersection test → `DISPUTE`; G17; referral packet | No unresolved overlap, or referral on record |
| 7 Field verification | FRC + Forest & Revenue officials | Site visit after intimation; officials sign with designation, date, comments [Rule 12(1)(a)–(e), 12A(1)] | G7 intimation; offline form; presence register; G8 sheet with department blocks or recorded absence | Signed sheet or recorded absence |
| 8 Findings and map | FRC → Gram Sabha | Findings presented; CFR map with landmarks and 13(2) evidence [Rule 12(1)(g), 12(2)] | G14 findings; G10 map sheet; completeness summary as annexure | Findings placed before Gram Sabha |
| 9 Gram Sabha resolution | Gram Sabha | Prior notice; quorum; simple majority [Rule 4(2), 11(5); Sec 6(1)] | G11 notice; G12 live quorum sheet; G13 resolution; refuses to advance if quorum fails | Resolution with quorum proof |
| 10 Submission | FRC / GS Secretary | Resolution + claim + map to SDLC [Sec 6(1); Rule 11(5)] | G15 covering letter and page-numbered index; SDLC acknowledgement scanned | Acknowledgement captured |
| 11 SDLC examination | SDLC | Collate, consolidate, examine, hear disputes/petitions, draft record, forward via SDO [Rule 6(c)–(j)] | Status tracking; hearing notices (≥ 15 days, Rule 14(2)); remand as its own state | Draft record forwarded, or petition path |
| 12 DLC decision | DLC | Final approval; detailed reasons if not accepting [Sec 6(5)(6); Rule 8(c), 12A(7), 12B(3)] | Order capture; adverse → 60-day clock from personal communication + G16; approved → Annexure IV captured | Title issued, or order with active appeal |
| 13 Title and record | DLC; Revenue & Forest | Certified copy and Annexure IV to Gram Sabha; final map; record incorporation ≤ 3 months [Rule 8(i), 12A(9)] | Title sealed; boundary locked as title polygon; record clock; G18 survey request | `RECORD_UPDATED` with entry attached |
| 14 Post-recognition | Gram Sabha; CFRMC | CFRMC constituted; plan; transit permits, income, plan approved by Gram Sabha [Sec 5; Rule 4(1)(e)(f)(g)]; scheme convergence [Rule 16] | CFRMC module; plan against a resolution; change-detection alerts; convergence register | Continuous operation |

### 9.1 Signing officer at each stage (reference sheet)
1. **Village:** FRC chair and secretary; Secretary of the Gram Panchayat; Forest and Revenue officials on the verification proceeding [Rule 12A(1)].
2. **SDLC:** SDO (chairperson) forwards claims and draft record to the DLC [Rule 6(j)].
3. **DLC:** District Collector/DC (chairperson) [Sec 6(6)].
4. **Annexure IV:** DFO/DCF · District Tribal Welfare Officer · Collector/DC; no seal or stamp prescribed.
5. **Record incorporation [Rule 12A(9)]:** the Revenue and Forest Departments prepare the final map and enter the right in the records within 3 months.

---

## 10. Statutory clocks

| Clock | Duration | Starts from | Behaviour |
|---|---|---|---|
| Claim filing window [Rule 11(1)(a)] | 3 months | Calling of claims | Countdown; extension needs written reason + resolution |
| Petition against Gram Sabha resolution [Sec 6(2), Rule 14(1)] | 60 days | Resolution date | Visible to Gram Sabha |
| Petition against SDLC decision [Sec 6(4), Rule 15(1)] | 60 days | SDLC decision | Alerts day 30/45/55/58; draft petition |
| Petition after modification/rejection [Rule 12A(3)] | 60 days, +30 at committee's discretion | **Date of personal communication** (stored separately from order date) | Alerts; draft petition |
| Hearing notice [Rules 14(2), 15(2)] | ≥ 15 days before hearing, written + public notice | Hearing date | Shorter notice flagged as irregular |
| Gram Sabha meeting on reference back [Rule 14(4)] | Within 30 days | Receipt of reference | Reminders |
| Inter-Gram Sabha dispute [Rule 14(7)] | 30 days for mutual solution | Joint meeting called | Then SDLC decides |
| Record updation [Rule 12A(9)] | State cycle or 3 months, whichever earlier | Title issue | Open item until entry captured |
| SLMC quarterly return [Rule 10(c)] | Every 3 months | Rolling | Annexure V export |
| Section 8 notice [Sec 8] | 60 days | Service on SLMC | Last-resort; never automatic |

---

## 11. Adverse outcomes

| Situation | Provision | Response |
|---|---|---|
| Resolution incomplete / needs examination | Rule 12A(6) | `REMANDED_TO_GS`; re-verification checklist of only what was questioned; original evidence unchanged |
| Department objects after being absent | Rule 12A(2) | Re-verification re-intimated; second absence → note that the Gram Sabha decision is final, with both intimation references |
| Rejection on technical/procedural grounds | Rule 12A(10); Guidelines i(f)(g) | Appeal ground; petition cites prohibition and speaking-order requirement |
| Rejection despite ≥ 2 evidences and Gram Sabha recommendation, without reasons | Guidelines i(g) | Completeness record exported as petition annexure |
| Rejection only on fine receipts/encroacher lists/offence reports | Rule 12A(11) Expl. 1 | Named petition ground |
| Rejection only on satellite imagery | Rule 12A(11) Expl. 2 | Named petition ground |
| Title issued, boundary never measured | supports Rule 12A(9) | `SURVEY_PENDING`; G18 request to land-record authority |
| No CFR in a forest village | Rule 12B(3)(4) | Coverage report lists the omission and whether DLC Secretary's reasons were furnished |
| Contravention by an officer | Sec 7, 8 | G19 Section 8 notice with 60-day clock |

---

## 12. Generated documents (G-series)

Each is print-ready in Marathi/Hindi/English with a signature or thumb-impression block. The signed paper is scanned back and hash-sealed.

| Code | Document | Basis |
|---|---|---|
| G1 | Notice calling for claims and fixing the CFR determination date (date, 3-month window, place, acceptable evidence; date of display) | Rule 11(1)(a)(b) |
| G2 | Intimation to adjoining Gram Sabhas and SDLC (villages from adjacency, date, boundary-walk invitation; dispatch date) | Rule 11(1)(b) |
| G3 | FRC constitution certificate (members with ST status and gender, arithmetic proof, chair/secretary, SDLC intimation) | Rule 3(1)(2) |
| G4 | Claim acknowledgement receipt (serial, date, claimant/Gram Sabha, claim type, documents received) | Rule 11(3) |
| G5 | Request to SDLC for forest/revenue maps and electoral rolls | Rule 6(b) |
| G6 | Request for authenticated copies of records | Rule 12(4) |
| G7 | Intimation of site visit to claimant and Forest Department | Rule 12(1) |
| G8 | Field verification proceeding sheet (observations, evidence seen, participants, Forest/Revenue signature blocks or recorded absence + intimation reference) | Rule 12(1)(a)–(e), 12A(1) |
| G9 | Participatory boundary delineation record (named elders/members, segments, landmarks, date) | Rule 12(1)(f) |
| G10 | CFR map sheet (boundary, numbered landmarks, bordering villages, use zones, scale, north arrow, resolution reference) | Rule 12(1)(g) |
| G11 | Gram Sabha meeting notice and agenda | Rule 4, 11(5) |
| G12 | Attendance and quorum sheet (registered, present, women, claimants; three tests) | Rule 4(2) |
| G13 | Gram Sabha resolution (number, date, agenda, discussion, decision, votes, approval of claim and map, direction to forward) | Sec 6(1); Rule 12(1)(g) |
| G14 | FRC findings report | Rule 12(2) |
| G15 | Submission covering letter and page-numbered index | Rule 11(5) |
| G16 | Petition to SDLC/DLC (grounds, communication date, limitation calculation, relief) | Rules 14, 15; 12A(3) |
| G17 | Joint meeting record for conflicting claims | Rule 12(3); 14(7) |
| G18 | Survey and measurement request | supports 12A(9) |
| G19 | Section 8 notice to the SLMC | Sec 8 |
| G20 | Complete case file export (single indexed PDF) | Facilitation |
| — | Form A / B / C with annexed member sheet and evidence schedule | Rule 11 |

Documents received from authorities: SDLC acknowledgement; forest and revenue maps and electoral rolls [6(b)]; draft record [6(i)(j)]; orders of modification, rejection or remand with reasons [12A(3)(6)(7)(10)]; Annexure IV title and certified copy [8(i)]; final map and record-incorporation entry [12A(9)].

---

## 13. After recognition

### 13.1 Record incorporation and survey
- Revenue and Forest Departments prepare the final map and incorporate the right in revenue and forest records [Rule 12A(9)]. In Maharashtra the Forest Department is responsible for the final CFR map [GR 2022].
- Where a title exists but the area is unmeasured or the boundary unclear, the case is **survey pending**. A formal request goes to the competent land-record authority (DILR / Bhumi Abhilekh), with follow-up tracking.

### 13.2 MFP rights after recognition
- Collection is free of all royalty and fees.
- The transit permit is issued by the Rule 4(1)(e) committee or a person authorised by the Gram Sabha.
- The Gram Sabha approves transit permits, the use of sale income and changes to the plan [Rule 4(1)(g)].
- The CFRMC must ensure MFP is not sold below the MSP set for 12 MFP items [GR 2015].

### 13.3 Maharashtra Government Resolutions
| # | Number / date | Department | Subject | Key directions |
|---|---|---|---|---|
| 1 | वहका-2014/प्र.क्र.66/का-14, **24 Jun 2015** | Tribal Development | Constitution and functioning of CFRMC [Rule 4(1)(e)] | CFRMC is the Gram Sabha's executive committee (§5): 17 functions incl. plan, integration with FD plans, rules, budget, reports to Gram Sabha, records, biodiversity register, works board, photos. No registration needed. **Joint bank account** of chair/secretary/treasurer (one a woman), any two sign with Gram Sabha approval; account-payee cheques. Accounts audited by Zilla Parishad Local Fund Auditor. Urgent meetings by दवंडी (announcement) half an hour before. |
| 2 | वहका-2017/प्र.क्र.77/का-14, **6 Jul 2017** | Tribal Development | Preparation of CFR conservation and management plans | Gram Sabha prepares a simple plan; its decisions final and binding; plan merges with FD micro/working plan (inconsistent FD provisions deemed deleted); copy to DCF; no plantation or felling in the CFR area without Gram Sabha permission. Model resolution and plan format below. |
| 3 | मग्रारो-2019/प्र.क्र.144/मग्रारो-01, **30 Nov 2021** | Planning (EGS) | Gram Sabhas with recognised CFR as **MGNREGA implementing agency** | CFRMC as executive body. Gram Sabha work list goes to the GP, forwarded to the Panchayat Samiti within 15 days, and into the labour budget within 45 days. Gram Sabha selects the Mate. Barefoot technician from local youth (job card, 12th pass). Technical sanction by JE (construction) or Agriculture Extension Officer (plantation). Payments to a "ग्रामसभा …(रोहयो)" account. Monitoring by BDO/PO ITDP/DPC, SECURE software and social audit. |
| 4 | वहका-2021/प्र.क्र.187/का-14, **12 Sep 2022** | Tribal Development | **Taluka Convergence Committee**; revised District Convergence Committee and State Steering Committee | Taluka committee: chair PO ITDP, co-chair Tahsildar, line officers, 1 NGO, 1 woman + 1 man from the Gram Sabha; reviews monthly. District committee: chair Collector, co-chair CEO ZP, vice-chair DCF; monthly; may use the 5% PESA fund. State Steering Committee: ACS/PS TD; member-secretary Commissioner TRTI Pune. ₹12,000 per CFR claim (₹3,000 CFRMC training; ₹1,000 district; ₹2,000 taluka; ₹6,000 printing/stationery/CFR board). CFRMC does शिवारफेरी (area walk), lists works, puts up a CFR board (name, area, map, boundaries). Timeline: plan in 3 months → taluka returns in 1 month → district in 2 months. |
| 5 | वहका-2023/प्र.क्र.218/का-14, **13 Mar 2024** | Tribal Development | Government schemes to forest-rights holders [Rule 16] | Awareness; individual benefits without delay; area-wise clusters; time-bound taluka plans approved by the district committee; annexure of 133 schemes/works. |

**CFR conservation and management plan format [GR 2017]**
- **Header:** Gram Sabha, GP, taluka, district, date.
- **Resolution clauses:** plan period; alignment with the FD plan; copy to DCF; Gram Sabha's right to revise; no plantation or felling without permission.
- **Sections:**
  1. Current status: area per government records (ha), GPS area, compartment no., local names, % dense / open / grass / plantation / degraded / barren, 5–10 common species, animals, water bodies, past practices.
  2. Needs: fuelwood, grazing, house timber, tendu, bamboo, mahua, charoli, honey, coupe timber, sacred sites, catchment.
  3. Threats.
  4. Protection, regeneration and penalty rules.
  5. Gram Sabha's own contribution.
  6. Support expected from FD, NGOs and others.
  7. Duration and revision.

**State figures cited:**
- 15,002 village FRCs [GR 2015].
- 11,425 CFR claims received and 8,433 approved by DLCs as of Jul 2022 [GR 2022].
- More than 5,000 villages with recognised CFR [GR 2021].

### 13.4 Livelihood
**Pathway:** CFR area → resource survey → community knowledge and traditional skills → product identification → sustainability assessment → value addition → market opportunity → community income.

**Village Resource and Livelihood Profile:** available resources, seasonal availability, community skills, potential products, buyers/market connections, value-addition opportunities, sustainable utilisation plans.

---

## 14. Platform architecture

### 14.1 Eight functional layers
| Layer | Contents |
|---|---|
| User interface | Community, NGO, FRC, CFRMC, Gram Sabha, Admin |
| Community services | Awareness, village profile, member registry |
| FRA/CFR case management | Claims, evidence, documents, workflow, tracking |
| Land & GIS management | GPS, survey status, boundaries, maps, satellite |
| Gram Sabha governance | Meetings, attendance, resolutions, CFR decisions |
| CFR management & livelihoods | Resources, forest products, skills, markets |
| AI & decision support | RAG, OCR, voice, evidence assistance, alerts |
| Data & integration | PostgreSQL, PostGIS, offline sync, APIs, audit |

### 14.2 The seventeen modules
| # | Module | Scope |
|---|---|---|
| 1 | FRA & CFR Awareness & Community Mobilisation | Knowledge centre (what FRA/IFR/CR/CFR are; roles of Gram Sabha and FRC; CFR process; post-recognition duties); Marathi/Hindi/English/tribal languages; text, audio, illustration, video, voice guidance, process diagrams. Awareness dashboard: sessions, participants, women, households, questions, potential communities. |
| 2 | Village & Community Registry | Village profile: ID, name, GP, taluka, district, state, population, households, connectivity, forest dependency, FRA status, CFR status. Institution registry: Gram Sabha, FRC, CFRMC, representatives, authorised NGO facilitators. |
| 3 | FRA/CFR Digital Case Management | Every case has a unique identity (IFR / CR / CFR under each village): claimant/community information, claim type, documents, evidence, land/forest information, field verification, Gram Sabha record, submission, institutional status, survey status, final outcome. |
| 4 | Evidence & Document Management | Categories: identity → residence → community → historical → land/forest → field → Gram Sabha documents. Metadata: document ID, case ID, type, upload date, uploaded by, verification status, verified by, remarks. |
| 5 | AI-Assisted Claim & Document Support | OCR, classification, field extraction, duplicate detection; voice (speech → text → structured → field-worker verification); knowledge assistant (next step, missing documents, status meaning); claim readiness indicator (administrative, **not a legal approval score**). |
| 6 | Step-by-Step Institutional Workflow Tracker | Community preparation → FRC/Gram Sabha → verification → SDLC → DLC → decision/recognition; per case: current stage, previous stage, submission date, pending action, documents submitted, next action. |
| 7 | Land Survey & Boundary Coordination | Survey Status Management: right/title status → survey completed? Yes → official map; No → survey pending → issue identification → application → submission → follow-up. |
| 8 | GIS & Geospatial Land Management | Layers: village boundary, forest area, CFR boundary, community use areas, water resources, paths, natural resources, traditional use areas, community management zones. |
| 9 | Participatory Mapping | Community knowledge + field GPS + existing records + survey info → preliminary map → community review → Gram Sabha validation → authorised/verified spatial record. GPS points, walking tracks, landmarks, photos, water sources, forest-use areas, traditional locations. |
| 10 | Official Survey vs Community Mapping | Every boundary is classified (§17.2). |
| 11 | Satellite & Forest Change Monitoring | Verified CFR boundary → polygon → Sentinel imagery → periodic change analysis → potential change → alert to CFRMC/NGO → human field verification. |
| 12 | Gram Sabha Digital Governance | Meeting date, location, agenda, purpose; registered, present, women present, participation requirements → meeting record. |
| 13 | Digital Resolution Management | Resolution ID, meeting ID, date, agenda, discussion, decision, text, supporting documents, verification, history; linkable to a claim, land issue, survey request, management decision or livelihood activity. |
| 14 | Tamper-Evident Record System | Hash chain: meeting → resolution → next record; detects modification; blockchain not required. |
| 15 | CFR Resource Management | CFRMC dashboard: area, resources, forest products, seasonal calendar, activities, decisions, monitoring, livelihood opportunities. |
| 16 | Village Resource & Livelihood Assessment | §13.4 profile. |
| 17 | Village Opportunity Engine (future) | Resources + skills + seasonality + products + market → suggestions (value-added products, training, cooperative activities) for community discussion only. |

**Architecture summary (20 components):**
1–16 as above, plus:
- 17 NGO Field Implementation Dashboard
- 18 Government/Institutional Coordination Layer
- 19 Offline Synchronisation Architecture
- 20 Privacy, Security and Role-Based Access

### 14.3 Stakeholder interfaces
| Interface | Functions |
|---|---|
| Tribal community member | My Village, My Rights Information, My Claim, My Documents, My Land, Gram Sabha, Village Forest, Help & Support; view authorised records, meetings, next step |
| NGO field worker | Villages, households, claims, documents, field verification, mapping, Gram Sabha, follow-up tasks; onboard villages, register cases, collect evidence, capture GPS, prepare meeting records |
| FRC | Claim list, evidence checklist, verification records, village documentation, claim readiness, Gram Sabha linkage, pending actions |
| CFRMC | CFR area, forest resources, management activities, village decisions, resource survey, livelihood opportunities, monitoring alerts |
| Gram Sabha | Upcoming meetings, agenda, attendance, participation statistics, resolutions, village claims, CFR map, decisions |
| Government coordination | Controlled dashboard, only where officially authorised: survey-pending cases, application preparation, verified documentation packets, status updates |

### 14.4 System roles and permissions
| Role | Held by | Can | Cannot |
|---|---|---|---|
| `community_member` | Adult village member | View own and village claim status; upload own documents with assistance; awareness; published Gram Sabha records | Edit a claim; view others' documents; see precise boundary coordinates |
| `ngo_facilitator` | Trained NGO worker | Onboard villages; create draft cases; capture evidence and GPS; prepare meeting papers; run readiness checklist; generate letters | Sign a verification; record a resolution; mark submitted; alter a signed artefact |
| `frc_member` | Elected FRC member | Acknowledge claims; verify evidence; site visit; delineate boundary; author Form B/C; record findings | Verify a claim in which they are a claimant [Rule 3(3)]; pass a resolution |
| `frc_chair` / `frc_secretary` | FRC office bearers | Sign findings and Form C packet; correspond with SDLC | Decide a claim |
| `gs_secretary` | GP Secretary | Create meetings; record attendance and quorum; record and publish resolutions | Alter evidence or verification records |
| `cfrmc_member` | Rule 4(1)(e) committee | Post-title plan, resource register, monitoring responses | Anything in the pre-title workflow |
| `authority_viewer` | SDLC/DLC/SLMC officer where authorised | Read submitted packet; download evidence bundle; record an acknowledgement | Edit community data; the module never becomes the official file |
| `admin` | Implementation team | Configure districts, actors, master data, releases | Edit case content or ledger rows |

### 14.5 Navigation
- **Home**
- **FRA & CFR Awareness**
- **My Village**
- **Claims & Cases:** Documents, Evidence, Field Verification, Status
- **My Land / CFR Map:** Boundary, Survey Status, Forest Monitoring
- **Gram Sabha:** Meetings, Attendance, Resolutions
- **CFR Management:** Resources, Activities, Monitoring
- **Livelihood Opportunities**
- **Help & NGO Support**

### 14.6 End-to-end journey (14 phases)
1. Awareness
2. Village & community onboarding
3. Identification of potential rights
4. Claim / CFR case creation
5. Document & evidence collection
6. Field verification & participatory mapping
7. Gram Sabha discussion & resolution
8. Statutory process tracking
9. Right recognition
10. Survey status check
11. Survey coordination if pending
12. Geospatial CFR map
13. CFRMC forest management
14. Resource & livelihood development

---

## 15. CFR claim module architecture

### 15.1 Five layers
| Layer | Role |
|---|---|
| 1 Client | Flutter app, offline store, capture, maps, sync |
| 2 Application | Legal workflow core: auth/scoping, state machine, rule engines, clocks, ledger |
| 3 Assist (**advisory, removable**) | OCR, speech-to-text, duplicate detection, knowledge assistant: switching it off changes nothing legal |
| 4 Data & Geo | PostgreSQL + PostGIS, object storage, backups |
| 5 Statutory interface | Every touchpoint with the law: document generation, correspondence, order capture, signed-scan intake, authority register |

### 15.2 Claim state machine
| State | Owner | Meaning | Next |
|---|---|---|---|
| `DRAFT` | NGO / FRC | Case created; nothing statutory yet | `EVIDENCE_COLLECTION` |
| `EVIDENCE_COLLECTION` | FRC | Rule 13 ledger open; acknowledgement issued | `MAPPING_IN_PROGRESS` |
| `MAPPING_IN_PROGRESS` | FRC + elders | Boundary walk, use zones | `FRC_VERIFICATION`, `DISPUTE_JOINT_HEARING` |
| `DISPUTE_JOINT_HEARING` | FRCs concerned | Overlap [Rule 12(3)] | `MAPPING_IN_PROGRESS`, SDLC referral |
| `FRC_VERIFICATION` | FRC + departments | Site visit and proceeding | `GS_READY` |
| `GS_READY` | FRC | Findings and map ready | `GS_RESOLVED` |
| `GS_RESOLVED` | Gram Sabha | Resolution with quorum proof | `SUBMITTED_SDLC` |
| `SUBMITTED_SDLC` | SDLC office | Packet delivered and acknowledged | `SDLC_UNDER_EXAM` |
| `SDLC_UNDER_EXAM` | SDLC | Veracity examination | `SDLC_FORWARDED`, `REMANDED_TO_GS`, `MODIFIED_REJECTED` |
| `SDLC_FORWARDED` | SDO | Draft record to DLC | `DLC_UNDER_CONSIDERATION` |
| `DLC_UNDER_CONSIDERATION` | DLC | Final approval pending | `TITLE_APPROVED`, `REMANDED_TO_GS`, `MODIFIED_REJECTED` |
| `REMANDED_TO_GS` | FRC | Sent back for re-verification (**not rejection**) [Rule 12A(6)] | `FRC_VERIFICATION` |
| `MODIFIED_REJECTED` | SDLC / DLC | Adverse order; clock from personal communication | `PETITION_FILED` |
| `PETITION_FILED` | Claimant / Gram Sabha | Petition [Rule 14/15] | `SDLC_UNDER_EXAM`, `DLC_UNDER_CONSIDERATION` |
| `TITLE_APPROVED` | DLC | Annexure IV issued | `RECORD_UPDATED`, `SURVEY_PENDING` |
| `SURVEY_PENDING` | Land records | Title exists, measurement does not | `RECORD_UPDATED` |
| `RECORD_UPDATED` | Revenue + Forest | Right incorporated | `CFR_ACTIVE` |
| `CFR_ACTIVE` | Gram Sabha / CFRMC | Management phase | terminal for the claim module |

Every transition writes a `workflow_event`: acting authority, order reference, reason text, resulting clock. States after submission change **only** from an uploaded authority order with its order date and communication date.

### 15.3 Business rules
| ID | Rule | Basis / effect |
|---|---|---|
| BR-01 | FRC: 10–15 members, ≥ ⅔ ST, ≥ ⅓ women (no STs → ≥ ⅓ women) | Rule 3(1): hard block |
| BR-02 | Claimant FRC member cannot sign verification of that case | Rule 3(3): hard block + recusal record |
| BR-03 | Resolution on a claim needs all three quorum tests | Rule 4(2): hard block |
| BR-04 | CFR case cannot be submitted without a linked resolution and Gram Sabha-approved boundary | Sec 6(1), Rule 12(1)(g): hard block |
| BR-05 | Fewer than two verified 13(1) evidences → evidentially incomplete, **not blocked** | Rule 11(1)(a), 13(3): advisory |
| BR-06 | Satellite/GPS items cannot alone satisfy the two-evidence test | Rule 12A(11) Expl. 2 |
| BR-07 | Field verification needs signatures or recorded absence with intimation reference | Rule 12A(1)(2): hard block |
| BR-08 | Every boundary segment needs ≥ 1 landmark before map sheet generation | Rule 12(1)(g): hard block on document |
| BR-09 | Overlap forces dispute sub-state until joint-meeting record or SDLC referral | Rule 12(3): hard block |
| BR-10 | Limitation clock starts from date of personal communication, never order date | Rule 12A(3) |
| BR-11 | Remand recorded as remand, never rejection | Rule 12A(6) |
| BR-12 | Adverse order records whether written reasons were supplied; absence = appeal ground | Rule 12A(7)(10) |
| BR-13 | Case cannot close without certified title copy and record-incorporation entry | Rule 8(i), 12A(9): hard block |
| BR-14 | No role may set a claim outcome; outcomes only from uploaded orders | C1 |
| BR-15 | Signed artefacts are immutable; corrections create a superseding record with a reason | Integrity |

The **only hard blocks** are procedural validity conditions (composition, recusal, quorum, signatures/absence, landmarks, overlap, submission linkage, closure). Evidentiary sufficiency only ever advises.

### 15.4 Documentation completeness (sufficiency) checks for a CFR case
| Check | Test | Rule |
|---|---|---|
| R1 | ≥ 2 verified Rule 13(1) evidences | 11(1)(a), 13(3) |
| R2 | ≥ 1 verified Rule 13(2) evidence | CFR character |
| R3 | Boundary with status `GS_APPROVED` | 12(1)(g) |
| R4 | ≥ 1 landmark per boundary segment | 12(1)(g) |
| R5 | Verification proceeding: Forest signed or absence recorded **and** Revenue signed or absence recorded | 12A(1)(2) |
| R6 | Signed elder statement **or** ≥ 3 Rule 13(1) evidences | 13(1)(i) |
| R7 | Quorum test passed | 4(2) |
| R8 | Intimation sent to every adjacent Gram Sabha | 11(1)(b) |
| R9 | Acknowledgement issued | 11(3) |
| R10 | No unresolved overlap **or** joint-meeting record exists | 12(3) |

Output: "documentation completeness: N of 10", with each unmet item named, citing its rule, and given a one-line local-language instruction.

### 15.5 Printable checklist an FRC carries to the Gram Sabha
- FRC constitution certificate [3(1)]
- Notice calling for claims with date of display [11(1)(a)]
- Intimations to adjoining Gram Sabhas and SDLC with dispatch dates [11(1)(b)]
- Written acknowledgement [11(3)]
- Form C completed and signed [11(4)]
- Gram Sabha member sheet with ST/OTFD status [Form C item 5]
- CFR map with landmarks, bordering villages and legend [12(1)(g)]
- Schedule of evidence, at least two under 13(1) [11(1)(a), 13(3)]
- Rule 13(2) evidence
- Elders' statements, signed [13(1)(i)]
- Boundary delineation record naming elders [12(1)(f)]
- Verification proceeding with signatures or recorded absence [12(1)(a), 12A(1)]
- FRC findings [12(2)]
- Meeting notice, attendance and quorum sheet [4(2)]
- Resolution approving the claim and map [12(1)(g)]
- Joint meeting record where overlap exists [12(3)]
- Covering letter and page-numbered index [11(5)]

---

## 16. Data model

🔗 = append-only and hash-chained.

| Entity | Notes |
|---|---|
| `village` / hamlet | Self-referencing hierarchy, `consolidation_status` [Rule 2A]; identified by census/LGD code, not name |
| `gram_sabha`, `gs_member` | Roster carries gender and category (ST/OTFD/other): used for FRC composition, quorum and the Form C member sheet |
| `frc`, `frc_member` | Constitution date, arithmetic proof, chair/secretary, conflict-of-interest per case |
| `case` | `claim_type ∈ {IFR, CR, CFR}`; CR/CFR owned by the Gram Sabha |
| `evidence` 🔗 | `rule_ref` from the Rule 13 vocabulary; `is_substitutable` false for satellite/GPS |
| `cfr_boundary` | Versioned geometry with source, status (draft / GS-approved / titled), accuracy statistics, landmark set |
| `gs_meeting` 🔗, `resolution` 🔗 | Quorum arithmetic stored as it was on the day, never recomputed |
| `verification_proceeding` 🔗 | Department signatures or absences, attempt number |
| `authority_order` 🔗 | Kind, order date, **communication date**, reasons given, grounds, scan |
| `workflow_event` 🔗 | From/to state, authority, order reference, reason, statutory due date, actor, timestamp |
| `authority_actor` | Designation, department, jurisdiction, committee, validity dates |
| `survey_request`, `records_request`, correspondence | Addressee, dispatch date, reminders, outcome |
| `consent` | Purpose-scoped, per data subject and per sharing event, with withdrawal |

Platform-level entity map: Village → Members, Gram Sabha (Meetings, Resolutions), FRC, CFRMC, FRA Cases (Documents, Evidence, Field Verification, Survey Status), Land Records, GIS Maps, CFR Area, Livelihood Profile.

---

## 17. Geospatial rules

### 17.1 Boundary pipeline
- **Inputs:** community knowledge, field GPS, existing records and survey information feed a draft. Topology and adjacency are tested before the community sees it. The Gram Sabha resolution converts the draft into a claimable boundary.
- **Storage and area:** geometry stored in EPSG:4326. Area computed in UTM 43N (EPSG:32643; 32644 further east) so the hectare figures are defensible.
- **GNSS quality:** each vertex records accuracy, satellite count and time. Poor points are drawn differently and listed, never smoothed.
- **Landmarks:** at least 1 per segment, in a numbered legend. Landmark descriptions, not coordinates, are what committees and titles use.
- **Legal layers:** RF/PF/sanctuary/NP layers are shown for reference. The community polygon is **never clipped** to them [Rule 12(1)(g) Expl.].
- **Overlap:** intersect/overlap tests against neighbouring draft and approved polygons. An overlap raises a Rule 12(3) dispute, not an error.
- **Versions:** boundaries are versioned. The version approved by the Gram Sabha is frozen and sealed. The Annexure IV version is frozen again and is the reference for post-title monitoring.
- **Offline maps:** vector or raster packs are loaded onto the device before field visits.

### 17.2 Boundary classification
| Status | Meaning |
|---|---|
| Officially surveyed | Legally authoritative cadastral survey completed |
| Verified spatial record available | Spatial record exists and has been verified |
| Community / participatory mapping | Mapped through community participation, not yet authorised |
| Boundary unclear / survey pending | No reliable boundary information |

GPS and mapping tools are for preliminary mapping, participation and survey coordination. They are **never** presented as a replacement for an officially authorised cadastral survey.

---

## 18. Offline synchronisation

| Rule | Reason |
|---|---|
| UUIDv7 IDs minted on the device | Field records referenceable before reaching the server; time order keeps causal order |
| Append-only ledgers never merge | Two devices adding evidence both succeed |
| Last-writer-wins on descriptive scalars only | Harmless conflicts (population, contact numbers) |
| Signed artefacts immutable | Edits after signature become a conflict item for a person, never an overwrite |
| Resumable chunked media uploads with checksums | A dropped 2G connection must not lose scans |
| Encrypted device vault; remote wipe | Devices hold identity documents and elder testimony |

Flow: mobile app → local offline database → offline work → sync queue → internet available → secure server synchronisation.

---

## 19. Integrity

```
record_hash(n) = SHA256( canonical_json(payload(n)) || record_hash(n-1) )
Chained tables : evidence · verification_proceeding · gs_meeting · resolution · workflow_event · title_artefact
Chain scope    : one chain per Gram Sabha
Anchoring      : chain head published weekly to the district instance and printed in the Gram Sabha register
Correction     : never an update; a new row supersedes and records the reason
```

---

## 20. Security, privacy and non-functional requirements

| Area | Requirement |
|---|---|
| Ownership | The community record belongs to the Gram Sabha; the operator is custodian; full export and deletion on request |
| Consent | Purpose-limited, revocable, per data subject and per sharing event (DPDP Act 2023); local language; oral consent recorded for non-literate members |
| Access | Role + jurisdiction scoping enforced in the database (row-level security), not only the API; no role can delete a ledger row |
| Access by role | Community member: own/authorised community data · NGO worker: assigned villages/cases · FRC: relevant claims · CFRMC: CFR management data · Gram Sabha: authorised community records · Admin: system administration |
| Sensitive geometry | Precise boundaries and sacred-site locations restricted; exports generalised |
| Encryption | TLS 1.3 in transit; AES-256 at rest (database, object store, device vault); managed, rotated keys |
| Audit | Every read of personal data and every transition logged with actor, time, purpose; retained for the life of the claim + 10 years |
| Availability | Fully offline in the field; server 99% in working hours; no data loss tolerated |
| Performance | Case list and readiness < 300 ms on device; district overlap check < 2 s; document generation < 10 s (async) |
| Accessibility | Large type, high contrast, icon-led navigation, audio guidance per screen, outdoor-sized tap targets |
| Device reality | 2 GB RAM Android, 720p, 2G / intermittent 4G, battery-conscious GPS |
| Retention | Claim records permanent; identity documents purged from device after sync and verification |

---

## 21. AI and assistive intelligence

| Component | Choice | Constraint |
|---|---|---|
| OCR | Tesseract 5 (eng + mar + hin); PaddleOCR for degraded scans | Output is metadata only; the scan is the evidence |
| Speech-to-text | Whisper-family, Marathi/Hindi; small on-device model where possible | The signed printed transcript is the evidence, never audio or raw transcript |
| Knowledge assistant | RAG over Act, Rules, Guidelines, State circulars, module procedure | Answers carry citations; refuses to opine on eligibility or outcome |
| Completeness checker | Deterministic rules, not a model | Never a score or probability |
| Change detection | NDVI/land-cover differencing on Sentinel-2 L2A | Post-title only; "potential change detected, field verification recommended" |

AI services → human verification. AI never replaces legal verification, community decision-making, official land survey or statutory approval.

---

## 22. Technology stack

| Tier | Component | Choice | Fallback |
|---|---|---|---|
| Client | Mobile app | Flutter 3.x, Android 8+, low-RAM devices | Kotlin native for special GNSS |
| Client | Local DB | Hive (documents, queues) + SQLite/Drift (relational queries) | SQLite only |
| Client | Offline maps | MapLibre GL + MBTiles/PMTiles | flutter_map with raster tiles |
| Client | Location | Android FusedLocation with raw GNSS accuracy | External Bluetooth GNSS |
| Client | Media | Camera with EXIF geotag, on-device compression, deskew | — |
| Client | Encryption | SQLCipher / Hive AES; keys in Android Keystore | — |
| Client | Languages | Marathi, Hindi, English; string catalogue ready for tribal languages | Audio-first UI |
| Server | API | FastAPI, Python 3.12, Uvicorn, Pydantic v2 | — |
| Server | Workflow | Explicit state machine + `workflow_event` table | Temporal/Camunda at scale |
| Server | Async | Celery + Redis | RQ / FastAPI background tasks (pilot) |
| Server | Documents | WeasyPrint (HTML → PDF) with Noto Devanagari; ReportLab for map sheets | LaTeX map sheet |
| Server | Object storage | MinIO (S3), versioned, encrypted | S3-compatible under data residency |
| Server | Identity | OIDC (Keycloak) with role + jurisdiction scopes; OTP for field users | FastAPI-native JWT (pilot) |
| Data | Database | PostgreSQL 16, row-level security | — |
| Data | Spatial | PostGIS 3.4 | — |
| Data | Vector search | pgvector | Qdrant |
| Data | Tiles | pg_tileserv / Tegola; PMTiles offline | GeoServer |
| Data | Desktop GIS | QGIS, read-only PostGIS connection | — |
| Data | Satellite | Sentinel-2 L2A, processed offline into change tiles | Manual periodic review |
| Data | Backups | WAL archiving + PITR; nightly encrypted off-site | — |
| Ops | Packaging | Docker; Compose for pilot; K3s for > 1 district | — |
| Ops | Proxy | Nginx/Traefik, TLS 1.3, HSTS, rate limits | — |
| Ops | CI/CD | GitHub Actions: lint, type check, tests, signed APK, container publish, migration dry-run | — |
| Ops | Testing | pytest with PostGIS container; golden files per statutory document; property tests for quorum/sufficiency; Flutter offline integration tests | — |
| Ops | Observability | Prometheus/Grafana, Loki, Sentry; dashboard for sync failures and approaching deadlines | — |
| Ops | Hosting | State/institutional data centre or Indian-region cloud under a data-sharing agreement | — |

---

## 23. API surface (representative)

```
POST /api/v1/villages                          village and hamlet registry
POST /api/v1/gram-sabhas/{id}/frc              constitute FRC (Rule 3(1) check)
POST /api/v1/cases                             create case {claim_type}
GET  /api/v1/cases/{id}/readiness              completeness with rule citations
POST /api/v1/cases/{id}/evidence               add evidence {rule_ref, media, captured_by}
POST /api/v1/cases/{id}/boundary               upsert draft polygon (GeoJSON)
GET  /api/v1/cases/{id}/boundary/conflicts     overlap check against neighbours
POST /api/v1/cases/{id}/verification           field verification + signature blocks
POST /api/v1/meetings                          Gram Sabha meeting
POST /api/v1/meetings/{id}/attendance          attendance; live quorum
POST /api/v1/meetings/{id}/resolutions         resolution (blocked if quorum fails)
POST /api/v1/cases/{id}/transitions            state transition {to_state, authority, order_ref}
POST /api/v1/cases/{id}/documents/{tpl}        render G-series document (pdf, language)
POST /api/v1/cases/{id}/orders                 authority order + communication date
GET  /api/v1/cases/{id}/timeline               statutory clocks and remaining days
POST /api/v1/sync/batch                        offline outbox drain (idempotent, causal)
GET  /api/v1/reports/annexure-v                SLMC quarterly return export
GET  /api/v1/reports/coverage                  forest villages with no CFR case
```

Every blocked action returns its rule: `{error, rule, message_key, details}`.

---

## 24. On-ground implementation scheme

### 24.1 Twelve implementation phases
1. FRA/CFR awareness programme
2. Identification of eligible communities
3. NGO and community facilitation
4. Digital evidence and claim preparation
5. Gram Sabha / FRC-level process
6. SDLC and DLC tracking
7. Recognition of rights
8. Survey and boundary coordination
9. Geospatial CFR mapping
10. Digital Gram Sabha governance
11. CFR management and resource assessment
12. Sustainable community livelihood development

### 24.2 Awareness programme
- **Participants:** the Forest Department/DFO office where appropriate; partner NGOs and CBOs; Gram Sabha representatives; FRC/CFRMC members; local volunteers; the VanMitra team.
- **Topics:** purpose of the FRA; IFR and CFR; eligibility; roles of the Gram Sabha and FRC; statutory stages; documentation and evidence; CFR recognition; post-recognition responsibilities.
- **Activities:** village camps, Gram Sabha sessions, small groups, app demonstrations, local-language sessions, simplified process guides, identification of potentially eligible households and communities.

### 24.3 Claim preparation workflow
1. Community identification
2. Eligibility and preliminary information
3. Required documents and evidence
4. Community forest area information
5. Participatory mapping
6. Gram Sabha discussion
7. Claim/supporting documentation (incl. joint statement/patra and the prescribed forms)
8. Verification and submission through the statutory process

**Features:** digital checklist; community-wise claim records; evidence management; uploads; geo-tagged observations; participatory land information; digital supporting records; claim readiness checklist; exportable documentation for authorities.

**Shown for every claim:** current stage; date of submission; documents submitted; verification status; pending requirements; action required from the community; status updates; final decision or recognition status.

### 24.4 Stakeholder roles
| Stakeholder | Role |
|---|---|
| Tribal and forest-dwelling community | Participate in awareness, provide information and evidence, mapping, Gram Sabha decisions, traditional knowledge, CFR management and livelihoods |
| Gram Sabha | Decision-making, approval, resolution management, participation, governance of recognised rights |
| FRC / CFRMC | Community-level processes, documentation and verification support, coordination, mapping and resource management |
| NGOs | Mobilisation, awareness, field facilitation, documentation, capacity building, pilot implementation, usability feedback |
| Government | Statutory processing, verification, official survey and measurement, land records, recognition, administrative resolution |
| VanMitra platform | Claim and document assistance, case management, tracking, GIS, survey-pending identification, Gram Sabha records, CFR monitoring, livelihood profiling |

### 24.5 Pilot
- **Structure:** 1 partner NGO + 1 village + 1 Gram Sabha + FRC/CFRMC participation + selected CFR/forest-rights cases + relevant government coordination.
- **Stages:**
  1. Baseline survey (households, existing claims, CFR status, land records, survey status, Gram Sabha practices, livelihood resources)
  2. Awareness
  3. Digital onboarding (village profile, community, claim and document records, spatial information)
  4. Claim and governance support
  5. Survey and mapping
  6. CFR management

### 24.6 Responsibility split
| Activity | Accountable | Responsible | Consulted / informed |
|---|---|---|---|
| Awareness | Gram Sabha | Partner NGO | ITDP PO; Forest Dept |
| Claim preparation and evidence | FRC | FRC + NGO | Gram Sabha |
| Boundary delineation | Gram Sabha | FRC + elders + NGO | Adjoining Gram Sabhas; Forest Dept |
| Field verification | FRC | FRC + Forest & Revenue officials | SDLC |
| Resolution and submission | Gram Sabha | GP Secretary; FRC | SDLC |
| Statutory processing | SDLC and DLC | SDO; Collector | Gram Sabha; SLMC |
| Record incorporation and survey | Collector | Revenue & Forest; land-record office | Gram Sabha |
| Platform operation | Implementation team | Implementation team | Gram Sabha as data owner |

---

## 25. Risks and mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Seen as a parallel government system | High | Label as a community record; brief SDLC/DLC; exact statutory paper formats; never claim official status |
| Readiness misread as an eligibility score | High | Wording discipline (C2), disclaimer on every export, no numeric score |
| Participatory map treated as cadastral survey | High | Provenance on every map sheet; source and status printed; survey-request workflow |
| Evidence loss through device failure/theft | High | Encrypted vault, frequent sync, chunked uploads, second custodian device per cluster |
| Personal data exposure | High | Consent scoping, row-level security, masked exports, no public API on personal/precise spatial data |
| Officer designations change or differ | Medium | `authority_actor` as configuration with validity dates; periodic re-verification |
| Limitation lost because an order was oral | Medium | Communication date mandatory when recording an order; prompt to obtain the order in writing |
| Low digital literacy | Medium | Audio-first flows, icon navigation, printed one-page process card; success measured by FRC use |
| Sustainability after the pilot grant | Medium | Open formats, full export, low-cost hosting, ≥ 2 village-level custodians |

---

## 26. Glossary (official Marathi terms)

| Marathi | English |
|---|---|
| ग्रामसभा | Gram Sabha |
| वनहक्क समिती | Forest Rights Committee (FRC) |
| उपविभागस्तरीय समिती | Sub-Divisional Level Committee (SDLC) |
| जिल्हास्तरीय समिती | District Level Committee (DLC) |
| राज्यस्तरीय संनियंत्रण समिती | State Level Monitoring Committee (SLMC) |
| सामूहिक वनहक्क व्यवस्थापन समिती | CFR Management Committee (CFRMC) |
| सामूहिक / सामुदायिक वन संसाधन | Community Forest Resource (Form C uses सामुदायिक; GRs use सामूहिक) |
| सामूहिक हक्क / वैयक्तिक हक्क | community / individual rights |
| वनहक्क धारक | forest-rights holder |
| दावा, दावेदार; मागणीदार | claim, claimant; claimant (2008 Rules wording) |
| पुरावा; पुष्टयर्थ / पुष्टीदाखल पुरावा | evidence; supporting evidence |
| ठराव (संमत करणे) | resolution (pass) |
| गणपूर्ती | quorum |
| नमुना-क / ख / ग | Form A / B / C |
| जोडपत्र; प्रपत्र; परिशिष्ट | annexure; format; appendix |
| हक्कपत्र; मालकी हक्क | title deed; ownership title |
| निस्तार; निस्तार पत्रक | nistar rights; nistar record |
| गौण वनोत्पादन / गौण वनोपज | minor forest produce |
| विल्हेवाट | disposal |
| स्वामित्व हक्क; स्वामित्वधन | ownership right; royalty |
| पारगमन परवाना / वाहतूक परवाना | transit permit |
| चराई | grazing |
| वसतिस्थान | habitat |
| आदिम जमाती समूह; विशेषत: असुरक्षित जमाती समूह | PTG; PVTG |
| कृषिपूर्व समाज | pre-agricultural community |
| भटक्या / फिरस्ते जमाती | nomadic / pastoral communities |
| अनुसूचित जमाती; इतर पारंपारिक वननिवासी | Scheduled Tribe; OTFD |
| पिढी (पंचवीस वर्षे) | generation (25 years) |
| उपजीविकेच्या खऱ्याखुऱ्या गरजा | bona fide livelihood needs |
| निरंतर वापर | sustainable use |
| संरक्षण, पुनर्निर्माण, संवर्धन, व्यवस्थापन | protect, regenerate, conserve, manage |
| संवर्धन व व्यवस्थापन आराखडा | conservation and management plan |
| सूक्ष्म योजना / कार्य योजना | micro plan / working plan |
| सीमांकन; सीमा चिन्हे; रूढीगत सीमा; चतु:सीमा | demarcation; boundary marks; customary boundary; four boundaries |
| नकाशा; नजरी नकाशा; राजस्व नकाशा | map; sketch map; revenue map |
| खसरा / कक्ष क्रमांक; सर्व्हे नंबर | khasra / compartment number; survey number |
| सातबारा (७/१२) उतारा | 7/12 record-of-rights extract |
| पडताळणी; क्षेत्रीय पडताळणी | verification; field verification |
| वडिलधाऱ्या व्यक्तींचे लेखानिविष्ट कथन | written statement of elders |
| मतदार यादी | electoral roll |
| प्रमाणपत्र | certificate |
| विनंती अर्ज; अपील; व्यथित व्यक्ती | petition; appeal; aggrieved person |
| मान्यता देणे; निहित करणे | recognise; vest |
| फेरबदल; फेटाळणे; पुनर्विचारार्थ | modify; reject; for reconsideration |
| अभिलेख; हक्क नोंदी; महसूल व वन अभिलेख | record; record of rights; revenue and forest records |
| अधिप्रमाणित प्रत | authenticated copy |
| राखीव / संरक्षित वन; अभयारण्य; राष्ट्रीय उद्यान | reserved / protected forest; sanctuary; national park |
| वन ग्राम; महसुली गाव; गावठाण; वाडी / पाडे | forest village; revenue village; village settlement; hamlets |
| देवराई; पवित्र स्थळे; दफन / दहन भूमी | sacred grove; sacred sites; burial / cremation ground |
| गोचर; निस्तारी वन | grazing common; nistari forest |
| जैविक विविधता; बौद्धिक संपदा; पारंपारिक ज्ञान | biodiversity; intellectual property; traditional knowledge |
| उपविभागीय अधिकारी; उपवनसंरक्षक; जिल्हाधिकारी | SDO; DCF; Collector |
| तलाठी; तहसीलदार | Talathi (village revenue officer); Tahsildar |
| प्रकल्प अधिकारी, एकात्मिक आदिवासी विकास प्रकल्प | Project Officer, ITDP |
| शिवारफेरी | village area walk |
| अभिसरण समिती | convergence committee |
| अध्यक्ष / सचिव / खजिनदार | chair / secretary / treasurer |
| दवंडी | drum announcement |
| तेंदू पत्ता, बांबू, मोह फुले, चारोळी, मध | tendu leaves, bamboo, mahua, charoli, honey |
| शासन निर्णय; शासन परिपत्रक; संकेतांक | GR; circular; code number |

---

## 27. Acronyms

| | |
|---|---|
| ACF / RFO | Assistant Conservator of Forests / Range Forest Officer |
| CFR / CR / IFR | Community Forest Resource / Community Rights / Individual Forest Rights |
| CFRMC | Community Forest Resource Management Committee |
| DCF / DFO | Deputy Conservator of Forests / Divisional Forest Officer |
| DILR | District Inspector of Land Records |
| DLC / SDLC / SLMC | District / Sub-Divisional Level Committee / State Level Monitoring Committee |
| DPDP | Digital Personal Data Protection Act, 2023 |
| FDST / OTFD | Forest-Dwelling Scheduled Tribe / Other Traditional Forest Dweller |
| FRA / FRC | Forest Rights Act / Forest Rights Committee |
| GP / GR | Gram Panchayat / Government Resolution |
| ITDP / TRTI | Integrated Tribal Development Project / Tribal Research & Training Institute |
| LGD | Local Government Directory code |
| MFP / MSP | Minor Forest Produce / Minimum Support Price |
| MoTA | Ministry of Tribal Affairs |
| PESA | Panchayats (Extension to Scheduled Areas) Act |
| PTG / PVTG | Primitive / Particularly Vulnerable Tribal Group |
| RF / PF / NP / WLS | Reserved Forest / Protected Forest / National Park / Wildlife Sanctuary |

---

## 28. Rule index (quick lookup)

| Rule | Subject |
|---|---|
| 2(1)(ca), 2(1)(d) | Community rights definition; disposal of MFP |
| 2A | Hamlets and unrecorded settlements |
| 3 | FRC constitution, composition, recusal |
| 4 | Gram Sabha functions; 4(1)(e)–(g) CFRMC, plan, permits; 4(2) quorum |
| 5, 6 | SDLC constitution and functions |
| 7, 8 | DLC constitution and functions; 8(h) Annexures II/III; 8(i) Annexure IV |
| 9, 10 | SLMC constitution and functions; Annexure V |
| 11 | Claims: window, CFR date, acknowledgement, Forms B/C by FRC, forwarding, GP Secretary |
| 12 | FRC verification, boundary, map, findings, conflicts, records |
| 12A | SDLC/DLC process, officials' presence, petitions, remand, reasons, record updation, no technical rejection, evidence |
| 12B | PVTG habitat, pastoralists, CFR in all villages, reasons for omission, forest-village conversion |
| 13 | Evidence: 13(1) general, 13(2) CFR, 13(3) more than one |
| 14, 15 | Petitions to SDLC / DLC |
| 16 | Post-claim support and convergence |

---

## 29. Field vocabulary for forms (enumerations)

| Vocabulary | Values |
|---|---|
| Claim type | IFR (Form A) · CR (Form B) · CFR (Form C) |
| Community status (Form B 1, Form C 5) | FDST yes/no · OTFD yes/no (per member on the Form C sheet: ST / OTFD) |
| Form B rights | nistar [3(1)(b)] · minor forest produce [3(1)(c)] · water bodies/fish [3(1)(d)] · grazing [3(1)(d)] · nomadic/pastoral access [3(1)(d)] · habitat of PTGs [3(1)(e)] · biodiversity/IP/traditional knowledge [3(1)(k)] · other traditional [3(1)(l)] |
| Per-right detail (Maharashtra) | right name and items used · survey/compartment nos. · area (ha.R) · four boundaries (E/W/N/S landmark) · annual quantity |
| Evidence tags | 13(1)(a)–(i), 13(2)(a)–(e) |
| Use-zone types [13(2)(b)] | grazing ground · roots and tubers · fodder · wild edible fruits · other MFP · fishing ground · irrigation system · water source (human/livestock) · medicinal-plant territory |
| Landmark types | river · stream (नाला) · spring (झरा) · pond (तलाव) · deity/sacred place · sacred tree/grove · burial/cremation ground · well · road/path · compartment pillar |
| Boundary status | draft · GS-approved · titled; classification per §17.2 |
| Village type | revenue village · forest village · hamlet (with consolidation status) |
| Consolidation status [Rule 2A] | recognised · listed · consolidated (SDO) · finalised (DLC) |
| Gender | female · male · other |
| Authority order kinds | acknowledgement · forward · remand · modification · rejection · title · record entry |

---

## 30. Reference data

### 30.1 Pilot village: ओझर (Ozar / Ozhar)
From `mh_cfr_potential_villages.xlsx`. Village matching must use the census code, because other villages named Ozar exist in Nashik and Jalgaon.

| Field | Value |
|---|---|
| District / Taluka / Gram Panchayat | Palghar / Jawhar / Ozar |
| Census 2011 village code | **551855** |
| Geographical area | 964 ha (GIS 970.05 ha) |
| Households | 421 |
| Population | 2,171 (SC 0, ST 2,169) |
| Village type | Revenue village; CFR type: forest within village |
| Forest inside revenue boundary | 318.4 ha (≈ 33% of GIS area) |
| Potential CFR in 2 km buffer | 0 ha |
| **Total CFR potential** | **318.4 ha** (23rd of 60 villages in Jawhar) |
| App village ID used so far | OZH-01 |

### 30.2 District and state context
| Scope | Figures |
|---|---|
| Jawhar taluka | 60 villages; 15,788 households; population 78,153 (ST 76,390); CFR potential 17,631.5 ha |
| Palghar district | 609 villages; CFR potential 188,650.2 ha. By taluka (villages / ha): Dahanu 119 / 43,961.2 · Palghar 133 / 35,981.5 · Vada 125 / 33,746.8 · Vikramgad 76 / 22,882.0 · Jawhar 60 / 17,631.5 · Mokhada 35 / 14,102.8 · Vasai 29 / 12,984.5 · Talasari 32 / 7,359.9 |
| Maharashtra | 17,256 villages listed (16,559 revenue, 697 forest); 34 districts; 338 talukas; CFR potential 6,331,512.9 ha (3,605,450.5 inside boundaries + 2,726,062.4 buffer); ST population 5,574,095 |

Dataset columns: district, subdistrict, Gram Panchayat, village, village code 2011, geographical area, GIS area, households, population, SC, ST, village type, CFR type (forest within / adjacent / both), forest inside revenue boundary, potential CFR in 2 km buffer, total CFR potential. The source and author are not stated in the file.

---

## 31. Source index (`documents/`)

| File | What it is |
|---|---|
| `VanMitra_CFR_Claim_Module.pdf` | CFR Claim Module specification v1.0 (36 pp., 6 Sep 2026): legal foundation, authorities, documents, 14-stage workflow, architecture, stack, business rules, roadmap, risks |
| `vanmitra_architecture.pdf` | Final Application Architecture (28 pp., 31 Aug 2026): vision, principles, 8 layers, interfaces, 17 modules, data/technical/AI/integration/security architecture, navigation |
| `FRA_CFR_Implementation_Report (1).pdf` | Proposed On-Ground Implementation Scheme (16 pp., 31 Aug 2026): awareness, facilitation, tracking, survey, mapping, Gram Sabha, livelihoods, 12 phases, stakeholders, pilot |
| `cfr_workflow.pdf` | Two-page CFR reference sheet: documents required; officers and signatories per stage; Annexure IV signature block |
| `FRARulesBook_Highlighted.pdf` | MoTA/UNDP *Forest Rights Act, 2006: Act, Rules and Guidelines* (52 pp.); Forms A/B/C on printed pp. 27–30; Annexures II–IV after |
| `1. FRA ACT 2006_Marathi.pdf` | Marathi text of the Act |
| `3. FRA AMMENDMENT 2012_Marathi.pdf` | Marathi text of the 2012 Amendment Rules (incl. नमुना-ग, जोडपत्र-चार, पाच) |
| `Imp..ALL GRs...FRA 2006.pdf` | 82 pp.: Marathi Act (pp. 1–13), Rules 2008 (pp. 14–32), Amendment 2012 (pp. 33–42) and the five Maharashtra GRs of §13.3 (pp. 43–82). Pp. 1–42 use legacy DVB-TT fonts and need conversion to Unicode |
| `mh_cfr_potential_villages.xlsx` | 17,256 Maharashtra villages with CFR potential area (§30) |
| `138b6349-….jpg` | Hand-drawn participatory map (नजरी नकाशा), Chek Sukwasi |
| `3a5b8ce6-….jpg` | 7/12 extract, Government (Forest Department) land |
| `951b097f-….jpg` (= `WhatsApp … 2.44.01 PM.jpeg`) | Elders' written statement, Rule 13(1)(i) |
| `c39372f8-….jpg` | Gram Panchayat certificate of ST/OTFD claimant counts |
| `f756e0b9-….jpg` | Form B per-right table (nistar, MFP) with survey nos., area, four boundaries, quantity |
| `WhatsApp … 2.44.01 PM (2).jpeg` | Electoral roll summary 2024 |
| `WhatsApp … 2.44.01 PM (3).jpeg` | Revenue map (राजस्व नकाशा) of the mauja |
| `WhatsApp … 2.44.46 PM.jpeg` | Folder view of a real "Claim Process" packet: the eight documents of §8 |

---

*This reference is derived from published legislation, rules and Maharashtra GRs. It is not legal advice. Statutory provisions, state rules, GRs and officer designations change; verify against the instruments in force before generating any document for real use.*
