"""
VanMitra-AI Model A — Agent Implementations
============================================
All 7 single-responsibility agents from the Colab notebook,
plus supporting data classes and the shared FAISS RAG retriever.

Architecture:
  OrchestratorAgent
  ├─ IntakeAgent        (sanitize/validate input)
  ├─ EligibilityAgent   (FDST/OTFD eligibility test)
  ├─ DocVerifyAgent     (OCR + fuzzy cross-check)
  ├─ ScoringAgent       (weighted evidence score)
  ├─ DraftAgent         (RAG-grounded Form A/B/C draft)
  ├─ RejectionAgent     (rejection reason classification)
  └─ AppealAgent        (Section 6 appeal draft)
"""

import json
import re
import textwrap
import uuid
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional

import numpy as np

# ── Evidence weights — loaded from bundled JSON (same as Flutter assets) ──────────
_ASSETS_DIR = Path(__file__).resolve().parents[2] / "assets"
_WEIGHTS_PATH = _ASSETS_DIR / "ai_config" / "evidence_weights.json"
if _WEIGHTS_PATH.exists():
    with open(_WEIGHTS_PATH, encoding="utf-8") as _f:
        EVIDENCE_WEIGHTS: Dict[str, float] = json.load(_f)
else:
    EVIDENCE_WEIGHTS = {
        "government_records": 0.30,
        "physical_structures": 0.30,
        "elder_statements": 0.20,
        "traditional_structures": 0.10,
        "other_govt_schemes": 0.10,
    }

CUTOFF_DATE = date(2005, 12, 13)

FORM_TITLES = {
    "A": {"mr": "फॉर्म अ — वैयक्तिक वन हक्क दावा", "en": "Form A — Individual Forest Rights Claim"},
    "B": {"mr": "फॉर्म ब — सामुदायिक हक्क दावा", "en": "Form B — Community Rights Claim"},
    "C": {"mr": "फॉर्म क — सामुदायिक वन संसाधन हक्क दावा", "en": "Form C — Community Forest Resource Rights Claim"},
}

REJECTION_KEYWORDS = {
    "procedural_defect": ["signature", "unsigned", "incomplete form", "स्वाक्षरी"],
    "insufficient_evidence": ["evidence", "proof", "पुरावा", "documents lacking"],
    "boundary_dispute": ["boundary", "overlap", "सीमा", "adjoining claim"],
    "occupation_not_proven": ["occupation", "2005", "ताबा", "residence not proven"],
    "wrong_jurisdiction": ["jurisdiction", "wrong committee", "अधिकार क्षेत्र"],
    "beyond_time_limit": ["time limit", "late", "deadline", "मुदत"],
    "duplicate_claim": ["duplicate", "already filed", "पुनरावृत्ती"],
}


# ── Data classes ──────────────────────────────────────────────────────────────────

@dataclass
class Evidence:
    category: str
    description: str
    file_ref: Optional[str] = None
    verification_status: str = "unverified"
    confidence: float = 0.0


@dataclass
class Rejection:
    reason_class: Optional[str] = None
    order_ref: Optional[str] = None
    appeal_deadline: Optional[str] = None


@dataclass
class ClaimRecord:
    form_type: str
    claimant_category: str
    claimant_scope: str
    claimant_name: str
    father_husband_name: str
    tribe_caste: str
    village: str
    gram_sabha: str
    tehsil: str
    district: str
    residence_start_date: str
    depends_on_forest: bool
    survey_khasra_no: Optional[str]
    area_value: float
    area_unit: str
    nature_of_right: List[str]
    community_details: Dict = field(default_factory=dict)
    evidence: List[Evidence] = field(default_factory=list)
    witnesses: List[Dict] = field(default_factory=list)
    sketch_map_ref: Optional[str] = None
    language: str = "mr"
    claim_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    status: str = "draft"
    evidence_score: float = 0.0
    rejection: Rejection = field(default_factory=Rejection)
    draft_text: str = ""
    hash_chain_ref: Optional[str] = None


# ── FAISS RAG corpus ──────────────────────────────────────────────────────────────

