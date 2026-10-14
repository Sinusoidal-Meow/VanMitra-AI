"""Land-area units used in Maharashtra. Stored in hectares; the app shows the conversion back."""

import math
from enum import StrEnum

ACRE_TO_HA = 0.40468564224
GUNTHA_TO_HA = ACRE_TO_HA / 40  # 40 guntha = 1 acre
WARN_ABOVE_HA = 100.0  # the app asks "please check" above this; never blocks


class AreaUnit(StrEnum):
    HECTARE = "hectare"
    ACRE = "acre"
    GUNTHA = "guntha"


_FACTOR = {AreaUnit.HECTARE: 1.0, AreaUnit.ACRE: ACRE_TO_HA, AreaUnit.GUNTHA: GUNTHA_TO_HA}


def to_hectares(value: float, unit: AreaUnit) -> float:
    """Convert a land area to hectares. Rejects zero, negative and non-finite values."""
    if not math.isfinite(value) or value <= 0:
        raise ValueError("land area must be a positive number")
    return value * _FACTOR[unit]
