"""
The daily check: claims sent back to the villager and not resubmitted within the time
allowed are closed, marked expired, and the villager and the village's Gram Sabha are
notified (only those two). Safe to run any number of times, and from more than one
server: a claim is only ever expired once.
"""

import logging
from datetime import date

from ..db import Store
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
from . import ledger, push
from .cases import ReturnInfo, returned_info

log = logging.getLogger(__name__)

SYSTEM_NAME = "VanMitra (automatic)"


def _gram_sabha_users(db: Store, case: ClaimCase, today: date) -> list[AppUser]:
    gs = db.get(GramSabha, case.gram_sabha_id)
    if gs is None:
        return []
    today_iso = today.isoformat()
    roles = db.find(
        UserRole,
        {
            "role": Role.GRAM_SABHA.value,
            "village_id": gs.village_id,
            "valid_from": {"$lte": today_iso},
            "$or": [{"valid_to": None}, {"valid_to": {"$gte": today_iso}}],
        },
    )
    user_ids = {r.user_id for r in roles}
    return [u for uid in user_ids if (u := db.get(AppUser, uid)) is not None]


def _expire(db: Store, case: ClaimCase, back: ReturnInfo, today: date) -> list[Notification]:
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
    notes: list[Notification] = []
    for user_id, msg in [
        (case.created_by_user_id, to_filer),
        *[(u.id, to_gs) for u in _gram_sabha_users(db, case, today)],
    ]:
        if user_id in sent:  # a Gram Sabha that filed its own Form C is told once
            continue
        sent.add(user_id)
        note = db.add(
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
        notes.append(note)
    return notes


def expire_overdue(db: Store, today: date | None = None) -> int:
    """Expire every overdue returned claim; returns how many were expired."""
    today = today or today_ist()
    draft_cases = db.find(ClaimCase, {"state": CaseState.DRAFT.value})
    expired = 0
    notes: list[Notification] = []
    for case in draft_cases:
        back = returned_info(db, case)
        if back is not None and rule.is_overdue(back.resubmit_by, today):
            notes += _expire(db, case, back, today)
            expired += 1
    if expired:
        db.commit()
        log.info("expired %d claim(s) not resubmitted within %d days", expired, RESUBMIT_DAYS)
        push.deliver(db, notes)  # phone push messages, after the notifications are saved
    return expired