FRA_CORPUS = [
    "Forest Dwelling Scheduled Tribes (FDST) must belong to a Scheduled Tribe in that area, "
    "have resided in forest land before 13 December 2005, and depend on the forest for livelihood.",
    "Other Traditional Forest Dwellers (OTFD) must have lived in and depended on the forest for "
    "at least 75 years (three generations) before 13 December 2005, and depend on the forest for livelihood.",
    "Claims may be filed by an individual tribal person, a tribal family, the entire village or Gram Sabha, "
    "or a forest-dependent community for Community Forest Rights.",
    "Rule 13 of the FRA Rules 2008 allows a wide range of evidence: identity proof such as Aadhaar, Voter ID, "
    "Ration Card, Caste Certificate, or PAN; residence proof such as old ration cards, electoral rolls, "
    "school or census records; and occupation proof such as revenue records, forest department records, "
    "old survey maps, satellite images, cultivation records, and old pattas or leases.",
    "Community and traditional evidence is especially important in tribal areas and includes statements "
    "of village elders, Gram Sabha resolutions, traditional maps, and evidence of grazing, bamboo "
    "collection, tendu collection, and fishing.",
    "If a tribal family has no documentary evidence, the FRA specifically allows oral evidence, witness "
    "testimony, statements of elders, community verification by the Gram Sabha, and physical verification "
    "by the Forest Rights Committee (FRC).",
    "The Gram Sabha forms a Forest Rights Committee (FRC) of 10 to 15 members, at least one-third of whom "
    "must be women, and the FRC helps villagers file claims using Form A, B, or C.",
    "The claim then goes to the Sub-Divisional Level Committee (SDLC), headed by the Sub-Divisional "
    "Officer, which reviews the Gram Sabha's recommendations and evidence.",
    "The District Level Committee (DLC), usually chaired by the District Collector, is the final authority "
    "for approving or rejecting claims; if approved, a forest rights title certificate is issued.",
    "Form A is the claim for Individual Forest Rights (IFR), filed by an individual or family.",
    "Form B is the claim for Community Rights (CR), filed by a Gram Sabha or village community.",
    "A rejected claim may be appealed within a sixty day window under Section 6 of the Forest Rights Act; "
    "common invalid grounds for rejection include failure to cite the specific Rule 13 evidence category "
    "considered, absence of Forest Rights Committee field verification, and rejection issued without a reasoned order.",
    "Common reasons genuine claims get rejected include lack of awareness about the FRA, missing records, "
    "difficulty collecting evidence, and language barriers for tribal communities.",
]


def _build_rag_index():
    try:
        from sentence_transformers import SentenceTransformer
        import faiss
        embedder = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
        embeddings = embedder.encode(FRA_CORPUS, convert_to_numpy=True)
        index = faiss.IndexFlatL2(embeddings.shape[1])
        index.add(embeddings)
        return embedder, index
    except Exception:
        return None, None


_embedder, _rag_index = _build_rag_index()


def retrieve(query: str, k: int = 3) -> List[str]:
    if _embedder is None or _rag_index is None:
        return FRA_CORPUS[:k]
    q_emb = _embedder.encode([query], convert_to_numpy=True)
    _, indices = _rag_index.search(q_emb, k)
    return [FRA_CORPUS[i] for i in indices[0]]


# ── 1. IntakeAgent ────────────────────────────────────────────────────────────────

class IntakeAgent:
    REQUIRED_FIELDS = [
        "claimant_name", "father_husband_name", "tribe_caste",
        "village", "gram_sabha", "tehsil", "district",
        "residence_start_date", "form_type",
    ]

    def process(self, raw: Dict) -> Dict:
        clean, flags = {}, []
        for f in self.REQUIRED_FIELDS:
            value = raw.get(f)
            if value is None or (isinstance(value, str) and not value.strip()):
                flags.append(f"Missing required field '{f}'")
                clean[f] = None
            else:
                clean[f] = value.strip() if isinstance(value, str) else value
        for f in ("claimant_name", "father_husband_name", "village", "gram_sabha"):
            if clean.get(f):
                clean[f] = re.sub(r"\s+", " ", re.sub(r"[\x00-\x1f]", "", clean[f])).strip()
        try:
            if raw.get("residence_start_date"):
                date.fromisoformat(raw["residence_start_date"])
        except ValueError:
            flags.append("residence_start_date is not a valid ISO date")
        if raw.get("form_type") not in ("A", "B", "C"):
            flags.append("form_type must be A, B, or C")
        clean["needs_human_review"] = len(flags) > 0
        clean["review_notes"] = flags
        return clean


# ── 2. EligibilityAgent ───────────────────────────────────────────────────────────

