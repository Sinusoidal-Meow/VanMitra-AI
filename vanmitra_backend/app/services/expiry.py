"""
The daily check: claims sent back to the villager and not resubmitted within the time
allowed are closed, marked expired, and the villager and the village's Gram Sabha are
notified (only those two). Safe to run any number of times, and from more than one
server: a claim is only ever expired once.
"""

import logging
from datetime import date

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..domain import expiry as rule
from ..domain.dates import today_ist
from ..domain.workflow import RESUBMIT_DAYS
from ..models import (
    AppUser,
    CaseState,
    ClaimCase,
    GramSabha,
    Role,
    UserRole,
    WorkflowAction,
    WorkflowEvent,
)
from ..models.notifications import Notification
from . import ledger
from .cases import ReturnInfo, returned_info

log = logging.getLogger(__name__)

SYSTEM_NAME = "VanMitra (automatic)"


def _gram_sabha_users(db: Session, case: ClaimCase, today: date) -> list[AppUser]:
    village_id = db.scalar(select(GramSabha.village_id).where(GramSabha.id == case.gram_sabha_id))
    return list(
        db.scalars(
            select(AppUser)
            .join(UserRole, UserRole.user_id == AppUser.id)
            .where(
                UserRole.role == Role.GRAM_SABHA,
                UserRole.village_id == village_id,
                UserRole.valid_from <= today,
                or_(UserRole.valid_to.is_(None), UserRole.valid_to >= today),
            )
        ).unique()
    )


def _expire(db: Session, case: ClaimCase, back: ReturnInfo, today: date) -> None:
    event = WorkflowEvent(
        case_id=case.id,
        action=WorkflowAction.EXPIRE,
        from_state=case.state,
        to_state=CaseState.EXPIRED,
        actor_user_id=None,
        actor_role=None,
        actor_name=SYSTEM_NAME,
        remarks=(
            f"Not resubmitted within {RESUBMIT_DAYS} days of being sent back on "
            f"{back.returned_on.isoformat()}"
        ),
    )
    db.add(event)
    ledger.append(db, case.gram_sabha_id, event)
    case.state = CaseState.EXPIRED

    filer = db.get(AppUser, case.created_by_user_id)
    claimant = filer.name if filer else "the claimant"
    to_filer = rule.to_villager(case.claim_type, back.returned_on)
    to_gs = rule.to_gram_sabha(case.claim_type, claimant, back.returned_on)
    sent: set[object] = set()
    for user_id, msg in [
        (case.created_by_user_id, to_filer),
        *[(u.id, to_gs) for u in _gram_sabha_users(db, case, today)],
    ]:
        if user_id in sent:  # a Gram Sabha that filed its own Form C is told once
            continue
        sent.add(user_id)
        db.add(
            Notification(
                user_id=user_id,
                case_id=case.id,
                kind="claim_expired",
                title_en=msg.title_en,
                body_en=msg.body_en,
                title_mr=msg.title_mr,
                body_mr=msg.body_mr,
            )
        )


def expire_overdue(db: Session, today: date | None = None) -> int:
    """Expire every overdue returned claim; returns how many were expired."""
    today = today or today_ist()
    overdue_ids = []
    for case in db.scalars(select(ClaimCase).where(ClaimCase.state == CaseState.DRAFT)):
        back = returned_info(case)
        if back is not None and rule.is_overdue(back.resubmit_by, today):
            overdue_ids.append(case.id)
    db.rollback()  # release the read snapshot before taking row locks

    expired = 0
    for case_id in overdue_ids:
        # Lock the claim; another server running the same check skips it.
        locked = db.scalar(
            select(ClaimCase).where(ClaimCase.id == case_id).with_for_update(skip_locked=True)
        )
        back = returned_info(locked) if locked is not None else None
        if locked is None or back is None or not rule.is_overdue(back.resubmit_by, today):
            db.rollback()
            continue
        _expire(db, locked, back, today)
        db.commit()
        expired += 1
    if expired:
        log.info("expired %d claim(s) not resubmitted within %d days", expired, RESUBMIT_DAYS)
    return expired
