"""
Facts about the boundary, field verification, Gram Sabha resolution and disputes of a
case, used by the completeness checks (R3, R4, R5, R7, R10) and the Gram Sabha guard.
Each later stage of the procedure fills in its part here.
"""

from dataclasses import dataclass

from sqlalchemy.orm import Session

from .cases import CaseContext


@dataclass(frozen=True)
class ProcedureFacts:
    boundary_gs_approved: bool = False
    segments_without_landmark: int | None = None
    verification_complete: bool = False
    quorum_passed: bool = False
    open_disputes: int = 0


def collect(db: Session, ctx: CaseContext) -> ProcedureFacts:
    return ProcedureFacts()
