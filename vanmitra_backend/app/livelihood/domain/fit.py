"""
Rank an idea for one landowner (PDF §9).

    F = 0.35 M + 0.20 K + 0.15 P + 0.15 E + 0.15 G

M resources the idea needs · K market access · P people fit · E ease of start · G green fit.
`F` and its parts are INTERNAL; the user sees only the fit label (rule L5).
"""

from collections.abc import Sequence
from dataclasses import dataclass, field

from ..geo import Nearby
from ..schemas import FitLabel, Idea, Level, ProfileIn, Reason, Tag, WaterOnLand
from .config import DEFAULT_CONFIG, LivelihoodConfig
from .labels import ResourceLabel

_LEVEL_RANK = {Level.LOW: 0, Level.MEDIUM: 1, Level.HIGH: 2}


@dataclass(frozen=True)
class LabelledResource:
    near: Nearby
    label: ResourceLabel

    @property
    def id(self) -> str:
        return self.near.record.id


@dataclass(frozen=True)
class IdeaEval:
    idea: Idea
    f: float  # internal only
    fit: FitLabel
    missing_needs: list[list[str]] = field(default_factory=list)
    resources_used: list[str] = field(default_factory=list)
    nearest_m: int | None = None
    past_work_match: bool = False
    animal_match: bool = False
    flags: list[Reason] = field(default_factory=list)


def fit_label(f: float, cfg: LivelihoodConfig = DEFAULT_CONFIG) -> FitLabel:
    if f >= cfg.good_min:
        return FitLabel.GOOD
    if f >= cfg.fair_min:
        return FitLabel.FAIR
    return FitLabel.WEAK


def _own_asset_present(entry: str, profile: ProfileIn | None) -> bool:
    """An 'asset:x' need is met by what he says he owns, or by the water he reports on his land."""
    if profile is None:
        return False
    code = entry.removeprefix("asset:")
    if code in profile.assets:
        return True
    water = profile.land.water_on_land if profile.land else None
    return (code == "well" and water is WaterOnLand.OPEN_WELL) or (
        code == "borewell" and water is WaterOnLand.BOREWELL
    )


def _match_needs(
    idea: Idea,
    resources: Sequence[LabelledResource],
    profile: ProfileIn | None,
    cfg: LivelihoodConfig,
) -> tuple[float, list[list[str]], list[str], int | None, bool]:
    """
    M: the mean over need-groups of the best way to meet each. A group nothing meets scores 0.
    The last value says whether a COMMUNITY (inside-CFR) resource was used: it still counts, but
    the idea is then flagged "Use only through the Gram Sabha" (rule L3), never "do it alone".
    """
    if not idea.needs:
        return cfg.neutral, [], [], None, False

    usable = list(resources)
    scores: list[float] = []
    missing: list[list[str]] = []
    used: list[str] = []
    distances: list[float] = []
    uses_community = False

    for group in idea.needs:
        best = -1.0
        best_id: str | None = None
        best_distance: float | None = None
        best_community = False
        for entry in group:
            if entry.startswith("asset:"):
                if _own_asset_present(entry, profile) and cfg.told_resource_u > best:
                    best, best_id, best_distance = cfg.told_resource_u, f"told:{entry[6:]}", None
                    best_community = False
                continue
            for r in usable:
                if r.near.record.kind.value == entry and r.label.u > best:
                    best, best_id, best_distance = r.label.u, r.id, r.near.distance_m
                    best_community = r.near.tag is Tag.INSIDE_CFR
        if best_id is None:
            scores.append(0.0)
            missing.append(list(group))
        else:
            scores.append(best)
            used.append(best_id)
            uses_community = uses_community or best_community
            if best_distance is not None:
                distances.append(best_distance)

    nearest = round(min(distances)) if distances else None
    return sum(scores) / len(scores), missing, used, nearest, uses_community


