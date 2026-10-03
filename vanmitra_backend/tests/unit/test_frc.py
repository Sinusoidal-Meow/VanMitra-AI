"""FRC composition [Rule 3(1)] (BR-01) and recusal [Rule 3(3)] (BR-02)."""

from app.domain.frc import FrcCandidate, check_frc, must_recuse
from app.models import Gender, MemberCategory

F, M = Gender.FEMALE, Gender.MALE
ST, OTFD, OTHER = MemberCategory.ST, MemberCategory.OTFD, MemberCategory.OTHER


def _frc(spec: list[tuple[Gender, MemberCategory]]) -> list[FrcCandidate]:
    return [FrcCandidate(str(i), g, c) for i, (g, c) in enumerate(spec)]


def _ok(cands: list[FrcCandidate], has_st: bool = True) -> list[str]:
    return check_frc(cands, gram_sabha_has_st=has_st, chair_id="0", secretary_id="1").failures


def test_valid_committee_of_twelve() -> None:
    # 12 members: 8 ST (= ceil(2*12/3)), 4 women (= ceil(12/3))
    cands = _frc([(F, ST)] * 4 + [(M, ST)] * 4 + [(M, OTFD)] * 4)
    result = check_frc(cands, gram_sabha_has_st=True, chair_id="0", secretary_id="1")
    assert result.ok, result.failures
    assert (result.required_st, result.required_women) == (8, 4)


def test_size_limits() -> None:
    assert "frc.too_few_members" in _ok(_frc([(F, ST)] * 9))
    assert "frc.too_many_members" in _ok(_frc([(F, ST)] * 16))
    assert _ok(_frc([(F, ST)] * 10)) == []
    assert _ok(_frc([(F, ST)] * 15)) == []


def test_two_thirds_scheduled_tribes() -> None:
    cands = _frc([(F, ST)] * 4 + [(M, ST)] * 3 + [(M, OTFD)] * 5)  # 7 ST of 12, needs 8
    assert "frc.too_few_st" in _ok(cands)


def test_st_rule_skipped_when_gram_sabha_has_no_st() -> None:
    cands = _frc([(F, OTFD)] * 4 + [(M, OTHER)] * 6)
    assert _ok(cands, has_st=False) == []
    assert "frc.too_few_st" in _ok(cands, has_st=True)


def test_one_third_women() -> None:
    cands = _frc([(F, ST)] * 3 + [(M, ST)] * 9)  # 3 women of 12, needs 4
    assert "frc.too_few_women" in _ok(cands)


def test_chair_and_secretary_must_be_distinct_members() -> None:
    cands = _frc([(F, ST)] * 4 + [(M, ST)] * 6)
    same = check_frc(cands, gram_sabha_has_st=True, chair_id="0", secretary_id="0")
    assert "frc.chair_and_secretary_same" in same.failures
    outsider = check_frc(cands, gram_sabha_has_st=True, chair_id="99", secretary_id=None)
    assert {"frc.chair_not_a_member", "frc.secretary_not_a_member"} <= set(outsider.failures)


def test_duplicate_member_is_caught() -> None:
    cands = _frc([(F, ST)] * 4 + [(M, ST)] * 6)
    cands.append(cands[0])
    assert "frc.duplicate_member" in _ok(cands)


def test_proof_is_serialisable() -> None:
    proof = check_frc(
        _frc([(F, ST)] * 10), gram_sabha_has_st=True, chair_id="0", secretary_id="1"
    ).proof()
    assert proof["members"] == 10 and proof["ok"] is True


def test_recusal() -> None:
    assert must_recuse("m1", ["m1", "m2"])
    assert not must_recuse("m3", ["m1", "m2"])
    assert not must_recuse(None, ["m1"])
