"""The claim path (domain.workflow): villager → Gram Sabha → SDO → district, no database."""

from datetime import date

import pytest

from app.domain.workflow import (
    RESUBMIT_DAYS,
    WorkflowError,
    allowed_actions,
    can_view,
    decide,
    resubmit_deadline,
)
from app.models import CaseState, Role, WorkflowAction

S, A = CaseState, WorkflowAction


def _do(state: CaseState, action: WorkflowAction, roles: set[Role], **kw: object) -> CaseState:
    return decide(state=state, action=action, actor_roles=roles, **kw).to_state  # type: ignore[arg-type]


def test_happy_path_hands_over_to_the_district() -> None:
    state = _do(S.DRAFT, A.SUBMIT, {Role.VILLAGER}, is_creator=True)
    assert state is S.GS_REVIEW
    state = _do(state, A.APPROVE, {Role.GRAM_SABHA}, is_creator=False)
    assert state is S.SDO_REVIEW
    state = _do(state, A.APPROVE, {Role.SDO}, is_creator=False)
    assert state is S.DISTRICT_REVIEW


def test_nothing_more_happens_here_once_handed_to_the_district() -> None:
    for action in (A.SUBMIT, A.APPROVE, A.RETURN, A.REJECT):
        with pytest.raises(WorkflowError) as e:
            decide(
                state=S.DISTRICT_REVIEW,
                action=action,
                actor_roles={Role.SDO, Role.GRAM_SABHA},
                is_creator=True,
                remarks="Something to say",
            )
        assert e.value.error == "HANDED_TO_DISTRICT"


@pytest.mark.parametrize(
    ("state", "role"), [(S.GS_REVIEW, Role.GRAM_SABHA), (S.SDO_REVIEW, Role.SDO)]
)
def test_both_reviewers_send_the_claim_back_to_the_villager(state: CaseState, role: Role) -> None:
    assert _do(state, A.RETURN, {role}, is_creator=False, remarks="Photo is not clear") is S.DRAFT


def test_return_and_reject_need_remarks() -> None:
    for action in (A.RETURN, A.REJECT):
        with pytest.raises(WorkflowError) as e:
            decide(state=S.SDO_REVIEW, action=action, actor_roles={Role.SDO}, is_creator=False)
        assert e.value.error == "REMARKS_REQUIRED"
    with pytest.raises(WorkflowError) as e:
        decide(
            state=S.SDO_REVIEW,
            action=A.REJECT,
            actor_roles={Role.SDO},
            is_creator=False,
            remarks="  ",
        )
    assert e.value.rule == "Rule 12A(7)"


def test_resubmit_deadline_is_sixty_days_after_the_return() -> None:
    assert RESUBMIT_DAYS == 60
    assert resubmit_deadline(date(2026, 10, 1)) == date(2026, 11, 30)


def test_villager_may_resubmit_until_the_last_day() -> None:
    last_day = resubmit_deadline(date(2026, 10, 1))
    on_time = decide(
        state=S.DRAFT,
        action=A.SUBMIT,
        actor_roles={Role.VILLAGER},
        is_creator=True,
        resubmit_by=last_day,
        today=last_day,
    )
    assert on_time.to_state is S.GS_REVIEW
    with pytest.raises(WorkflowError) as e:
        decide(
            state=S.DRAFT,
            action=A.SUBMIT,
            actor_roles={Role.VILLAGER},
            is_creator=True,
            resubmit_by=last_day,
            today=date(2026, 12, 1),
        )
    assert e.value.error == "RESUBMIT_WINDOW_PASSED"


def test_reject_is_final() -> None:
    assert _do(S.SDO_REVIEW, A.REJECT, {Role.SDO}, is_creator=False, remarks="Reasons...") is (
        S.REJECTED
    )
    with pytest.raises(WorkflowError) as e:
        decide(state=S.REJECTED, action=A.APPROVE, actor_roles={Role.SDO}, is_creator=False)
    assert e.value.error == "CASE_CLOSED"


def test_wrong_level_cannot_act() -> None:
    with pytest.raises(WorkflowError) as e:
        decide(
            state=S.SDO_REVIEW, action=A.APPROVE, actor_roles={Role.GRAM_SABHA}, is_creator=False
        )
    assert e.value.status == 403
    with pytest.raises(WorkflowError):
        decide(state=S.GS_REVIEW, action=A.APPROVE, actor_roles={Role.SDO}, is_creator=False)


def test_old_district_logins_have_no_powers() -> None:
    for state in (S.GS_REVIEW, S.SDO_REVIEW):
        with pytest.raises(WorkflowError) as e:
            decide(state=state, action=A.APPROVE, actor_roles={Role.COLLECTOR}, is_creator=False)
        assert e.value.error == "NOT_YOUR_LEVEL"


def test_only_the_claimant_submits() -> None:
    with pytest.raises(WorkflowError) as e:
        decide(state=S.DRAFT, action=A.SUBMIT, actor_roles={Role.VILLAGER}, is_creator=False)
    assert e.value.error == "ONLY_CLAIMANT_CAN_SUBMIT"
    # an official who somehow created nothing cannot submit
    with pytest.raises(WorkflowError):
        decide(state=S.DRAFT, action=A.SUBMIT, actor_roles={Role.SDO}, is_creator=True)


def test_gram_sabha_files_its_own_form_c() -> None:
    d = decide(state=S.DRAFT, action=A.SUBMIT, actor_roles={Role.GRAM_SABHA}, is_creator=True)
    assert d.to_state is S.GS_REVIEW
    assert d.acting_role is Role.GRAM_SABHA


def test_allowed_actions_for_buttons() -> None:
    assert allowed_actions(state=S.DRAFT, actor_roles={Role.VILLAGER}, is_creator=True) == [
        A.SUBMIT
    ]
    assert set(allowed_actions(state=S.SDO_REVIEW, actor_roles={Role.SDO}, is_creator=False)) == {
        A.APPROVE,
        A.RETURN,
        A.REJECT,
    }
    expired = allowed_actions(
        state=S.DRAFT,
        actor_roles={Role.VILLAGER},
        is_creator=True,
        resubmit_by=date(2000, 1, 1),
    )
    assert expired == []
    assert allowed_actions(state=S.DISTRICT_REVIEW, actor_roles={Role.SDO}, is_creator=False) == []


def test_visibility_by_level() -> None:
    assert can_view(roles=set(), is_creator=True, reached_stage=0)
    assert not can_view(roles={Role.GRAM_SABHA}, is_creator=False, reached_stage=0)
    assert can_view(roles={Role.GRAM_SABHA}, is_creator=False, reached_stage=1)
    assert not can_view(roles={Role.SDO}, is_creator=False, reached_stage=1)
    assert can_view(roles={Role.SDO}, is_creator=False, reached_stage=2)
    assert not can_view(roles={Role.COLLECTOR}, is_creator=False, reached_stage=3)
    assert not can_view(roles={Role.VILLAGER}, is_creator=False, reached_stage=4)  # others' claims
