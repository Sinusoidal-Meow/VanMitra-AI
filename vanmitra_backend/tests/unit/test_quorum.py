"""The three quorum tests of Rule 4(2) (BR-03)."""

import pytest

from app.domain.quorum import quorum

BASE = {
    "registered": 100,
    "present": 50,
    "women_present": 17,
    "claimants_total": 10,
    "claimants_present": 5,
}


def test_all_three_pass() -> None:
    q = quorum(**BASE)
    assert q.passed
    assert (q.required_present, q.required_women, q.required_claimants) == (50, 17, 5)
    assert q.failures == []


@pytest.mark.parametrize(
    ("change", "failure"),
    [
        ({"present": 49, "women_present": 17}, "quorum.t1_present"),
        ({"women_present": 16}, "quorum.t2_women"),
        ({"claimants_present": 4}, "quorum.t3_claimants"),
    ],
)
def test_each_test_fails_alone_at_the_boundary(change: dict[str, int], failure: str) -> None:
    q = quorum(**{**BASE, **change})
    assert not q.passed
    assert q.failures == [failure]


def test_rounding_goes_up() -> None:
    q = quorum(registered=101, present=51, women_present=17, claimants_total=3, claimants_present=2)
    assert q.required_present == 51
    assert q.required_claimants == 2
    assert q.passed


def test_no_claimants_means_the_third_test_is_met() -> None:
    assert quorum(registered=10, present=5, women_present=2).t3


def test_empty_meeting_never_passes() -> None:
    assert not quorum(registered=0, present=0, women_present=0).passed
    assert not quorum(registered=10, present=0, women_present=0).passed


def test_proof_is_plain_data() -> None:
    proof = quorum(registered=10, present=5, women_present=2).proof()
    assert proof["passed"] is True
    assert proof["registered"] == 10