def evaluate_idea(
    idea: Idea,
    *,
    resources: Sequence[LabelledResource],
    profile: ProfileIn | None,
    flood_risk: bool = False,
    hot_area: bool = False,
    protected_near: bool = False,
    cfg: LivelihoodConfig = DEFAULT_CONFIG,
) -> IdeaEval:
    flags: list[Reason] = []

    m, missing, used, nearest, uses_community = _match_needs(idea, resources, profile, cfg)
    if uses_community:
        flags.append(Reason(key="flag.through_gram_sabha"))
    if "flood_sensitive" in idea.tags and flood_risk:
        m *= cfg.flood_factor
        flags.append(Reason(key="flag.possible_flood_risk"))
    if "water_hungry" in idea.tags and hot_area:
        m *= cfg.hot_water_factor
        flags.append(Reason(key="flag.hot_area_water_need"))
    for group in missing:
        flags.append(Reason(key="flag.missing_need", params={"need": group[0]}))

    k = cfg.neutral  # market access: no market layer yet, so everyone gets 0.5

    # P: people fit
    past_work_match = False
    animal_match = False
    p = cfg.neutral
    if profile is not None:
        past_work_match = bool(set(profile.past_work) & set(idea.p_hints.past_work))
        counts = profile.animal_counts
        animal_match = any(counts.get(a, 0) > 0 for a in idea.p_hints.animals)
        p += cfg.p_past_work_bonus if past_work_match else 0.0
        p += cfg.p_animal_bonus if animal_match else 0.0
        p += cfg.p_workers_bonus if (profile.family_workers or 0) >= 2 else 0.0
        p = min(1.0, p)

    # E: ease of start (money, training, and enough land)
    e = idea.ease
    if profile is not None and profile.money_level is not None:
        shortfall = max(0, _LEVEL_RANK[idea.cost_level] - _LEVEL_RANK[profile.money_level])
        match = (1.0, 0.6, 0.2)[shortfall]
        e = (idea.ease + match) / 2
    area = profile.area_ha if profile is not None else None
    if idea.min_land_ha:
        if area is None:
            flags.append(Reason(key="flag.land_unknown", params={"min_ha": idea.min_land_ha}))
        elif area < idea.min_land_ha:
            e *= cfg.land_short_factor
            flags.append(
                Reason(
                    key="flag.needs_more_land",
                    params={"min_ha": idea.min_land_ha, "have_ha": round(area, 2)},
                )
            )

    g = idea.green

    if idea.group_only:
        flags.append(Reason(key="flag.group_only"))
    if idea.through_gram_sabha:
        flags.append(Reason(key="flag.through_gram_sabha"))
    if protected_near:
        flags.append(Reason(key="flag.ask_forest_dept"))

    f = cfg.w_m * m + cfg.w_k * k + cfg.w_p * p + cfg.w_e * e + cfg.w_g * g
    f = max(0.0, min(1.0, f))
    return IdeaEval(
        idea=idea,
        f=f,
        fit=fit_label(f, cfg),
        missing_needs=missing,
        resources_used=used,
        nearest_m=nearest,
        past_work_match=past_work_match,
        animal_match=animal_match,
        flags=flags,
    )


def idea_reason(ev: IdeaEval, cfg: LivelihoodConfig = DEFAULT_CONFIG) -> Reason:
    """One-line reason for the card, as a key plus the facts it needs."""
    near = {"nearest_m": ev.nearest_m} if ev.nearest_m is not None else {}
    if ev.missing_needs:
        return Reason(key="idea.reason.missing_need", params={"need": ev.missing_needs[0][0]})
    if ev.animal_match and ev.resources_used:
        return Reason(key="idea.reason.animals_and_resources", params=near)
    if ev.past_work_match:
        return Reason(key="idea.reason.matches_past_work")
    if ev.idea.through_gram_sabha:
        return Reason(key="idea.reason.community_resource", params=near)
    if ev.resources_used:
        return Reason(key="idea.reason.good_resources_nearby", params=near)
    return Reason(key="idea.reason.fits_basic")
