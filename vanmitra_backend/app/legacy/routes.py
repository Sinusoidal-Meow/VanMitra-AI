"""
Legacy VanMitra-AI "Model A" endpoints (pre-CFR-module).

DEPRECATED. Kept only so the existing Flutter screens keep working while they
move to the new CFR claim API (BACKEND_PLAN.md, decision B-04). Paths are
unchanged. Do not add features here.

- /eligibility-check and the evidence score break rules R1/R2 (the app never
  decides eligibility and never shows a score). They are removed once the
  frontend stops calling them.
- OCR (/verify-document) and /transcribe move to app/assist/ later.

Mounted only when VANMITRA_ENABLE_LEGACY_API=true (the default).
"""

from datetime import date, datetime
from typing import Dict, List, Optional

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field

from .agents import CUTOFF_DATE, ClaimRecord, Evidence, OrchestratorAgent

router = APIRouter(tags=["legacy (deprecated)"])

_orchestrator = OrchestratorAgent()
_notices: List[Dict] = []


class EligibilityRequest(BaseModel):
    is_scheduled_tribe: bool
    residence_start_date: str
    depends_on_forest: bool = True
    years_of_dependence: int = 0


@router.post("/api/v1/eligibility-check")
def eligibility_check(req: EligibilityRequest):
    try:
        residence_start = date.fromisoformat(req.residence_start_date)
    except ValueError:
        raise HTTPException(status_code=422, detail="residence_start_date must be YYYY-MM-DD")
    result = _orchestrator.eligibility.check(
        is_scheduled_tribe=req.is_scheduled_tribe,
        residence_start=residence_start,
        depends_on_forest=req.depends_on_forest,
        years_of_dependence=req.years_of_dependence,
    )
    result["cutoff_date"] = CUTOFF_DATE.isoformat()
    return result


@router.post("/api/v1/verify-document")
async def verify_document(
    image: UploadFile = File(...),
    expected_category: str = Form(...),
    claimant_name: str = Form(""),
    survey_khasra_no: Optional[str] = Form(None),
):
    image_bytes = await image.read()
    claim = ClaimRecord(
        form_type="A", claimant_category="FDST", claimant_scope="individual",
        claimant_name=claimant_name or "Unknown", father_husband_name="",
        tribe_caste="", village="Ozhar", gram_sabha="Ozhar Gram Sabha",
        tehsil="Jawhar", district="Palghar", residence_start_date="1990-01-01",
        depends_on_forest=True, survey_khasra_no=survey_khasra_no,
        area_value=0, area_unit="sqm", nature_of_right=["cultivation"],
    )
    return _orchestrator.verify_document(image_bytes, expected_category, claim)


class ClaimInput(BaseModel):
    form_type: str = Field(..., pattern="^[ABC]$")
    claimant_name: str
    father_husband_name: str
    tribe_caste: str = "Warli"
    village: str = "Ozhar"
    gram_sabha: str = "Ozhar Gram Sabha"
    tehsil: str = "Jawhar"
    district: str = "Palghar"
    survey_number: Optional[str] = None
    area_sq_meters: float = 0.0
    nature_of_right: str = "cultivation"
    occupation_years: int = 0
    residence_start_date: str = "1990-01-01"
    depends_on_forest: bool = True
    is_scheduled_tribe: bool = True
    evidence: Optional[Dict[str, str]] = None
    language: str = "mr"
    claimant_scope: str = "individual"


@router.post("/api/v1/generate-draft")
def generate_draft(payload: ClaimInput):
    evidence_list = [
        Evidence(category=cat, description=f"{cat} evidence", verification_status=status,
                 confidence=1.0 if status == "auto_verified" else 0.6)
        for cat, status in (payload.evidence or {}).items()
    ]
    claim = ClaimRecord(
        form_type=payload.form_type,
        claimant_category="FDST" if payload.is_scheduled_tribe else "OTFD",
        claimant_scope=payload.claimant_scope,
        claimant_name=payload.claimant_name,
        father_husband_name=payload.father_husband_name,
        tribe_caste=payload.tribe_caste,
        village=payload.village, gram_sabha=payload.gram_sabha,
        tehsil=payload.tehsil, district=payload.district,
        residence_start_date=payload.residence_start_date,
        depends_on_forest=payload.depends_on_forest,
        survey_khasra_no=payload.survey_number,
        area_value=payload.area_sq_meters, area_unit="sqm",
        nature_of_right=[payload.nature_of_right],
        evidence=evidence_list, language=payload.language,
    )
    return _orchestrator.run_claim_pipeline(
        claim=claim, is_scheduled_tribe=payload.is_scheduled_tribe,
        years_of_dependence=payload.occupation_years,
    )


@router.post("/api/v1/transcribe")
async def transcribe(audio: UploadFile = File(...), language: str = Form("mr")):
    try:
        import whisper, tempfile, os
        audio_bytes = await audio.read()
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name
        model = whisper.load_model("base")
        result = whisper.transcribe(model, tmp_path, language=language)
        os.unlink(tmp_path)
        return {"text": result["text"], "language": language, "is_ai_generated": True}
    except ImportError:
        raise HTTPException(status_code=503, detail="Whisper not installed. Add openai-whisper to requirements.txt.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")