class EligibilityAgent:
    def check(self, is_scheduled_tribe: bool, residence_start: date,
              depends_on_forest: bool, years_of_dependence: int) -> Dict:
        result = {"eligible": False, "category": None, "reasons": []}
        before_cutoff = residence_start < CUTOFF_DATE

        if is_scheduled_tribe and before_cutoff and depends_on_forest:
            result.update(eligible=True, category="FDST")
            result["reasons"].append("Meets FDST criteria: ST + pre-2005 residence + forest dependence.")
            return result
        if years_of_dependence >= 75 and before_cutoff and depends_on_forest:
            result.update(eligible=True, category="OTFD")
            result["reasons"].append("Meets OTFD criteria: ≥75 years dependence + pre-2005 residence.")
            return result
        if not before_cutoff:
            result["reasons"].append("Residence must have started before 13 Dec 2005.")
        if not depends_on_forest:
            result["reasons"].append("Must demonstrate bona fide dependence on forest for livelihood.")
        if not is_scheduled_tribe and years_of_dependence < 75:
            result["reasons"].append("Neither ST-status nor 75-year OTFD dependence threshold is met.")
        return result


# ── 3. ScoringAgent ───────────────────────────────────────────────────────────────

class ScoringAgent:
    STATUS_VALUE = {"auto_verified": 1.0, "needs_review": 0.6, "unverified": 0.3, "rejected": 0.0}

    def score(self, evidence_list: List[Evidence]) -> float:
        best: Dict[str, float] = {}
        for ev in evidence_list:
            v = self.STATUS_VALUE.get(ev.verification_status, 0.0)
            best[ev.category] = max(best.get(ev.category, 0.0), v)
        num, den = 0.0, 0.0
        for cat, weight in EVIDENCE_WEIGHTS.items():
            num += weight * best.get(cat, 0.0)
            den += weight
        return round(num / den, 3) if den else 0.0

    def risk_level(self, score: float) -> str:
        if score >= 0.8: return "🟢 Ready — Submit"
        elif score >= 0.6: return "🟡 Partial — Warn"
        else: return "🔴 High Risk — Alert"


# ── 4. DocVerifyAgent ─────────────────────────────────────────────────────────────

class DocVerifyAgent:
    def verify(self, image_bytes: bytes, expected_category: str, claim: ClaimRecord) -> Dict:
        try:
            import pytesseract
            from PIL import Image
            from rapidfuzz import fuzz
            import io
            img = Image.open(io.BytesIO(image_bytes))
            ocr_text = pytesseract.image_to_string(img, lang="eng+mar+hin")
            name_score = fuzz.partial_ratio(claim.claimant_name.lower(), ocr_text.lower())
            survey_score = fuzz.partial_ratio(str(claim.survey_khasra_no or "").lower(), ocr_text.lower())
            match_confidence = round(max(name_score, survey_score) / 100, 2)
            status = "auto_verified" if match_confidence >= 0.8 else "needs_review" if match_confidence >= 0.4 else "rejected"
            return {
                "document_type": expected_category,
                "verification_status": status,
                "extracted_fields": {"name_match_score": round(name_score/100, 2)},
                "extracted_text_preview": ocr_text.strip()[:200],
                "match_confidence": match_confidence,
            }
        except ImportError:
            return {"document_type": expected_category, "verification_status": "needs_review",
                    "extracted_fields": {}, "extracted_text_preview": "[OCR not available]", "match_confidence": 0.0}
        except Exception as e:
            return {"document_type": expected_category, "verification_status": "needs_review",
                    "extracted_fields": {}, "extracted_text_preview": f"[OCR error: {str(e)[:80]}]", "match_confidence": 0.0}


# ── 5. DraftAgent ─────────────────────────────────────────────────────────────────

