"""Facts and guards for the Gram Sabha decision on a claim (BR-03, BR-04, BR-07, BR-09)."""

import uuid

from ..db import Store
from ..models import BoundaryStatus, CaseClaimant, ClaimType, Gender, GsMember
from ..models.procedure import GsMeeting, Resolution, VerificationProceeding
from ..schemas.gramsabha import ApprovalCheckOut, ApprovalPrerequisite
from . import boundary
from .cases import CaseContext


def latest_verification(db: Store, case_id: uuid.UUID) -> VerificationProceeding | None:
    return db.find_one(
        VerificationProceeding,
        {"case_id": case_id},
        sort=[("attempt_no", -1)],
    )


def verification_complete(v: VerificationProceeding | None) -> bool:
    """Both departments signed, or their absence is recorded (BR-07)."""
    if v is None:
        return False
    forest = v.forest_signed or v.forest_absence_recorded
    revenue = v.revenue_signed or v.revenue_absence_recorded
    return forest and revenue


def finality_note(v: VerificationProceeding | None) -> bool:
    """Absent on a second visit: the Gram Sabha decision stands [Rule 12A(2)]."""
    return bool(
        v
        and v.attempt_no >= 2
        and (v.forest_absence_recorded or v.revenue_absence_recorded)
        and verification_complete(v)
    )


def current_resolution(db: Store, case_id: uuid.UUID) -> Resolution | None:
    rows = db.find(
        Resolution,
        {"case_id": case_id},
        sort=[("created_at", 1), ("_id", 1)],
    )
    superseded = {r.supersedes_id for r in rows if r.supersedes_id}
    live = [r for r in rows if r.id not in superseded]
    return live[-1] if live else None


def meeting_counts(db: Store, meeting: GsMeeting) -> tuple[int, int]:
    """(present, women present) from the attendance register."""
    present_member_ids = [a.gs_member_id for a in meeting.attendance if a.present]
    if not present_member_ids:
        return 0, 0
    women_count = db.count(
        GsMember,
        {
            "_id": {"$in": present_member_ids},
            "gender": Gender.FEMALE.value,
        },
    )
    return len(present_member_ids), women_count


def claimant_counts(db: Store, meeting: GsMeeting, case_id: uuid.UUID) -> tuple[int, int]:
    """(claimants in the case, of whom present at the meeting)."""
    claimants = db.find(CaseClaimant, {"case_id": case_id})
    claimant_ids = {c.gs_member_id for c in claimants}
    if not claimant_ids:
        return 0, 0
    present_ids = {a.gs_member_id for a in meeting.attendance if a.present}
    return len(claimant_ids), len(claimant_ids & present_ids)


def approval_check(db: Store, ctx: CaseContext) -> ApprovalCheckOut:
    """
    The Gram Sabha may forward a CFR claim only with a resolution that passed quorum
    and approved the boundary [Sec 6(1), Rule 12(1)(g)] (BR-04), a closed field
    verification [Rule 12A(1)(2)] (BR-07) and no open overlap [Rule 12(3)] (BR-09).
    """
    case = ctx.case
    items: list[ApprovalPrerequisite] = []
    if case.claim_type is ClaimType.CFR:
        b = boundary.current_boundary(db, case.id)
        approved = bool(b and b.status in (BoundaryStatus.GS_APPROVED, BoundaryStatus.TITLED))
        res = current_resolution(db, case.id)
        items = [
            ApprovalPrerequisite(
                id="resolution",
                ok=res is not None and bool(res.quorum_proof.get("passed")),
                rule="Sec 6(1), Rule 4(2)",
                message_key="approval.resolution_needed",
            ),
            ApprovalPrerequisite(
                id="boundary",
                ok=approved,
                rule="Rule 12(1)(g)",
                message_key="approval.boundary_not_approved",
            ),
            ApprovalPrerequisite(
                id="verification",
                ok=verification_complete(latest_verification(db, case.id)),
                rule="Rule 12A(1)(2)",
                message_key="approval.verification_open",
            ),
            ApprovalPrerequisite(
                id="disputes",
                ok=boundary.open_disputes(db, case.id) == 0,
                rule="Rule 12(3)",
                message_key="approval.dispute_open",
            ),
        ]
    return ApprovalCheckOut(case_id=case.id, ready=all(i.ok for i in items), items=items)
