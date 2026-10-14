"""
Tunable numbers. Every value here is a STARTING value (docs/BACKEND_PLAN.md §5): the PDF gives
the U and F weights and the label bands; the rest are marked 'proposed' and are tuned after
field tests. Later these are overridden from the `lv_config` collection.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class LivelihoodConfig:
    # search
    default_radius_m: int = 5000  # requested 5 km (PDF starts at 3 km)
    max_radius_m: int = 10000
    protected_near_m: int = 2000  # proposed: "near" a protected area
    flood_near_m: int = 300  # proposed: near a river / drainage line
    hot_month_tmax_c: float = 40.0  # proposed: a month this hot marks the area "hot"

    # missing data is neutral and shown as "Not yet checked on the ground"
    neutral: float = 0.5

    # resource label: U = a*A + c*C + s*S + r*R   (PDF §7)
    w_a: float = 0.35
    w_c: float = 0.25
    w_s: float = 0.25
    w_r: float = 0.15
    useful_min: float = 0.70
    partly_min: float = 0.40
    # proposed reach bands: (max distance m, R). Beyond the last band: reach_beyond
    reach_bands: tuple[tuple[int, float], ...] = ((1000, 1.0), (3000, 0.7), (5000, 0.4))
    reach_beyond: float = 0.2
    no_road_factor: float = 0.8

    # idea fit: F = m*M + k*K + p*P + e*E + g*G   (PDF §9)
    w_m: float = 0.35
    w_k: float = 0.20
    w_p: float = 0.15
    w_e: float = 0.15
    w_g: float = 0.15
    good_min: float = 0.70  # proposed fit-label bands
    fair_min: float = 0.40
    top_n: int = 5

    # proposed adjustments
    told_resource_u: float = 0.8  # a resource the user says he owns (unverified)
    p_past_work_bonus: float = 0.2
    p_animal_bonus: float = 0.2
    p_workers_bonus: float = 0.1  # two or more family members can work
    land_short_factor: float = 0.5  # E multiplier when own land is below the idea's minimum
    flood_factor: float = 0.7
    hot_water_factor: float = 0.85

    def __post_init__(self) -> None:
        if abs(self.w_a + self.w_c + self.w_s + self.w_r - 1.0) > 1e-9:
            raise ValueError("resource label weights must add up to 1")
        if abs(self.w_m + self.w_k + self.w_p + self.w_e + self.w_g - 1.0) > 1e-9:
            raise ValueError("idea fit weights must add up to 1")


DEFAULT_CONFIG = LivelihoodConfig()