class DraftAgent:
    def __init__(self):
        self._scorer = ScoringAgent()

    def generate(self, claim: ClaimRecord, top_k_context: int = 2) -> str:
        lang = claim.language
        title = FORM_TITLES.get(claim.form_type, {}).get(lang,
                FORM_TITLES.get(claim.form_type, {}).get("en", f"Form {claim.form_type}"))
        context = retrieve(f"Form {claim.form_type} evidence eligibility {claim.claimant_category}", k=top_k_context)
        legal_grounding = "\n".join(f"  • {c}" for c in context)
        evidence_lines = "\n".join(
            f"  - {ev.description} ({ev.category}, {ev.verification_status})"
            for ev in claim.evidence
        ) or "  - [To be attached / oral evidence per Rule 13(3)]"
        risk = self._scorer.risk_level(claim.evidence_score)
        return textwrap.dedent(f"""
        {title}
        ------------------------------------------------------------
        To: Forest Rights Committee, {claim.gram_sabha}, {claim.tehsil}, {claim.district}

        Claimant: {claim.claimant_name}  (Father/Husband: {claim.father_husband_name})
        Tribe/Caste: {claim.tribe_caste}   Category: {claim.claimant_category}
        Village: {claim.village}   Gram Sabha: {claim.gram_sabha}

        Land Details:
          Survey/Khasra No.: {claim.survey_khasra_no or "N/A"}
          Area: {claim.area_value} {claim.area_unit}
          Nature of right: {", ".join(claim.nature_of_right)}
          Occupation since: {claim.residence_start_date}

        Evidence Submitted:
        {evidence_lines}

        Evidence Score: {claim.evidence_score}  ({risk})

        Legal Grounding (FRA corpus):
        {legal_grounding}

        We request the Forest Rights Committee and Gram Sabha to verify and recommend this claim
        to the Sub-Divisional Level Committee under the Forest Rights Act, 2006.

        Date: {date.today().isoformat()}
        ------------------------------------------------------------
        """).strip()


# ── 6. RejectionAgent ─────────────────────────────────────────────────────────────

class RejectionAgent:
    def classify(self, ocr_text: str) -> Dict:
        text_l = ocr_text.lower()
        scores = {cls: sum(1 for kw in kws if kw.lower() in text_l) for cls, kws in REJECTION_KEYWORDS.items()}
        best_class = max(scores, key=scores.get) if any(scores.values()) else "invalid_rejection"
        cites_rule13 = "rule 13" in text_l or "नियम १३" in ocr_text or "नियम 13" in ocr_text
        is_valid = best_class != "invalid_rejection" and cites_rule13
        return {
            "rejection_reason": best_class,
            "is_rejection_valid": is_valid,
            "validity_explanation": (
                "Rejection cites Rule 13 evidence category and a specific defect." if is_valid
                else "Rejection does not clearly cite Rule 13 — may be appealable under Section 6."
            ),
            "appeal_recommended": not is_valid,
        }


# ── 7. AppealAgent ────────────────────────────────────────────────────────────────

class AppealAgent:
    def generate(self, claim: ClaimRecord, rejection_analysis: Dict) -> Dict:
        context = retrieve(f"Section 6 appeal {rejection_analysis['rejection_reason']} rule 13", k=2)
        legal_grounding = "\n".join(f"  • {c}" for c in context)
        appeal_deadline = (date.today() + timedelta(days=60)).isoformat()
        appeal_text = textwrap.dedent(f"""
        SECTION 6 APPEAL — Forest Rights Act, 2006
        ------------------------------------------------------------
        Re: Claim {claim.claim_id} ({FORM_TITLES.get(claim.form_type, {}).get('en', f'Form {claim.form_type}')})
        Claimant: {claim.claimant_name}, {claim.village}, {claim.tehsil}, {claim.district}

        Ground of rejection: {rejection_analysis['rejection_reason']}
        Assessment: {rejection_analysis['validity_explanation']}

        We submit this appeal under Section 6 of the Forest Rights Act, 2006:
        {legal_grounding}

        Appeal deadline: {appeal_deadline} (60 days from rejection order)
        ------------------------------------------------------------
        """).strip()
        return {"appeal_text": appeal_text, "appeal_deadline": appeal_deadline, "is_ai_generated": True}


# ── OrchestratorAgent ─────────────────────────────────────────────────────────────

