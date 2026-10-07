"""
The claim path in this backend: four access levels, of which three are ours.

    DRAFT ──submit──▶ GS_REVIEW ──approve──▶ SDO_REVIEW ──approve──▶ DISTRICT_REVIEW
      ▲                 │                       │                    (handed over to the
      │   return        │                       │                     district website)
      └─ with remarks ──┴───────────────────────┘
                        reject (reasons) ──────────────────────────▶ REJECTED

- The Gram Sabha and the SDO each verify the claim. Either of them can send it back
  straight to the villager, with a remark saying what is wrong.
- The villager then has RESUBMIT_DAYS days from the day it was sent back to correct it
  and submit it again. The claim starts again at the Gram Sabha.
- When the SDO approves, the claim is handed over to the district level, which is a
  separate website (built by another team member). Nothing more happens here.
- DISTRICT_REVIEW therefore means "handed over to the district". TITLE_ISSUED is only set
  when the district side reports the signed title.

Rules:
- Only the claimant who created the draft may submit it (village user or Gram Sabha).
- Each level is reviewed only by its own role, within its jurisdiction (checked by caller).
- Return and reject need written remarks; a rejection must give reasons [Rule 12A(7)].
- A claim not resubmitted in time is closed automatically as EXPIRED (see domain.expiry).
- REJECTED, EXPIRED, TITLE_ISSUED and a claim handed to the district are final here.
"""

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import date, timedelta

from ..models.enums import CaseState, Role, WorkflowAction
from .dates import today_ist

MIN_REMARKS_LENGTH = 5
RESUBMIT_DAYS = 60  # the villager's time to correct and resubmit a returned claim

STAGE: dict[CaseState, int] = {
    CaseState.DRAFT: 0,
    CaseState.GS_REVIEW: 1,
    CaseState.SDO_REVIEW: 2,
    CaseState.DISTRICT_REVIEW: 3,
    CaseState.TITLE_ISSUED: 4,
}

REVIEWERS: dict[CaseState, frozenset[Role]] = {
    CaseState.GS_REVIEW: frozenset({Role.GRAM_SABHA}),
    CaseState.SDO_REVIEW: frozenset({Role.SDO}),
}

APPROVE_TO: dict[CaseState, CaseState] = {
    CaseState.GS_REVIEW: CaseState.SDO_REVIEW,
    CaseState.SDO_REVIEW: CaseState.DISTRICT_REVIEW,
}

# Both reviewers send a claim straight back to the villager.
RETURN_TO = CaseState.DRAFT

FINAL_STATES = frozenset({CaseState.TITLE_ISSUED, CaseState.REJECTED, CaseState.EXPIRED})


class WorkflowError(Exception):
    """An action that is not allowed; `status` is the HTTP code the API should use."""

    def __init__(self, status: int, error: str, message_key: str, rule: str | None = None):
        super().__init__(error)
        self.status = status
        self.error = error
        self.message_key = message_key
        self.rule = rule


@dataclass(frozen=True)
class Decision:
    to_state: CaseState
    acting_role: Role


def resubmit_deadline(returned_on: date) -> date:
    """The last day on which the villager may resubmit a claim returned on `returned_on`."""
    return returned_on + timedelta(days=RESUBMIT_DAYS)


def decide(
    *,
    state: CaseState,
    action: WorkflowAction,
    actor_roles: Iterable[Role],
    is_creator: bool,
    remarks: str | None = None,
    resubmit_by: date | None = None,
    today: date | None = None,
) -> Decision:
    """
    The outcome of `action` by a user holding `actor_roles` (already jurisdiction-filtered).
    `resubmit_by` is the deadline of a returned claim, if this draft was sent back.
    """
    roles = set(actor_roles)

    if action is WorkflowAction.EXPIRE:  # only the daily check expires a claim
        raise WorkflowError(403, "SYSTEM_ONLY", "workflow.system_only")
    if state is CaseState.DISTRICT_REVIEW:
        raise WorkflowError(409, "HANDED_TO_DISTRICT", "workflow.handed_to_district")
    if state in FINAL_STATES:
        raise WorkflowError(409, "CASE_CLOSED", "workflow.case_closed")

    if action is WorkflowAction.SUBMIT:
        if state is not CaseState.DRAFT:
            raise WorkflowError(409, "NOT_A_DRAFT", "workflow.not_a_draft")
        filer = roles & {Role.VILLAGER, Role.GRAM_SABHA}
        if not is_creator or not filer:
            raise WorkflowError(403, "ONLY_CLAIMANT_CAN_SUBMIT", "workflow.only_claimant_submits")
        if resubmit_by is not None and (today or today_ist()) > resubmit_by:
            raise WorkflowError(409, "RESUBMIT_WINDOW_PASSED", "workflow.resubmit_window_passed")
        acting = Role.GRAM_SABHA if Role.GRAM_SABHA in filer else Role.VILLAGER
        return Decision(CaseState.GS_REVIEW, acting)

    reviewers = REVIEWERS.get(state)
    if reviewers is None:
        raise WorkflowError(409, "NOT_UNDER_REVIEW", "workflow.not_under_review")
    held = roles & reviewers
    if not held:
        raise WorkflowError(403, "NOT_YOUR_LEVEL", "workflow.not_your_level")

    if action in (WorkflowAction.RETURN, WorkflowAction.REJECT):
        if not remarks or len(remarks.strip()) < MIN_REMARKS_LENGTH:
            raise WorkflowError(
                422,
                "REMARKS_REQUIRED",
                "workflow.remarks_required",
                "Rule 12A(7)" if action is WorkflowAction.REJECT else None,
            )
        acting = _pick(held)
        if action is WorkflowAction.RETURN:
            return Decision(RETURN_TO, acting)
        return Decision(CaseState.REJECTED, acting)

    return Decision(APPROVE_TO[state], _pick(held))  # APPROVE


def allowed_actions(
    *,
    state: CaseState,
    actor_roles: Iterable[Role],
    is_creator: bool,
    resubmit_by: date | None = None,
) -> list[WorkflowAction]:
    """What the caller may do now (for the app to show only valid buttons)."""
    out = []
    for action in WorkflowAction:
        try:
            decide(
                state=state,
                action=action,
                actor_roles=actor_roles,
                is_creator=is_creator,
                remarks="x" * MIN_REMARKS_LENGTH,
                resubmit_by=resubmit_by,
            )
        except WorkflowError:
            continue
        out.append(action)
    return out


def can_view(*, roles: Iterable[Role], is_creator: bool, reached_stage: int) -> bool:
    """
    The claimant always sees their case. The Gram Sabha sees a case once it has been
    filed to it; the SDO once it reached the SDO. `roles` must already be filtered to
    those covering the case's village.
    """
    held = set(roles)
    if is_creator:
        return True
    if Role.GRAM_SABHA in held and reached_stage >= STAGE[CaseState.GS_REVIEW]:
        return True
    return Role.SDO in held and reached_stage >= STAGE[CaseState.SDO_REVIEW]


def _pick(roles: set[Role]) -> Role:
    """Deterministic choice when a user holds more than one eligible role."""
    order = list(Role)
    return min(roles, key=order.index)
