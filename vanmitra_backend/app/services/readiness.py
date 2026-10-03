"""Gathers the facts for the R1-R10 completeness checks from the database."""

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..domain.form_b import Completeness
from ..domain.readiness import ReadinessInput, readiness
from ..models import ClaimType, EvidenceKind, LetterTemplate
from ..models.procedure import Correspondence, Evidence, EvidenceVerification
from . import procedure_facts
from .cases import CaseContext


def current_evidence(db: Session, case_id: uuid.UUID) -> list[Evidence]:
    """Evidence rows not superseded by a correction, oldest first."""
    rows = db.scalars(
        select(Evidence).where(Evidence.case_id == case_id).order_by(Evidence.created_at)
    ).all()
    superseded = {r.supersedes_id for r in rows if r.supersedes_id}
    return [r for r in rows if r.id not in superseded]


def verified_ids(db: Session, evidence_ids: list[uuid.UUID]) -> set[uuid.UUID]:
    if not evidence_ids:
        return set()
    return set(
        db.scalars(
            select(EvidenceVerification.evidence_id).where(
                EvidenceVerification.evidence_id.in_(evidence_ids)
            )
        )
    )


def readiness_input(db: Session, ctx: CaseContext) -> ReadinessInput:
    case = ctx.case
    evidence = current_evidence(db, case.id)
    verified = verified_ids(db, [e.id for e in evidence])
    ok = [e for e in evidence if e.id in verified]
    general = sum(1 for e in ok if e.rule_ref.is_general and e.is_substitutable)
    cfr = sum(1 for e in ok if not e.rule_ref.is_general and e.is_substitutable)
    elder = any(
        e.kind is EvidenceKind.ELDER_STATEMENT and e.signed_scan_media_id is not None for e in ok
    )

    adjacent_total = adjacent_intimated = 0
    if case.claim_type is ClaimType.CFR and case.form_c is not None:
        names = {b.name.strip().casefold() for b in case.form_c.bordering_villages}
        adjacent_total = len(names)
        sent = {
            (c.neighbour_village or "").strip().casefold()
            for c in db.scalars(
                select(Correspondence).where(
                    Correspondence.gram_sabha_id == case.gram_sabha_id,
                    Correspondence.template == LetterTemplate.G2_INTIMATION_ADJOINING,
                    Correspondence.dispatched_on.is_not(None),
                )
            )
        }
        adjacent_intimated = len(names & sent)

    facts = procedure_facts.collect(db, ctx)
    return ReadinessInput(
        claim_type=case.claim_type,
        verified_general=general,
        verified_cfr=cfr,
        signed_elder_statement=elder,
        acknowledged=case.ack_serial is not None,
        adjacent_total=adjacent_total,
        adjacent_intimated=adjacent_intimated,
        boundary_gs_approved=facts.boundary_gs_approved,
        segments_without_landmark=facts.segments_without_landmark,
        verification_complete=facts.verification_complete,
        quorum_passed=facts.quorum_passed,
        open_disputes=facts.open_disputes,
    )


def compute(db: Session, ctx: CaseContext) -> Completeness:
    return readiness(readiness_input(db, ctx))
