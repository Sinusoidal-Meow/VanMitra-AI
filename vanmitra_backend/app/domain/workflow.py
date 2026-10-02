"""
Module 3 claim workflow: three levels of review.

    DRAFT ──submit──▶ GS_REVIEW ──approve──▶ SDO_REVIEW ──approve──▶ DISTRICT_REVIEW
      ▲                  │  return (remarks)    │  return → GS_REVIEW    │  return → SDO_REVIEW
      └──────────────────┘                      │                        │
                         reject (reasons) ──────┴────────────────────────┴──▶ REJECTED
    DISTRICT_REVIEW: the Collector, DFO and District Tribal Welfare Officer each approve;
    when all three have approved, the case moves to TITLE_ISSUED and the title draft
    (Annexure II / III / IV) is produced with the three of them as signatories [Rule 8(h)(i)].

Rules:
- Only the claimant who created the draft may submit it (village user or Gram Sabha).
- Each level is reviewed only by its own role, within its jurisdiction (checked by caller).
- Return and reject need written remarks; a rejection must give reasons [Rule 12A(7)].
- Approval at the district level is per officer; one officer cannot approve twice.
- TITLE_ISSUED and REJECTED are final in this module.
"""

from collections.abc import Iterable
from dataclasses import dataclass

from ..models.enums import DISTRICT_ROLES, CaseState, Role, WorkflowAction

MIN_REMARKS_LENGTH = 5

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
    CaseState.DISTRICT_REVIEW: frozenset(DISTRICT_ROLES),
}

APPROVE_TO: dict[CaseState, CaseState] = {
    CaseState.GS_REVIEW: CaseState.SDO_REVIEW,
    CaseState.SDO_REVIEW: CaseState.DISTRICT_REVIEW,
}

RETURN_TO: dict[CaseState, CaseState] = {
    CaseState.GS_REVIEW: CaseState.DRAFT,
    CaseState.SDO_REVIEW: CaseState.GS_REVIEW,
    CaseState.DISTRICT_REVIEW: CaseState.SDO_REVIEW,
}

FINAL_STATES = frozenset({CaseState.TITLE_ISSUED, CaseState.REJECTED})


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
    district_approvals: frozenset[Role]  # after this action (district level only)


def decide(
    *,
    state: CaseState,
    action: WorkflowAction,
    actor_roles: Iterable[Role],
    is_creator: bool,
    district_approvals: Iterable[Role] = (),
    remarks: str | None = None,
) -> Decision:
    """The outcome of `action` by a user holding `actor_roles` (already jurisdiction-filtered)."""
    roles = set(actor_roles)
    approvals = frozenset(district_approvals)

    if state in FINAL_STATES:
        raise WorkflowError(409, "CASE_CLOSED", "workflow.case_closed")

    if action is WorkflowAction.SUBMIT:
        if state is not CaseState.DRAFT:
            raise WorkflowError(409, "NOT_A_DRAFT", "workflow.not_a_draft")
        filer = roles & {Role.VILLAGER, Role.GRAM_SABHA}
        if not is_creator or not filer:
            raise WorkflowError(403, "ONLY_CLAIMANT_CAN_SUBMIT", "workflow.only_claimant_submits")
        acting = Role.GRAM_SABHA if Role.GRAM_SABHA in filer else Role.VILLAGER
        return Decision(CaseState.GS_REVIEW, acting, frozenset())

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
            return Decision(RETURN_TO[state], acting, frozenset())
        return Decision(CaseState.REJECTED, acting, frozenset())

    # APPROVE
    if state is CaseState.DISTRICT_REVIEW:
        pending = held - approvals
        if not pending:
            raise WorkflowError(409, "ALREADY_APPROVED", "workflow.already_approved")
        acting = _pick(pending)
        after = approvals | {acting}
        done = after >= set(DISTRICT_ROLES)
        return Decision(
            CaseState.TITLE_ISSUED if done else CaseState.DISTRICT_REVIEW, acting, after
        )
    return Decision(APPROVE_TO[state], _pick(held), frozenset())


def allowed_actions(
    *,
    state: CaseState,
    actor_roles: Iterable[Role],
    is_creator: bool,
    district_approvals: Iterable[Role] = (),
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
                district_approvals=district_approvals,
                remarks="x" * MIN_REMARKS_LENGTH,
            )
        except WorkflowError:
            continue
        out.append(action)
    return out


def can_view(*, roles: Iterable[Role], is_creator: bool, reached_stage: int) -> bool:
    """
    The claimant always sees their case. The Gram Sabha sees a case once it has been
    filed to it; the SDO once it reached the SDO; district officers once it reached them.
    `roles` must already be filtered to those covering the case's village.
    """
    held = set(roles)
    if is_creator:
        return True
    if Role.GRAM_SABHA in held and reached_stage >= STAGE[CaseState.GS_REVIEW]:
        return True
    if Role.SDO in held and reached_stage >= STAGE[CaseState.SDO_REVIEW]:
        return True
    return bool(held & set(DISTRICT_ROLES)) and reached_stage >= STAGE[CaseState.DISTRICT_REVIEW]


def _pick(roles: set[Role]) -> Role:
    """Deterministic choice when a user holds more than one eligible role."""
    order = list(Role)
    return min(roles, key=order.index)
