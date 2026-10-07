"""The 60-day expiry rule and the notification wording (no database)."""

from datetime import date

import pytest

from app.domain.expiry import is_overdue, to_gram_sabha, to_villager
from app.domain.workflow import WorkflowError, allowed_actions, decide, resubmit_deadline
from app.models import CaseState, ClaimType, Role, WorkflowAction


def test_overdue_only_after_the_last_day() -> None:
    last_day = resubmit_deadline(date(2026, 10, 1))  # 30-11-2026
    assert not is_overdue(last_day, date(2026, 11, 30))
    assert is_overdue(last_day, date(2026, 12, 1))


def test_villager_is_told_to_file_a_new_claim() -> None:
    m = to_villager(ClaimType.IFR, date(2026, 10, 1))
    assert "01-10-2026" in m.body_en and "60 days" in m.body_en
    assert "file a new claim" in m.body_en and "Form A" in m.body_en
    assert "नवीन दावा दाखल करा" in m.body_mr and "फॉर्म अ" in m.body_mr


def test_gram_sabha_is_told_the_villager_did_nothing() -> None:
    m = to_gram_sabha(ClaimType.CR, "Ramu Bhoye", date(2026, 10, 1))
    assert "Ramu Bhoye" in m.body_en and "did nothing" in m.body_en and "Form B" in m.body_en
    assert "Ramu Bhoye" in m.body_mr and "फॉर्म ब" in m.body_mr


def test_nobody_can_expire_a_claim_by_hand() -> None:
    with pytest.raises(WorkflowError) as e:
        decide(
            state=CaseState.GS_REVIEW,
            action=WorkflowAction.EXPIRE,
            actor_roles={Role.GRAM_SABHA},
            is_creator=False,
        )
    assert e.value.error == "SYSTEM_ONLY"
    buttons = allowed_actions(
        state=CaseState.GS_REVIEW, actor_roles={Role.GRAM_SABHA}, is_creator=False
    )
    assert WorkflowAction.EXPIRE not in buttons


def test_an_expired_claim_is_closed() -> None:
    with pytest.raises(WorkflowError) as e:
        decide(
            state=CaseState.EXPIRED,
            action=WorkflowAction.SUBMIT,
            actor_roles={Role.VILLAGER},
            is_creator=True,
        )
    assert e.value.error == "CASE_CLOSED"
