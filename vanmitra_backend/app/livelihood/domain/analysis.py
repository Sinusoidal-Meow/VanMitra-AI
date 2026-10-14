"""
"Where you are heading": a short summary built BY CODE from the facts of the report. No free-form
AI text in M0. Every statement is a key plus params, rendered by the app in his language, and
points at a part of the report (the same "From: ..." idea the Ask box will use in Phase 4).
"""

from collections.abc import Sequence

from ..schemas import (
    WATER_KINDS,
    Analysis,
    Label,
    ProfileIn,
    Reason,
    ReportLevel,
    ResourceKind,
    Tag,
)
from .fit import IdeaEval, LabelledResource


def _nearest(resources: Sequence[LabelledResource], kinds: frozenset[ResourceKind]) -> int | None:
    ds = [r.near.distance_m for r in resources if r.near.record.kind in kinds]
    return round(min(ds)) if ds else None


def _own_water(profile: ProfileIn) -> bool:
    """He says he has a well, borewell or pond of his own (told by him, not verified)."""
    water = profile.land.water_on_land if profile.land else None
    return bool({"well", "borewell", "farm_pond"} & set(profile.assets)) or (
        water is not None and water.value in ("open_well", "borewell")
    )


def build_analysis(
    *,
    profile: ProfileIn | None,
    resources: Sequence[LabelledResource],
    ranked: Sequence[IdeaEval],
    protected_near: bool,
    protected_nearest_m: int | None = None,
    flood_risk: bool,
    report_level: ReportLevel,
    is_sample: bool,
    radius_m: int,
) -> Analysis:
    strengths: list[Reason] = []
    constraints: list[Reason] = []
    own: list[Reason] = []
    steps: list[Reason] = []
    notes: list[str] = []

    water = [r for r in resources if r.near.record.kind in WATER_KINDS]
    useful_water = [r for r in water if r.label.label is not Label.NOT_USEFUL]
    grazing = [r for r in resources if r.near.record.kind is ResourceKind.GRAZING_LAND]
    forest = [r for r in resources if r.near.record.kind is ResourceKind.FOREST_COMPARTMENT]

    if useful_water:
        strengths.append(
            Reason(
                key="analysis.water_nearby",
                params={
                    "count": len(useful_water),
                    "nearest_m": _nearest(useful_water, WATER_KINDS),
                    "radius_m": radius_m,
                },
            )
        )
    elif profile is not None and _own_water(profile):
        strengths.append(Reason(key="analysis.own_water_source"))
    else:
        constraints.append(Reason(key="analysis.no_water_nearby", params={"radius_m": radius_m}))

    if grazing:
        strengths.append(
            Reason(
                key="analysis.grazing_nearby",
                params={"nearest_m": _nearest(grazing, frozenset({ResourceKind.GRAZING_LAND}))},
            )
        )
    if forest:
        shared = any(r.near.tag is Tag.INSIDE_CFR for r in forest)
        strengths.append(
            Reason(
                key="analysis.forest_nearby",
                params={"count": len(forest), "gram_sabha_only": shared},
            )
        )

    seasonal = [
        r for r in water if r.label.reason.key in ("reason.low_water_months", "reason.water_dry")
    ]
    if useful_water and seasonal and len(seasonal) == len(useful_water):
        constraints.append(Reason(key="analysis.water_is_seasonal"))
    if flood_risk:
        constraints.append(Reason(key="analysis.possible_flood_risk"))
    if protected_near:
        constraints.append(
            Reason(key="analysis.near_protected_area", params={"nearest_m": protected_nearest_m})
        )
        steps.append(Reason(key="analysis.ask_forest_dept"))

    # his own details
    if profile is not None:
        counts = profile.animal_counts
        if counts:
            own.append(Reason(key="analysis.you_have_animals", params=dict(counts)))
            if not grazing and "fodder_land" not in profile.assets:
                constraints.append(
                    Reason(key="analysis.no_fodder_nearby", params={"radius_m": radius_m})
                )
        if profile.assets:
            own.append(
                Reason(key="analysis.you_have_assets", params={"assets": list(profile.assets)})
            )
        if profile.area_ha:
            own.append(
                Reason(key="analysis.your_land", params={"area_ha": round(profile.area_ha, 2)})
            )

    # headline: the top idea family, else a generic line
    if ranked:
        top = ranked[0].idea
        headline = Reason(
            key=f"analysis.headline.{top.family}",
            params={"idea": top.code},
        )
    else:
        headline = Reason(key="analysis.headline.generic")

    steps.append(Reason(key="analysis.verify_with_frc"))
    if profile is None or not profile.has_details:
        steps.append(Reason(key="analysis.add_details"))
        notes.append("profile_incomplete")
    if profile is None or profile.area_ha is None:
        notes.append("land_area_missing")
    if report_level is ReportLevel.VILLAGE:
        notes.append("from_village_centre")
    notes.append("market_not_checked")
    if is_sample:
        notes.append("dataset_is_sample")
    if not resources:
        notes.append("no_resources_found")
    if len(ranked) < 5:
        notes.append("fewer_than_five")

    return Analysis(
        headline=headline,
        strengths=strengths,
        constraints=constraints,
        own_resources=own,
        next_steps=steps,
        notes=notes,
    )