@router.post("/api/v1/analyze-rejection")
async def analyze_rejection(image: UploadFile = File(...)):
    image_bytes = await image.read()
    try:
        import pytesseract
        from PIL import Image
        import io
        img = Image.open(io.BytesIO(image_bytes))
        ocr_text = pytesseract.image_to_string(img, lang="eng+mar+hin")
    except Exception:
        return {"is_ocr_processed": False, "rejection_reason": "unknown",
                "is_rejection_valid": None, "validity_explanation": "OCR not available.",
                "appeal_recommended": True}
    result = _orchestrator.rejection.classify(ocr_text)
    result["is_ocr_processed"] = True
    result["rejection_date"] = datetime.utcnow().date().isoformat()
    return result


class AppealRequest(BaseModel):
    rejection_analysis: Dict
    original_claim: ClaimInput


@router.post("/api/v1/generate-appeal")
def generate_appeal(req: AppealRequest):
    evidence_list = [
        Evidence(category=cat, description=f"{cat} evidence", verification_status=status)
        for cat, status in (req.original_claim.evidence or {}).items()
    ]
    claim = ClaimRecord(
        form_type=req.original_claim.form_type,
        claimant_category="FDST" if req.original_claim.is_scheduled_tribe else "OTFD",
        claimant_scope=req.original_claim.claimant_scope,
        claimant_name=req.original_claim.claimant_name,
        father_husband_name=req.original_claim.father_husband_name,
        tribe_caste=req.original_claim.tribe_caste,
        village=req.original_claim.village, gram_sabha=req.original_claim.gram_sabha,
        tehsil=req.original_claim.tehsil, district=req.original_claim.district,
        residence_start_date=req.original_claim.residence_start_date,
        depends_on_forest=req.original_claim.depends_on_forest,
        survey_khasra_no=req.original_claim.survey_number,
        area_value=req.original_claim.area_sq_meters, area_unit="sqm",
        nature_of_right=[req.original_claim.nature_of_right],
        evidence=evidence_list, language=req.original_claim.language,
    )
    return _orchestrator.appeal.generate(claim, req.rejection_analysis)


@router.get("/api/v1/notices")
def get_notices():
    return {"notices": _notices, "count": len(_notices)}


@router.post("/api/v1/notices")
def post_notice(notice: Dict):
    _notices.append(notice)
    return {"status": "ok", "notice_id": notice.get("noticeId", "unknown")}


# ── Module B: Satellite Change Detection ─────────────────────────────────────

@router.post("/api/v1/satellite-verify")
async def satellite_verify(
    latitude:      float               = Form(...),
    longitude:     float               = Form(...),
    radius_meters: int                 = Form(500),
    claim_id:      Optional[str]       = Form(None),
    start_date:    Optional[str]       = Form(None),
    end_date:      Optional[str]       = Form(None),
    claimant_name: str                 = Form(""),
    image:         Optional[UploadFile] = File(None),
):
    """On-demand per-parcel satellite verification.

    Returns a structured result including land-cover class, NDVI, canopy
    coverage, deforestation flag, and a verification_verdict that feeds
    directly into the ScoringAgent evidence pipeline.

    NOTE: Until the Earth Engine service-account acquisition path is wired
    in SatelliteAgent._run_analysis(), this endpoint returns
    status="pending_ee_integration".  Use /satellite-monitor/run for seed data.
    """
    import uuid as _uuid
    image_bytes = await image.read() if image else None
    result = _orchestrator.satellite.analyze(
        latitude=latitude,
        longitude=longitude,
        radius_meters=radius_meters,
        image_bytes=image_bytes,
        start_date=start_date,
        end_date=end_date,
    )
    result["claim_id"] = claim_id or "unlinked"
    result["task_id"] = str(_uuid.uuid4())
    return result


@router.post("/api/v1/satellite-monitor/run")
async def run_village_monitor(village_id: str = Form(...)):
    """Batch satellite monitor — runs the Siamese model over every parcel
    for village_id and returns a per-parcel alert list.

    Currently serves ozar_alerts.csv seed data (demo-v1-synthetic).
    Production: wire SatelliteAgent._run_analysis() with EE service account,
    then replace with a per-parcel loop that calls satellite.analyze().
    Results should be upserted to boundary_alerts/{alertId} in Firestore.
    """
    return _orchestrator.satellite.run_village_monitor(village_id=village_id)


@router.get("/api/v1/satellite-monitor/config")
def get_satellite_config():
    """Return the loaded satellite model configuration and provenance flags."""
    sat = _orchestrator.satellite
    return {
        "model_version": sat.model_version,
        "village_boundary_source": sat.village_boundary_source,
        "earth_engine_imagery_used": sat.earth_engine_imagery_used,
        "thresholds": {
            "theta_change_candidate": sat.theta,
            "siamese_decision_tau": sat.tau,
            "reliable_min_sqm": sat.reliable_min_sqm,
            "marginal_min_sqm": sat.marginal_min_sqm,
        },
        "model_loaded": sat._model is not None,
    }

