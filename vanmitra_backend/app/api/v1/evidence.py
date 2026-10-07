"""
The evidence ledger [Rule 13], its verification, acknowledgement, documentation
completeness and the integrity check of the Gram Sabha's hash chain.

- Evidence is append-only and hash-chained (rule C8). A correction is a new row that
  supersedes the old one and records why (BR-15).
- The claimant adds evidence while drafting; the Gram Sabha adds and verifies it while
  reviewing. A verifier who is a claimant in the case is refused (BR-02, Rule 3(3)).
- An elder's statement must come from a Gram Sabha member who is not a claimant
  [Rule 13(1)(i)]. GPS and satellite items never count alone (BR-06).
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status

from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession, require_village_role
from ...auth.principal import Principal
from ...domain.frc import must_recuse
from ...errors import ApiError, RuleViolation
from ...models import (
    AppUser,
    CaseState,
    EvidenceKind,
    EvidenceRule,
    GramSabha,
    GsMember,
    Role,
    Village,
)
from ...models.procedure import CaseClaimant, Evidence, EvidenceVerification, Media, Recusal
from ...schemas.evidence import (
    AcknowledgementOut,
    EvidenceCorrect,
    EvidenceCreate,
    EvidenceOut,
    EvidenceVerify,
    LedgerReportOut,
    ReadinessOut,
    VerificationOut,
)
from ...services import ledger, readiness
from ...services.cases import CaseContext, load_case
from ._shared import FORM_LETTER, claimant_label, completeness_out

router = APIRouter(tags=["evidence"])


def claimant_member_ids(db: DbSession, case_id: uuid.UUID) -> set[str]:
    return {str(c.gs_member_id) for c in db.find(CaseClaimant, {"case_id": case_id})}


def _ensure_can_add(ctx: CaseContext) -> None:
    """Claimant while drafting; Gram Sabha while it reviews the claim."""
    state = ctx.case.state
    if state is CaseState.DRAFT and ctx.is_creator:
        return
    if state is CaseState.GS_REVIEW and Role.GRAM_SABHA in ctx.roles:
        return
    raise ApiError(403, "CANNOT_ADD_EVIDENCE_NOW", "evidence.cannot_add_now", {"state": state})


def _check_media(db: DbSession, user: AppUser, media_id: uuid.UUID | None) -> None:
    if media_id is None:
        return
    media = db.get(Media, media_id)
    if media is None or media.uploaded_by_user_id != user.id:
        raise ApiError(422, "MEDIA_NOT_YOURS", "evidence.media_not_yours", {"media_id": media_id})


def _validate(db: DbSession, ctx: CaseContext, body: EvidenceCreate, user: AppUser) -> None:
    _check_media(db, user, body.media_id)
    _check_media(db, user, body.signed_scan_media_id)
    if body.kind is EvidenceKind.ELDER_STATEMENT:
        if body.rule_ref is not EvidenceRule.R13_1_I or body.elder_member_id is None:
            raise ApiError(422, "ELDER_STATEMENT_FIELDS", "evidence.elder_statement_fields")
        elder = db.get(GsMember, body.elder_member_id)
        if elder is None or elder.gram_sabha_id != ctx.case.gram_sabha_id:
            raise ApiError(422, "ELDER_NOT_IN_ROSTER", "evidence.elder_not_in_roster")
        if str(body.elder_member_id) in claimant_member_ids(db, ctx.case.id):
            raise RuleViolation(
                "ELDER_IS_CLAIMANT",
                "Rule 13(1)(i)",
                "evidence.elder_is_claimant",
                {"elder_member_id": body.elder_member_id},
            )
    if body.kind is EvidenceKind.GPS_POINT and (body.gps_lat is None or body.gps_lon is None):
        raise ApiError(422, "GPS_POINT_NEEDS_COORDINATES", "evidence.gps_needs_coordinates")


def _new_row(ctx: CaseContext, body: EvidenceCreate, user: AppUser) -> Evidence:
    return Evidence(
        case_id=ctx.case.id,
        rule_ref=body.rule_ref,
        kind=body.kind,
        description=body.description,
        media_id=body.media_id,
        source_office=body.source_office,
        ref_no=body.ref_no,
        doc_date=body.doc_date,
        gps_lat=body.gps_lat,
        gps_lon=body.gps_lon,
        gps_accuracy_m=body.gps_accuracy_m,
        is_substitutable=body.kind.is_substitutable,
        elder_member_id=body.elder_member_id,
        transcript=body.transcript,
        signed_scan_media_id=body.signed_scan_media_id,
        added_by_user_id=user.id,
    )


def _out(db: DbSession, rows: list[Evidence], superseded: set[uuid.UUID]) -> list[EvidenceOut]:
    ids = [r.id for r in rows]
    verifications: dict[uuid.UUID, list[EvidenceVerification]] = {}
    if ids:
        v_rows = db.find(
            EvidenceVerification,
            {"evidence_id": {"$in": ids}},
            sort=[("created_at", 1)],
        )
        for v in v_rows:
            verifications.setdefault(v.evidence_id, []).append(v)
    return [
        EvidenceOut(
            id=r.id,
            rule_ref=r.rule_ref,
            kind=r.kind,
            description=r.description,
            media_id=r.media_id,
            source_office=r.source_office,
            ref_no=r.ref_no,
            doc_date=r.doc_date,
            gps_lat=r.gps_lat,
            gps_lon=r.gps_lon,
            gps_accuracy_m=r.gps_accuracy_m,
            is_substitutable=r.is_substitutable,
            elder_member_id=r.elder_member_id,
            transcript=r.transcript,
            signed_scan_media_id=r.signed_scan_media_id,
            supersedes_id=r.supersedes_id,
            superseded=r.id in superseded,
            correction_reason=r.correction_reason,
            verified=bool(verifications.get(r.id)),
            verifications=[
                VerificationOut(
                    verified_by_name=v.verified_by_name, remarks=v.remarks, at=v.created_at
                )
                for v in verifications.get(r.id, [])
            ],
            created_at=r.created_at,
        )
        for r in rows
    ]


@router.post(
    "/cases/{case_id}/evidence", response_model=EvidenceOut, status_code=status.HTTP_201_CREATED
)
def add_evidence(
    case_id: uuid.UUID,
    body: EvidenceCreate,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> EvidenceOut:
    ctx = load_case(db, principal, case_id)
    _ensure_can_add(ctx)
    _validate(db, ctx, body, user)
    row = _new_row(ctx, body, user)
    db.add(row)
    ledger.append(db, ctx.case.gram_sabha_id, row)
    db.commit()
    return _out(db, [row], set())[0]


@router.get("/cases/{case_id}/evidence", response_model=list[EvidenceOut])
def list_evidence(
    case_id: uuid.UUID,
    db: DbSession,
    principal: CurrentPrincipal,
    include_superseded: bool = False,
) -> list[EvidenceOut]:
    load_case(db, principal, case_id)
    rows = db.find(Evidence, {"case_id": case_id}, sort=[("created_at", 1)])
    superseded = {r.supersedes_id for r in rows if r.supersedes_id}
    if not include_superseded:
        rows = [r for r in rows if r.id not in superseded]
    return _out(db, rows, {i for i in superseded if i})


def _evidence_in_case(db: DbSession, case_id: uuid.UUID, evidence_id: uuid.UUID) -> Evidence:
    row = db.get(Evidence, evidence_id)
    if row is None or row.case_id != case_id:
        raise ApiError(404, "EVIDENCE_NOT_FOUND", "evidence.not_found")
    return row


def _is_superseded(db: DbSession, evidence_id: uuid.UUID) -> bool:
    return db.exists(Evidence, {"supersedes_id": evidence_id})


@router.post(
    "/cases/{case_id}/evidence/{evidence_id}/correct",
    response_model=EvidenceOut,
    status_code=status.HTTP_201_CREATED,
)
def correct_evidence(
    case_id: uuid.UUID,
    evidence_id: uuid.UUID,
    body: EvidenceCorrect,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
) -> EvidenceOut:
    """A correction never edits the record: it adds a row that supersedes it (BR-15)."""
    ctx = load_case(db, principal, case_id)
    _ensure_can_add(ctx)
    old = _evidence_in_case(db, case_id, evidence_id)
    if _is_superseded(db, old.id):
        raise ApiError(409, "ALREADY_SUPERSEDED", "evidence.already_superseded")
    _validate(db, ctx, body, user)
    row = _new_row(ctx, body, user)
    row.supersedes_id = old.id
    row.correction_reason = body.correction_reason
    db.add(row)
    ledger.append(db, ctx.case.gram_sabha_id, row)
    db.commit()
    return _out(db, [row], set())[0]


@router.post("/cases/{case_id}/evidence/{evidence_id}/verify", response_model=EvidenceOut)
def verify_evidence(
    case_id: uuid.UUID,
    evidence_id: uuid.UUID,
    db: DbSession,
    user: CurrentUser,
    principal: CurrentPrincipal,
    body: EvidenceVerify | None = None,
) -> EvidenceOut:
    """The Gram Sabha / FRC attests an item while reviewing the claim."""
    ctx = load_case(db, principal, case_id)
    if Role.GRAM_SABHA not in ctx.roles:
        raise ApiError(403, "NOT_YOUR_LEVEL", "workflow.not_your_level")
    if ctx.case.state is not CaseState.GS_REVIEW:
        raise ApiError(409, "NOT_UNDER_GS_REVIEW", "evidence.not_under_gs_review")
    row = _evidence_in_case(db, case_id, evidence_id)
    if _is_superseded(db, row.id):
        raise ApiError(409, "ALREADY_SUPERSEDED", "evidence.already_superseded")
    if must_recuse(
        str(user.gs_member_id) if user.gs_member_id else None,
        claimant_member_ids(db, case_id),
    ):
        assert user.gs_member_id is not None
        if not db.exists(
            Recusal,
            {"case_id": case_id, "gs_member_id": user.gs_member_id},
        ):
            db.add(
                Recusal(
                    case_id=case_id,
                    gs_member_id=user.gs_member_id,
                    reason="Claimant in this case; may not verify it [Rule 3(3)]",
                )
            )
            db.commit()
        raise RuleViolation("VERIFIER_IS_CLAIMANT", "Rule 3(3)", "evidence.verifier_is_claimant")
    already = db.exists(
        EvidenceVerification,
        {"evidence_id": row.id, "verified_by_user_id": user.id},
    )
    if already:
        raise ApiError(409, "ALREADY_VERIFIED", "evidence.already_verified")
    v = EvidenceVerification(
        evidence_id=row.id,
        verified_by_user_id=user.id,
        verified_by_name=user.name,
        remarks=body.remarks if body else None,
    )
    db.add(v)
    ledger.append(db, ctx.case.gram_sabha_id, v)
    db.commit()
    return _out(db, [row], set())[0]


# ── Acknowledgement, readiness, ledger ────────────────────────────────────────


@router.get("/cases/{case_id}/acknowledgement", response_model=AcknowledgementOut)
def acknowledgement(
    case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> AcknowledgementOut:
    """Data for the G4 acknowledgement receipt [Rule 11(3)]; issued when the claim is filed."""
    ctx = load_case(db, principal, case_id)
    case, village = ctx.case, ctx.village
    if case.ack_serial is None or case.acknowledged_on is None:
        raise ApiError(409, "NOT_YET_FILED", "acknowledgement.not_yet_filed")
    docs = [
        f"{e.rule_ref.value}: {e.description}"
        for e in readiness.current_evidence(db, case.id)
        if e.created_at.date() <= case.acknowledged_on
    ]
    return AcknowledgementOut(
        case_id=case.id,
        serial=case.ack_serial,
        acknowledged_on=case.acknowledged_on,
        form=FORM_LETTER[case.claim_type],
        claim_type=case.claim_type.value,
        claimant_label=claimant_label(case, village),
        village=f"{village.name_mr} ({village.name_en})",
        gram_panchayat=village.gram_panchayat,
        filed_within_window=case.filed_within_window,
        documents_received=docs,
    )


@router.get("/cases/{case_id}/readiness", response_model=ReadinessOut)
def case_readiness(case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> ReadinessOut:
    """Documentation completeness R1-R10 (advisory): what is still missing, with its rule."""
    ctx = load_case(db, principal, case_id)
    c = completeness_out(readiness.compute(db, ctx))
    return ReadinessOut(case_id=ctx.case.id, claim_type=ctx.case.claim_type.value, **c.model_dump())


@router.get("/villages/{village_id}/ledger/verify", response_model=LedgerReportOut)
def verify_ledger(
    db: DbSession,
    scope: Annotated[tuple[Principal, Village], Depends(require_village_role())],
) -> LedgerReportOut:
    """Recompute the Gram Sabha's hash chain and report the first altered or missing record."""
    gs = db.find_one(GramSabha, {"village_id": scope[1].id})
    if gs is None:
        raise ApiError(409, "GRAM_SABHA_MISSING", "village.gram_sabha_missing")
    r = ledger.verify(db, gs.id)
    return LedgerReportOut(
        ok=r.ok,
        length=r.length,
        head=r.head,
        broken_at_seq=r.broken_at_seq,
        broken_entity=r.broken_entity,
        reason=r.reason,
    )
