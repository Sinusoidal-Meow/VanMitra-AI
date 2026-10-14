"""
Label a resource Useful / Partly useful / Not useful (PDF §7).

    U = 0.35 A + 0.25 C + 0.25 S + 0.15 R
    A availability   C condition   S season span (months / 12)   R reach

Any check with no data counts as 0.5 and is reported in `unknown_checks`, so the card can say
"Not yet checked on the ground" (rule L6). `u` is INTERNAL: the user only ever sees the label
(rule L5).
"""

from dataclasses import dataclass, field
from typing import Any

from ..schemas import WATER_KINDS, Label, Reason, ResourceKind
from .config import DEFAULT_CONFIG, LivelihoodConfig

_CONDITION = {"good": 1.0, "fair": 0.6, "poor": 0.2}


@dataclass(frozen=True)
class ResourceLabel:
    label: Label
    u: float  # internal only
    reason: Reason
    unknown_checks: list[str] = field(default_factory=list)


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def availability(kind: ResourceKind, attrs: dict[str, Any]) -> float | None:
    """Holds water / produces in the main season? Only water layers say so from map data."""
    if kind in WATER_KINDS:
        if attrs.get("dry") is True:
            return 0.0
        perennial = attrs.get("perennial")
        if perennial is True:
            return 1.0
        if perennial is False:
            return 0.5  # seasonal
    return None


def condition(attrs: dict[str, Any]) -> float | None:
    """Working, not silted or broken?"""
    named = attrs.get("condition")
    if named in _CONDITION:
        return _CONDITION[named]
    if attrs.get("silted") is True or attrs.get("working") is False:
        return 0.2
    if attrs.get("working") is True or attrs.get("silted") is False:
        return 1.0
    return None


def season_span(attrs: dict[str, Any]) -> float | None:
    """Months a year it can be used, divided by 12."""
    months = attrs.get("months_available")
    if isinstance(months, bool) or not isinstance(months, int | float):
        return None
    return _clamp(months / 12)


def reach(
    distance_m: float, attrs: dict[str, Any], cfg: LivelihoodConfig = DEFAULT_CONFIG
) -> float:
    """Can he get to it? Distance bands, lowered a little when there is known to be no road."""
    value = cfg.reach_beyond
    for limit_m, band in cfg.reach_bands:
        if distance_m <= limit_m:
            value = band
            break
    if attrs.get("road_access") is False:
        value *= cfg.no_road_factor
    return _clamp(value)


def label_for(u: float, cfg: LivelihoodConfig = DEFAULT_CONFIG) -> Label:
    if u >= cfg.useful_min:
        return Label.USEFUL
    if u >= cfg.partly_min:
        return Label.PARTLY_USEFUL
    return Label.NOT_USEFUL


def _reason(
    kind: ResourceKind,
    a: float | None,
    c: float | None,
    s: float | None,
    r: float,
    attrs: dict[str, Any],
    distance_m: float,
    label: Label,
) -> Reason:
    """The one-line reason: the most telling problem, else a good/not-checked note."""
    months = attrs.get("months_available")
    if a == 0.0:
        return Reason(key="reason.water_dry")
    if c is not None and c <= 0.2:
        return Reason(
            key="reason.silted" if attrs.get("silted") is True else "reason.poor_condition"
        )
    if kind in WATER_KINDS and s is not None and s < 1.0 and isinstance(months, int | float):
        return Reason(key="reason.low_water_months", params={"months": int(months)})
    if r <= 0.4:
        return Reason(key="reason.far_from_you", params={"distance_m": round(distance_m)})
    if a is None and c is None and s is None:
        return Reason(key="reason.not_checked")
    if label is Label.USEFUL:
        # only claim "good all round" when every check had data
        if a is None or c is None or s is None:
            return Reason(key="reason.good_on_what_is_known")
        return Reason(key="reason.good_all_round")
    return Reason(key="reason.not_fully_checked")


def label_resource(
    kind: ResourceKind,
    attrs: dict[str, Any],
    distance_m: float,
    cfg: LivelihoodConfig = DEFAULT_CONFIG,
) -> ResourceLabel:
    a = availability(kind, attrs)
    c = condition(attrs)
    s = season_span(attrs)
    r = reach(distance_m, attrs, cfg)

    unknown = [
        name
        for name, value in (("availability", a), ("condition", c), ("season", s))
        if value is None
    ]
    u = (
        cfg.w_a * (cfg.neutral if a is None else a)
        + cfg.w_c * (cfg.neutral if c is None else c)
        + cfg.w_s * (cfg.neutral if s is None else s)
        + cfg.w_r * r
    )
    u = _clamp(u)
    label = label_for(u, cfg)
    return ResourceLabel(label, u, _reason(kind, a, c, s, r, attrs, distance_m, label), unknown)
