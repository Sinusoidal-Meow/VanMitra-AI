"""The three-level claim path (domain.workflow), without a database."""

import pytest

from app.domain.workflow import WorkflowError, allowed_actions, can_view, decide
from app.models import CaseState, Role, WorkflowAction

S, A = CaseState, WorkflowAction
DISTRICT = {Role.COLLECTOR, Role.DFO, Role.TRIBAL_WELFARE_OFFICER}


def _do(state: CaseState, action: WorkflowAction, roles: set[Role], **kw: object) -> CaseState:
    return decide(state=state, action=action, actor_roles=roles, **kw).to_state  # type: ignore[arg-type]


def test_happy_path_to_title() -> None:
    state = _do(S.DRAFT, A.SUBMIT, {Role.VILLAGER}, is_creator=True)
    assert state is S.GS_REVIEW
    state = _do(state, A.APPROVE, {Role.GRAM_SABHA}, is_creator=False)
    assert state is S.SDO_REVIEW
    state = _do(state, A.APPROVE, {Role.SDO}, is_creator=False)
    assert state is S.DISTRICT_REVIEW
    approvals: set[Role] = set()
    for officer in (Role.DFO, Role.TRIBAL_WELFARE_OFFICER, Role.COLLECTOR):
        d = decide(
            state=state,
            action=A.APPROVE,
            actor_roles={officer},
            is_creator=False,
            district_approvals=approvals,
        )
        approvals = set(d.district_approvals)
        state = d.to_state
    assert state is S.TITLE_ISSUED
    assert approvals == DISTRICT


def test_title_waits_for_all_three_officers() -> None:
    d = decide(
        state=S.DISTRICT_REVIEW,
        action=A.APPROVE,
        actor_roles={Role.COLLECTOR},
        is_creator=False,
        district_approvals={Role.DFO},
    )
    assert d.to_state is S.DISTRICT_REVIEW
    assert d.district_approvals == {Role.DFO, Role.COLLECTOR}


def test_officer_cannot_approve_twice() -> None:
    with pytest.raises(WorkflowError) as e:
        decide(
            state=S.DISTRICT_REVIEW,
            action=A.APPROVE,
            actor_roles={Role.DFO},
            is_creator=False,
            district_approvals={Role.DFO},
        )
    assert e.value.error == "ALREADY_APPROVED"


@pytest.mark.parametrize(
    ("state", "role", "back_to"),
    [
        (S.GS_REVIEW, Role.GRAM_SABHA, S.DRAFT),
        (S.SDO_REVIEW, Role.SDO, S.GS_REVIEW),
        (S.DISTRICT_REVIEW, Role.DFO, S.SDO_REVIEW),
    ],
)
def test_return_goes_one_level_down(state: CaseState, role: Role, back_to: CaseState) -> None:
    assert _do(state, A.RETURN, {role}, is_creator=False, remarks="Add the 7/12") is back_to


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


def test_reject_is_final() -> None:
    assert (
        _do(S.DISTRICT_REVIEW, A.REJECT, {Role.COLLECTOR}, is_creator=False, remarks="Reasons...")
        is S.REJECTED
    )
    with pytest.raises(WorkflowError) as e:
        decide(state=S.REJECTED, action=A.APPROVE, actor_roles={Role.COLLECTOR}, is_creator=False)
    assert e.value.error == "CASE_CLOSED"


def test_wrong_level_cannot_act() -> None:
    with pytest.raises(WorkflowError) as e:
        decide(
            state=S.SDO_REVIEW, action=A.APPROVE, actor_roles={Role.GRAM_SABHA}, is_creator=False
        )
    assert e.value.status == 403
    with pytest.raises(WorkflowError):
        decide(state=S.GS_REVIEW, action=A.APPROVE, actor_roles={Role.SDO}, is_creator=False)


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
    already = allowed_actions(
        state=S.DISTRICT_REVIEW,
        actor_roles={Role.DFO},
        is_creator=False,
        district_approvals={Role.DFO},
    )
    assert A.APPROVE not in already and A.RETURN in already
    assert allowed_actions(state=S.TITLE_ISSUED, actor_roles=DISTRICT, is_creator=False) == []


def test_visibility_by_level() -> None:
    assert can_view(roles=set(), is_creator=True, reached_stage=0)
    assert not can_view(roles={Role.GRAM_SABHA}, is_creator=False, reached_stage=0)
    assert can_view(roles={Role.GRAM_SABHA}, is_creator=False, reached_stage=1)
    assert not can_view(roles={Role.SDO}, is_creator=False, reached_stage=1)
    assert can_view(roles={Role.SDO}, is_creator=False, reached_stage=2)
    assert not can_view(roles={Role.COLLECTOR}, is_creator=False, reached_stage=2)
    assert can_view(roles={Role.COLLECTOR}, is_creator=False, reached_stage=3)
    assert not can_view(roles={Role.VILLAGER}, is_creator=False, reached_stage=4)  # others' claims