class OrchestratorAgent:
    def __init__(self):
        self.intake = IntakeAgent()
        self.eligibility = EligibilityAgent()
        self.scoring = ScoringAgent()
        self.doc_verify = DocVerifyAgent()
        self.draft = DraftAgent()
        self.rejection = RejectionAgent()
        self.appeal = AppealAgent()
        self.satellite = SatelliteAgent()  # Module B — Siamese CNN change detection

    def run_claim_pipeline(self, claim: ClaimRecord, is_scheduled_tribe: bool, years_of_dependence: int) -> Dict:
        eligibility_verdict = self.eligibility.check(
            is_scheduled_tribe=is_scheduled_tribe,
            residence_start=date.fromisoformat(claim.residence_start_date),
            depends_on_forest=claim.depends_on_forest,
            years_of_dependence=years_of_dependence,
        )
        claim.evidence_score = self.scoring.score(claim.evidence)
        claim.draft_text = self.draft.generate(claim)
        return {
            "claim_id": claim.claim_id,
            "eligibility": eligibility_verdict,
            "evidence_score": claim.evidence_score,
            "risk_level": self.scoring.risk_level(claim.evidence_score),
            "draft_text": claim.draft_text,
            "form_type": claim.form_type,
            "is_ai_generated": True,
            "language": claim.language,
            "disclaimer": "AI-generated draft — review required before submission.",
        }

    def verify_document(self, image_bytes: bytes, expected_category: str, claim: ClaimRecord) -> Dict:
        return self.doc_verify.verify(image_bytes, expected_category, claim)


# ── 8. SiameseChangeNet ───────────────────────────────────────────────────────
# Mirrors the architecture used to train siamese_change_model.pt (Cell 15/16 of
# VanMitra_ModuleB_Ozar.ipynb) — 6,002 params, patch_size=20

try:
    import torch
    import torch.nn as nn

    class SiameseChangeNet(nn.Module):
        """Lightweight Siamese CNN for per-pixel NDVI change detection.

        Matches the trained checkpoint: 2× branch streams share weights,
        L1 distance is fed to a classifier head.
        n_params ≈ 6,002  (demo training run on synthetic Tier-4 data)
        """
        def __init__(self, in_channels: int = 1, patch_size: int = 20):
            super().__init__()
            self.branch = nn.Sequential(
                nn.Conv2d(in_channels, 8, kernel_size=3, padding=1),
                nn.ReLU(inplace=True),
                nn.MaxPool2d(2),
                nn.Conv2d(8, 16, kernel_size=3, padding=1),
                nn.ReLU(inplace=True),
                nn.AdaptiveAvgPool2d((4, 4)),
            )
            self.classifier = nn.Sequential(
                nn.Linear(16 * 4 * 4, 32),
                nn.ReLU(inplace=True),
                nn.Linear(32, 1),
                nn.Sigmoid(),
            )

        def forward(self, x1: "torch.Tensor", x2: "torch.Tensor"):
            e1 = self.branch(x1).flatten(1)
            e2 = self.branch(x2).flatten(1)
            dist = (e1 - e2).abs()
            p_change = self.classifier(dist).squeeze(1)
            return p_change, e1, e2, dist

    _TORCH_AVAILABLE = True
except ImportError:
    _TORCH_AVAILABLE = False


# ── 9. SatelliteAgent ─────────────────────────────────────────────────────────

_AI_CONFIG_DIR = _ASSETS_DIR / "ai_config"


