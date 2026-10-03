"""
Forest Rights Committee composition [Rule 3(1)] (BR-01) and recusal [Rule 3(3)] (BR-02).

Rule 3(1): "not less than ten but not exceeding fifteen persons as members of the
Forest Rights Committee, wherein at least two-thirds of the members shall be the
Scheduled Tribes and not less than one-third of such members shall be women;
provided that where there are no Scheduled Tribes, at least one-third of such
members shall be women".
"""

import math
from collections.abc import Iterable, Sequence
from dataclasses import asdict, dataclass, field
from typing import Any

from ..models.enums import Gender, MemberCategory

MIN_MEMBERS = 10
MAX_MEMBERS = 15


@dataclass(frozen=True)
class FrcCandidate:
    member_id: str
    gender: Gender
    category: MemberCategory


@dataclass(frozen=True)
class FrcCheck:
    ok: bool
    members: int
    st: int
    women: int
    required_st: int  # 0 when the Gram Sabha has no Scheduled Tribe members
    required_women: int
    st_rule_applies: bool
    failures: list[str] = field(default_factory=list)  # message keys

    def proof(self) -> dict[str, Any]:
        return asdict(self)


def check_frc(
    candidates: Sequence[FrcCandidate],
    *,
    gram_sabha_has_st: bool,
    chair_id: str | None,
    secretary_id: str | None,
) -> FrcCheck:
    n = len(candidates)
    st = sum(1 for c in candidates if c.category is MemberCategory.ST)
    women = sum(1 for c in candidates if c.gender is Gender.FEMALE)
    required_st = math.ceil(2 * n / 3) if gram_sabha_has_st else 0
    required_women = math.ceil(n / 3)
    ids = {c.member_id for c in candidates}
    failures: list[str] = []
    if len(ids) != n:
        failures.append("frc.duplicate_member")
    if n < MIN_MEMBERS:
        failures.append("frc.too_few_members")
    if n > MAX_MEMBERS:
        failures.append("frc.too_many_members")
    if gram_sabha_has_st and st < required_st:
        failures.append("frc.too_few_st")
    if women < required_women:
        failures.append("frc.too_few_women")
    if chair_id is None or chair_id not in ids:
        failures.append("frc.chair_not_a_member")
    if secretary_id is None or secretary_id not in ids:
        failures.append("frc.secretary_not_a_member")
    if chair_id is not None and chair_id == secretary_id:
        failures.append("frc.chair_and_secretary_same")
    return FrcCheck(
        ok=not failures,
        members=n,
        st=st,
        women=women,
        required_st=required_st,
        required_women=required_women,
        st_rule_applies=gram_sabha_has_st,
        failures=failures,
    )


def must_recuse(member_id: str | None, claimant_ids: Iterable[str]) -> bool:
    """BR-02: an FRC member who is a claimant in a case may not verify that case."""
    return member_id is not None and member_id in set(claimant_ids)
