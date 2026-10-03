"""Form C completeness, member sheet and input validation (no database)."""

from typing import Any

import pytest
from pydantic import ValidationError

from app.domain.form_c import (
    DEFAULT_RESOLUTION_STATEMENT,
    form_c_completeness,
    member_sheet_counts,
)
from app.models import BoundarySide, EvidenceRule, MemberCategory
from app.schemas.form_c import FormCInput

VILLAGE = ("ओझर", "Ozar", "Jawhar", "Palghar")
ALL_SIDES = [BoundarySide.EAST, BoundarySide.WEST, BoundarySide.NORTH, BoundarySide.SOUTH]


def _check(**overrides: Any) -> dict[str, bool]:
    args: dict[str, Any] = {
        "village_fields": VILLAGE,
        "members": member_sheet_counts([MemberCategory.ST, MemberCategory.OTHER]),
        "resolution_statement": DEFAULT_RESOLUTION_STATEMENT,
        "area_description": "Forest east of the village up to the Nagdevta stream",
        "landmark_sides": ALL_SIDES,
        "bordering_village_count": 1,
        "evidence_rules": [EvidenceRule.R13_1_A, EvidenceRule.R13_1_I, EvidenceRule.R13_2_B],
    }
    args.update(overrides)
    c = form_c_completeness(**args)
    assert c.total == 8
    return {i.id: i.ok for i in c.items}


def test_complete_form_c() -> None:
    assert all(_check().values())


def test_new_draft_only_has_registry_and_default_statement() -> None:
    result = _check(
        members=member_sheet_counts([]),
        area_description=None,
        landmark_sides=[],
        bordering_village_count=0,
        evidence_rules=[],
    )
    assert [k for k, ok in result.items() if ok] == ["FC-1", "FC-3"]


def test_member_sheet_needs_a_few_st_or_otfd() -> None:
    """Form C item 5: the presence of a few ST/OTFD members is sufficient."""
    assert _check(members=member_sheet_counts([MemberCategory.OTHER] * 5))["FC-2"] is False
    one_otfd = member_sheet_counts([MemberCategory.OTHER] * 9 + [MemberCategory.OTFD])
    assert _check(members=one_otfd)["FC-2"] is True


def test_all_four_boundaries_need_a_landmark() -> None:
    three = [BoundarySide.EAST, BoundarySide.WEST, BoundarySide.NORTH, BoundarySide.WITHIN]
    assert _check(landmark_sides=three)["FC-5"] is False


def test_cfr_claim_needs_rule_13_2_evidence() -> None:
    general_only = [EvidenceRule.R13_1_A, EvidenceRule.R13_1_B, EvidenceRule.R13_1_I]
    result = _check(evidence_rules=general_only)
    assert result["FC-7"] is True
    assert result["FC-8"] is False


def test_two_general_evidences_needed() -> None:
    result = _check(evidence_rules=[EvidenceRule.R13_1_A, EvidenceRule.R13_2_A])
    assert result["FC-7"] is False
    assert result["FC-8"] is True


def test_member_sheet_counts() -> None:
    counts = member_sheet_counts(
        [MemberCategory.ST, MemberCategory.ST, MemberCategory.OTFD, MemberCategory.OTHER]
    )
    assert (counts.total, counts.st, counts.otfd) == (4, 2, 1)


def test_input_accepts_empty_draft() -> None:
    form = FormCInput.model_validate({})
    assert form.resolution_statement is None
    assert form.landmarks == []
    assert form.khasra_compartment_numbers == []  # item 6 is optional


def test_input_rejects_bad_side_kind_and_area() -> None:
    with pytest.raises(ValidationError):
        FormCInput.model_validate({"landmarks": [{"side": "up", "kind": "pond", "name": "x"}]})
    with pytest.raises(ValidationError):
        FormCInput.model_validate({"landmarks": [{"side": "east", "kind": "mall", "name": "x"}]})
    with pytest.raises(ValidationError):
        FormCInput.model_validate({"approx_area_ha": -1})


def test_landmark_needs_a_name() -> None:
    with pytest.raises(ValidationError):
        FormCInput.model_validate({"landmarks": [{"side": "east", "kind": "pond", "name": " "}]})
