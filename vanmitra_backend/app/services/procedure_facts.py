"""
Facts about the boundary, field verification, Gram Sabha resolution and disputes of a
case, used by the completeness checks (R3, R4, R5, R7, R10) and the Gram Sabha guard.
Each later stage of the procedure fills in its part here.
"""

from dataclasses import dataclass

from sqlalchemy.orm import Session

from ..models import BoundaryStatus, ClaimType
from . import boundary
from .cases import CaseContext


@dataclass(frozen=True)
class ProcedureFacts:
    boundary_gs_approved: bool = False
    segments_without_landmark: int | None = None
    verification_complete: bool = False
    quorum_passed: bool = False
    open_disputes: int = 0


def collect(db: Session, ctx: CaseContext) -> ProcedureFacts:
    approved = False
    unmarked: int | None = None
    disputes = 0
    if ctx.case.claim_type is ClaimType.CFR:
        current = boundary.current_boundary(db, ctx.case.id)
        if current is not None:
            approved = current.status in (BoundaryStatus.GS_APPROVED, BoundaryStatus.TITLED)
            unmarked = boundary.segments_without_landmark(current)
        disputes = boundary.open_disputes(db, ctx.case.id)
    return ProcedureFacts(
        boundary_gs_approved=approved,
        segments_without_landmark=unmarked,
        open_disputes=disputes,
    )
