"""Form B catalogue, completeness and input validation (no database)."""

from typing import Any

import pytest
from pydantic import ValidationError

from app.domain.form_b import FORM_B_RIGHTS, form_b_completeness
from app.models import EvidenceRule, FormBRight
from app.schemas.form_b import FormBInput

VILLAGE = ("ओझर", "Ozhar", "Jawhar", "Palghar")


def test_catalogue_follows_the_printed_form() -> None:
    """Annexure I, Form B, 'Nature of community rights enjoyed', items 1-6."""
    assert [(r.form_item, r.code, r.section) for r in FORM_B_RIGHTS] == [
        ("1", FormBRight.NISTAR, "Section 3(1)(b)"),
        ("2", FormBRight.MINOR_FOREST_PRODUCE, "Section 3(1)(c)"),
        ("3(a)", FormBRight.WATER_BODIES, "Section 3(1)(d)"),
        ("3(b)", FormBRight.GRAZING, "Section 3(1)(d)"),
        ("3(c)", FormBRight.NOMADIC_PASTORAL_ACCESS, "Section 3(1)(d)"),
        ("4", FormBRight.HABITAT, "Section 3(1)(e)"),
        ("5", FormBRight.BIODIVERSITY_KNOWLEDGE, "Section 3(1)(k)"),
        ("6", FormBRight.OTHER_TRADITIONAL, "Section 3(1)(l)"),
    ]
    assert {r.code for r in FORM_B_RIGHTS} == set(FormBRight)


def _completeness(**overrides: Any) -> dict[str, bool]:
    args: dict[str, Any] = {
        "village_fields": VILLAGE,
        "claimant_names": ["Ozhar Gram Sabha"],
        "is_fdst_community": True,
        "is_otfd_community": False,
        "claimed_rights": [FormBRight.NISTAR],
        "evidence_rules": [EvidenceRule.R13_1_A, EvidenceRule.R13_1_I],
    }
    args.update(overrides)
    c = form_b_completeness(**args)
    assert c.total == 5
    return {i.id: i.ok for i in c.items}


def test_complete_form() -> None:
    assert all(_completeness().values())


def test_empty_draft() -> None:
    result = _completeness(
        claimant_names=[],
        is_fdst_community=None,
        is_otfd_community=None,
        claimed_rights=[],
        evidence_rules=[],
    )
    assert result == {"B-1": False, "B-2": False, "B-3": True, "B-4": False, "B-5": False}


def test_both_status_questions_must_be_answered() -> None:
    assert _completeness(is_otfd_community=None)["B-2"] is False
    # "No" is an answer: completeness never judges eligibility (rule R1/R2).
    assert _completeness(is_fdst_community=False, is_otfd_community=False)["B-2"] is True


def test_rule_11_1_a_needs_two_evidences() -> None:
    assert _completeness(evidence_rules=[EvidenceRule.R13_1_A])["B-5"] is False
    assert _completeness(evidence_rules=[EvidenceRule.R13_1_A] * 2)["B-5"] is True


def test_blank_village_field_is_incomplete() -> None:
    assert _completeness(village_fields=("ओझर", " ", "Jawhar", "Palghar"))["B-3"] is False


def test_input_accepts_partial_draft() -> None:
    form = FormBInput.model_validate({})
    assert form.claimant_names == []
    assert form.rights == {}


def test_input_strips_and_rejects_blank_names() -> None:
    assert FormBInput.model_validate({"claimant_names": ["  Ozhar  "]}).claimant_names == ["Ozhar"]
    with pytest.raises(ValidationError):
        FormBInput.model_validate({"claimant_names": ["   "]})


def test_input_rejects_duplicate_names() -> None:
    with pytest.raises(ValidationError, match="duplicate"):
        FormBInput.model_validate({"claimant_names": ["Ozhar", "ozhar"]})


def test_input_rejects_unknown_right_and_rule() -> None:
    with pytest.raises(ValidationError):
        FormBInput.model_validate({"rights": {"mining": {"details": "x"}}})
    with pytest.raises(ValidationError):
        FormBInput.model_validate({"evidence": [{"rule_ref": "13(3)", "description": "x"}]})


def test_claimed_right_needs_details() -> None:
    with pytest.raises(ValidationError):
        FormBInput.model_validate({"rights": {"nistar": {"details": ""}}})
