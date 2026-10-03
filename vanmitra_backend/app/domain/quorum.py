"""
Quorum of a Gram Sabha meeting [Rule 4(2)] (BR-03). Three tests, all must pass:

    t1  present           >= ceil(registered / 2)
    t2  women present     >= ceil(present / 3)
    t3  claimants present >= ceil(claimants / 2)    (resolutions on claims only)

The inputs and the result are stored with the resolution and never recomputed.
"""

import math
from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass(frozen=True)
class QuorumResult:
    registered: int
    present: int
    women_present: int
    claimants_total: int
    claimants_present: int
    required_present: int
    required_women: int
    required_claimants: int
    t1: bool
    t2: bool
    t3: bool
    passed: bool
    failures: list[str] = field(default_factory=list)  # message keys

    def proof(self) -> dict[str, Any]:
        return asdict(self)


def quorum(
    *,
    registered: int,
    present: int,
    women_present: int,
    claimants_total: int = 0,
    claimants_present: int = 0,
) -> QuorumResult:
    required_present = math.ceil(registered / 2)
    required_women = math.ceil(present / 3)
    required_claimants = math.ceil(claimants_total / 2)
    t1 = registered > 0 and present >= required_present
    t2 = present > 0 and women_present >= required_women
    t3 = claimants_present >= required_claimants
    failures = [
        key
        for key, ok in (
            ("quorum.t1_present", t1),
            ("quorum.t2_women", t2),
            ("quorum.t3_claimants", t3),
        )
        if not ok
    ]
    return QuorumResult(
        registered=registered,
        present=present,
        women_present=women_present,
        claimants_total=claimants_total,
        claimants_present=claimants_present,
        required_present=required_present,
        required_women=required_women,
        required_claimants=required_claimants,
        t1=t1,
        t2=t2,
        t3=t3,
        passed=not failures,
        failures=failures,
    )
