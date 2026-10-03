"""
Documentation completeness of a case (Spec §4.6), the R1-R10 checks. Advisory only
(BR-05): it never gates the workflow and is never shown as a score or probability.

A CFR claim gets all ten checks; an individual (Form A) or community-rights (Form B)
claim gets the ones that apply to it (evidence, verification, quorum, acknowledgement).
"""

from dataclasses import dataclass

from ..models.enums import ClaimType
from .form_b import Completeness, CompletenessItem

MIN_GENERAL = 2  # Rule 11(1)(a), 13(3)
MIN_GENERAL_WITHOUT_ELDER = 3  # R6 alternative


@dataclass(frozen=True)
class ReadinessInput:
    claim_type: ClaimType
    verified_general: int  # verified, non-substitutable Rule 13(1) items (BR-06)
    verified_cfr: int  # verified Rule 13(2) items
    signed_elder_statement: bool  # a verified 13(1)(i) statement with its signed sheet
    acknowledged: bool  # Rule 11(3)
    boundary_gs_approved: bool = False  # Rule 12(1)(g)
    segments_without_landmark: int | None = None  # None = no boundary mapped yet
    verification_complete: bool = False  # Rule 12A(1)(2): signed or absence recorded
    quorum_passed: bool = False  # Rule 4(2)
    adjacent_total: int = 0  # bordering villages listed on Form C (item 7)
    adjacent_intimated: int = 0  # of which a G2 intimation has been dispatched
    open_disputes: int = 0  # Rule 12(3)


def readiness(r: ReadinessInput) -> Completeness:
    items = [
        CompletenessItem(
            "R1", r.verified_general >= MIN_GENERAL, "evidence", "Rule 11(1)(a), 13(3)",
            "readiness.r1_two_general_evidences",
        ),
        CompletenessItem(
            "R2", r.verified_cfr >= 1, "evidence", "Rule 13(2)", "readiness.r2_cfr_evidence"
        ),
        CompletenessItem(
            "R3", r.boundary_gs_approved, "map", "Rule 12(1)(g)", "readiness.r3_boundary_approved"
        ),
        CompletenessItem(
            "R4",
            r.segments_without_landmark == 0,
            "map",
            "Rule 12(1)(g)",
            "readiness.r4_landmark_per_segment",
        ),
        CompletenessItem(
            "R5", r.verification_complete, "verification", "Rule 12A(1)(2)",
            "readiness.r5_field_verification",
        ),
        CompletenessItem(
            "R6",
            r.signed_elder_statement or r.verified_general >= MIN_GENERAL_WITHOUT_ELDER,
            "evidence",
            "Rule 13(1)(i)",
            "readiness.r6_elder_statement",
        ),
        CompletenessItem(
            "R7", r.quorum_passed, "gram_sabha", "Rule 4(2)", "readiness.r7_quorum"
        ),
        CompletenessItem(
            "R8",
            r.adjacent_total > 0 and r.adjacent_intimated >= r.adjacent_total,
            "letters",
            "Rule 11(1)(b)",
            "readiness.r8_adjoining_intimated",
        ),
        CompletenessItem(
            "R9", r.acknowledged, "acknowledgement", "Rule 11(3)", "readiness.r9_acknowledged"
        ),
        CompletenessItem(
            "R10", r.open_disputes == 0, "map", "Rule 12(3)", "readiness.r10_no_open_dispute"
        ),
    ]  # fmt: skip
    if r.claim_type is not ClaimType.CFR:
        keep = {"R1", "R5", "R6", "R7", "R9"}
        items = [i for i in items if i.id in keep]
    return Completeness(tuple(items))