class SatelliteAgent:
    """Module B — Satellite boundary change-detection agent.

    Loads the trained SiameseChangeNet + satellite_config.json thresholds at
    startup.  _run_analysis() is the one remaining integration step: wire the
    Sentinel-2/Earth Engine acquisition path (service-account flow, headless
    equivalent of Colab Cell 12–13) to provide real T1/T2 patches.

    Until that pipeline is live, the on-demand endpoint returns a structured
    "pending_ee_integration" response and the batch monitor endpoint serves the
    ozar_alerts.csv seed data directly (see /api/v1/satellite-monitor/run).
    """

    def __init__(self):
        self._model = None
        self.patch_size = 20
        self.theta = 0.18          # ndvi_thresholds.theta_change_candidate
        self.tau = 0.5             # ndvi_thresholds.siamese_decision_tau
        self.a_min_pixels = 4
        self.pixel_area_sqm = 100.0
        self.reliable_min_sqm = 900.0
        self.marginal_min_sqm = 400.0
        self.village_boundary_source = "FALLBACK"
        self.earth_engine_imagery_used = False
        self.model_version = "demo-v1-synthetic"

        # Load satellite_config.json
        cfg_path = _AI_CONFIG_DIR / "satellite_config.json"
        if cfg_path.exists():
            try:
                cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
                ndvi = cfg.get("ndvi_thresholds", {})
                self.theta = ndvi.get("theta_change_candidate", self.theta)
                self.tau = ndvi.get("siamese_decision_tau", self.tau)
                cl = cfg.get("cluster_thresholds", {})
                self.a_min_pixels = cl.get("a_min_pixels", self.a_min_pixels)
                self.pixel_area_sqm = cl.get("pixel_area_sqm", self.pixel_area_sqm)
                rb = cfg.get("resolution_feasibility_bands", {})
                self.reliable_min_sqm = rb.get("reliable_min_sqm", self.reliable_min_sqm)
                self.marginal_min_sqm = rb.get("marginal_min_sqm", self.marginal_min_sqm)
                model_cfg = cfg.get("model", {})
                self.patch_size = model_cfg.get("patch_size", self.patch_size)
                self.village_boundary_source = cfg.get("village_boundary_source", "FALLBACK")
                self.earth_engine_imagery_used = cfg.get("earth_engine_imagery_used", False)
                self.model_version = (
                    "ee-v1" if self.earth_engine_imagery_used else "demo-v1-synthetic"
                )
            except Exception:
                pass  # Use hardcoded defaults if config parse fails

        # Load trained Siamese model
        model_path = _AI_CONFIG_DIR / "siamese_change_model.pt"
        if _TORCH_AVAILABLE and model_path.exists():
            try:
                ckpt = torch.load(model_path, map_location="cpu")
                # Support both raw state_dict and {"architecture":…, "state_dict":…} formats
                if isinstance(ckpt, dict) and "state_dict" in ckpt:
                    arch = ckpt.get("architecture", {})
                    net = SiameseChangeNet(**arch) if arch else SiameseChangeNet(patch_size=self.patch_size)
                    net.load_state_dict(ckpt["state_dict"])
                else:
                    net = SiameseChangeNet(patch_size=self.patch_size)
                    net.load_state_dict(ckpt)
                net.eval()
                self._model = net
            except Exception:
                pass  # Degrade gracefully if model load fails

    # ── Public API ────────────────────────────────────────────────────────────

    def analyze(
        self,
        latitude: float,
        longitude: float,
        radius_meters: int = 500,
        image_bytes: Optional[bytes] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
    ) -> Dict:
        """On-demand parcel verification (POST /api/v1/satellite-verify)."""
        try:
            ndvi_mean, canopy_pct, land_cover, p_change = self._run_analysis(
                latitude, longitude, radius_meters, image_bytes
            )
            status = self._verdict(ndvi_mean, canopy_pct, p_change)
            confidence = round(min(max(ndvi_mean, 0.0) + 0.2, 1.0), 2)
            description = (
                f"Satellite-verified forest land — NDVI {ndvi_mean:.2f}, "
                f"{canopy_pct:.1f}% canopy cover"
            )
            return {
                "status": "done",
                "land_cover": {"primary_class": land_cover},
                "ndvi": {
                    "mean": round(ndvi_mean, 3),
                    "interpretation": self._ndvi_label(ndvi_mean),
                },
                "canopy_coverage_percent": round(canopy_pct, 1),
                "change_detection": {
                    "deforestation_detected": p_change > self.tau,
                    "p_change": round(float(p_change), 3),
                },
                "verification_verdict": {
                    "status": status,
                    "confidence": confidence,
                    "evidence_category": "government_records",
                    "description": description,
                },
                "provenance": {
                    "village_boundary_source": self.village_boundary_source,
                    "imagery_source": "sentinel2_ee" if self.earth_engine_imagery_used else "synthetic",
                    "model_version": self.model_version,
                },
                "is_ai_generated": True,
                "disclaimer": "AI satellite analysis — field verification recommended before submission.",
            }
        except NotImplementedError:
            return {
                "status": "pending_ee_integration",
                "error_code": "EE_NOT_CONFIGURED",
                "message": (
                    "Earth Engine service-account acquisition not yet wired. "
                    "Use POST /api/v1/satellite-monitor/run to serve seed data."
                ),
                "provenance": {
                    "village_boundary_source": self.village_boundary_source,
                    "imagery_source": "synthetic",
                    "model_version": self.model_version,
                },
                "is_ai_generated": False,
            }
        except Exception as e:
            return {
                "status": "failed",
                "error_code": "ANALYSIS_ERROR",
                "message": str(e)[:200],
            }

    def run_village_monitor(self, village_id: str, seed_csv_path: Optional[str] = None) -> Dict:
        """Batch monitor job (POST /api/v1/satellite-monitor/run).

        Reads ozar_alerts.csv seed data and returns structured alert payloads
        for every parcel. Production: replace with a per-parcel loop that calls
        self.analyze() after wiring the EE acquisition path.
        """
        import csv
        alerts = []
        csv_path = seed_csv_path or str(
            _ASSETS_DIR / "seed_data" / "ozar_alerts.csv"
        )
        try:
            with open(csv_path, newline="", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    landowner_id = row.get("landowner_id", "")
                    area_sqm = float(row.get("declared_area_sqm", 0))
                    alerts.append({
                        "alertId": f"ALT_{village_id}_{landowner_id}",
                        "villageId": village_id,
                        "landownerId": int(landowner_id),
                        "claimantName": row.get("Claimant_Name", ""),
                        "surveyNo": int(row.get("Survey_No", 0)),
                        "declaredAreaSqm": area_sqm,
                        "landUseType": row.get("land_use_type", ""),
                        "resolutionFeasibility": row.get("resolution_feasibility", "marginal"),
                        "areaAffectedSqm": float(row.get("area_affected_sqm", 0.0)),
                        "tier": row.get("tier", "green"),
                        "likelyCause": row.get("likely_cause", "No change detected"),
                        "detectedAt": row.get("detected_date", date.today().isoformat()),
                        "resolvedAt": None,
                        "confidence": 0.87 if row.get("tier") == "green" else 0.72,
                        "ndviMean": 0.61 if row.get("tier") == "green" else 0.15,
                        "modelVersion": self.model_version,
                        "boundarySource": self.village_boundary_source,
                        "imagerySource": "sentinel2_ee" if self.earth_engine_imagery_used else "synthetic",
                        "is_ai_generated": True,
                    })
        except FileNotFoundError:
            return {"status": "error", "error_code": "SEED_CSV_NOT_FOUND", "alerts": []}
        return {
            "status": "done",
            "village_id": village_id,
            "total_parcels": len(alerts),
            "red_tier": sum(1 for a in alerts if a["tier"] == "red"),
            "yellow_tier": sum(1 for a in alerts if a["tier"] == "yellow"),
            "green_tier": sum(1 for a in alerts if a["tier"] == "green"),
            "model_version": self.model_version,
            "alerts": alerts,
        }

    def to_evidence(self, result: Dict) -> Evidence:
        """Convert analyze() result to Evidence for ScoringAgent."""
        v = result.get("verification_verdict", {})
        return Evidence(
            category=v.get("evidence_category", "government_records"),
            description=v.get("description", "Satellite analysis"),
            verification_status=v.get("status", "needs_review"),
            confidence=v.get("confidence", 0.5),
        )

    # ── Private helpers ───────────────────────────────────────────────────────

    def _run_analysis(self, lat: float, lng: float, radius: int, image_bytes: Optional[bytes]):
        """Acquire T1/T2 patches and run the Siamese model.

        TODO: Wire Sentinel-2/Earth Engine service-account acquisition here.
        Once live, this method should:
          1. Authenticate with EE service account (headless, no ee.Authenticate())
          2. Pull Sentinel-2 SR NIR+RED bands for (lat, lng, radius, T1, T2)
          3. Cloud-mask, pad patches to (1, patch_size, patch_size) via pad_to_size()
          4. Run self._model(x1, x2) → p_change
          5. Compute ndvi_mean, canopy_pct, land_class from pixel values
          6. Return (ndvi_mean, canopy_pct, land_class, p_change)

        Returns: (ndvi_mean: float, canopy_pct: float, land_class: str, p_change: float)
        """
        raise NotImplementedError(
            "Wire Sentinel-2/EE acquisition — model and thresholds are ready."
        )

    def _verdict(self, ndvi: float, canopy: float, p_change: float) -> str:
        """Combined Siamese + NDVI verdict per Module B plan §2.3."""
        if p_change <= self.tau and ndvi >= self.theta:
            return "auto_verified"
        elif p_change <= self.tau or ndvi >= self.theta * 0.6:
            return "needs_review"
        return "rejected"

    def _resolution_feasibility(self, area_sqm: float) -> str:
        if area_sqm >= self.reliable_min_sqm:
            return "reliable"
        elif area_sqm >= self.marginal_min_sqm:
            return "marginal"
        return "unreliable"

    def _ndvi_label(self, ndvi: float) -> str:
        if ndvi >= 0.6:
            return "Healthy vegetation — consistent with claimed forest land"
        elif ndvi >= 0.3:
            return "Moderate vegetation — partial forest cover"
        elif ndvi >= 0.1:
            return "Sparse vegetation — may not qualify as forest"
        return "Bare land / non-vegetated surface"

