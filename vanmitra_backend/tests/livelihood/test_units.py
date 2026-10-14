import math

import pytest

from app.livelihood.domain.units import ACRE_TO_HA, GUNTHA_TO_HA, AreaUnit, to_hectares


def test_hectare_is_identity() -> None:
    assert to_hectares(2.5, AreaUnit.HECTARE) == 2.5


def test_acre_and_guntha() -> None:
    assert to_hectares(1, AreaUnit.ACRE) == pytest.approx(0.4047, abs=1e-4)
    assert to_hectares(40, AreaUnit.GUNTHA) == pytest.approx(to_hectares(1, AreaUnit.ACRE))
    assert pytest.approx(ACRE_TO_HA) == GUNTHA_TO_HA * 40


@pytest.mark.parametrize("bad", [0, -1, math.inf, math.nan])
def test_rejects_non_positive_and_non_finite(bad: float) -> None:
    with pytest.raises(ValueError):
        to_hectares(bad, AreaUnit.ACRE)
