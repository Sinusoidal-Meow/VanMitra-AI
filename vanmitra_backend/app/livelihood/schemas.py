"""
Shapes of everything that crosses the API, plus the source-data records the rules read.

The REPORT shapes (ReportOut and its parts) are the contract the app builds against
(docs/BACKEND_PLAN.md §6). Rule L5: nothing in them carries a numeric score. Reasons travel as
{key, params}, never as finished text, so three languages stay consistent and a cached report
still renders offline.
"""

from datetime import datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .domain.units import AreaUnit, to_hectares

# ── controlled vocabularies ───────────────────────────────────────────────────


class ResourceKind(StrEnum):
    WATER_BODY = "water_body"
    WELL = "well"
    WATER_STRUCTURE = "water_structure"  # check dam, farm pond
    RIVER = "river"
    DRAINAGE_LINE = "drainage_line"
    FOREST_COMPARTMENT = "forest_compartment"
    CONSERVATION_RESERVE = "conservation_reserve"
    WILDLIFE_COMPARTMENT = "wildlife_compartment"
    GRAZING_LAND = "grazing_land"  # from recognised CFR approvals whose purpose names grazing


WATER_KINDS = frozenset(
    {
        ResourceKind.WATER_BODY,
        ResourceKind.WELL,
        ResourceKind.WATER_STRUCTURE,
        ResourceKind.RIVER,
        ResourceKind.DRAINAGE_LINE,
    }
)
PROTECTED_KINDS = frozenset({ResourceKind.WILDLIFE_COMPARTMENT, ResourceKind.CONSERVATION_RESERVE})
FLOOD_KINDS = frozenset({ResourceKind.RIVER, ResourceKind.DRAINAGE_LINE})


class Tag(StrEnum):
    INSIDE_CFR = "inside_cfr"
    INSIDE_VILLAGE = "inside_village"
    NEAR = "near"


class Label(StrEnum):
    USEFUL = "useful"
    PARTLY_USEFUL = "partly_useful"
    NOT_USEFUL = "not_useful"


class FitLabel(StrEnum):
    GOOD = "good"
    FAIR = "fair"
    WEAK = "weak"


class Level(StrEnum):
    """Cost level of an idea, and the money a landowner can invest."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class WildlifeRisk(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    NEEDS_PERMISSION = "needs_permission"


class Gate(StrEnum):
    LAND_SALE_OR_LEASE = "LAND_SALE_OR_LEASE"  # FRA Sec 4(4)
    HUNTING_OR_TRAPPING = "HUNTING_OR_TRAPPING"  # Sec 3(1)(l)
    TIMBER_OR_HARM = "TIMBER_OR_HARM"  # Sec 5
    NOT_ALLOWED_IN_CFR = "NOT_ALLOWED_IN_CFR"  # CFR rules


class LandType(StrEnum):
    IRRIGATED = "irrigated"
    RAIN_FED = "rain_fed"
    MIXED = "mixed"


class WaterOnLand(StrEnum):
    OPEN_WELL = "open_well"
    BOREWELL = "borewell"
    NONE = "none"


class LocationSource(StrEnum):
    GPS = "gps"
    MANUAL = "manual"
    VILLAGE_CENTRE = "village_centre"


class ReportLevel(StrEnum):
    PLOT = "plot"
    VILLAGE = "village"


class IdeaGroup(StrEnum):
    RANKED = "ranked"  # no details given: one list
    BUILD_ON_YOUR_WORK = "build_on_your_work"
    OTHER_OPTIONS = "other_options"


ASSET_CODES = (
    "well",
    "borewell",
    "farm_pond",
    "shed",
    "pump",
    "drip_kit",
    "bullock_cart",
    "storage_room",
    "vehicle",
    "fodder_land",
    "other",
)
ANIMAL_CODES = ("cow", "buffalo", "bullock", "goat_sheep", "poultry", "other")
PAST_WORK_CODES = (
    "paddy",
    "millets",
    "pulses",
    "vegetables",
    "fruit",
    "dairy",
    "goat_rearing",
    "poultry",
    "forest_produce",
    "labour",
    "other",
)

# ── the landowner's own details (all optional; always shown as "Told by you") ─


class Reason(BaseModel):
    key: str
    params: dict[str, Any] = Field(default_factory=dict)


class LandIn(BaseModel):
    model_config = ConfigDict(extra="forbid")  # we never ask caste, income or IDs (rule L8)

    area_value: float | None = Field(default=None, gt=0)
    area_unit: AreaUnit = AreaUnit.HECTARE
    land_type: LandType | None = None
    water_on_land: WaterOnLand | None = None


class LocationIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    accuracy_m: float | None = Field(default=None, ge=0)
    source: LocationSource = LocationSource.GPS


class LivestockIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cow: int = Field(default=0, ge=0, le=999)
    buffalo: int = Field(default=0, ge=0, le=999)
    bullock: int = Field(default=0, ge=0, le=999)
    goat_sheep: int = Field(default=0, ge=0, le=999)
    poultry: int = Field(default=0, ge=0, le=999)
    other: int = Field(default=0, ge=0, le=999)

    def counts(self) -> dict[str, int]:
        return {code: getattr(self, code) for code in ANIMAL_CODES if getattr(self, code) > 0}


class ProfileIn(BaseModel):
    """What the landowner tells us. We ask no caste, income or ID number (rule L8)."""

    model_config = ConfigDict(extra="forbid")

    land: LandIn | None = None
    location: LocationIn | None = None
    livestock: LivestockIn | None = None
    assets: list[str] = Field(default_factory=list)
    past_work: list[str] = Field(default_factory=list)
    family_workers: int | None = Field(default=None, ge=0, le=15)
    money_level: Level | None = None

    @field_validator("assets")
    @classmethod
    def _assets_known(cls, value: list[str]) -> list[str]:
        bad = sorted(set(value) - set(ASSET_CODES))
        if bad:
            raise ValueError(f"unknown asset codes: {bad}")
        return sorted(set(value))

    @field_validator("past_work")
    @classmethod
    def _past_work_known(cls, value: list[str]) -> list[str]:
        bad = sorted(set(value) - set(PAST_WORK_CODES))
        if bad:
            raise ValueError(f"unknown past-work codes: {bad}")
        return sorted(set(value))

    @property
    def area_ha(self) -> float | None:
        if self.land is None or self.land.area_value is None:
            return None
        return to_hectares(self.land.area_value, self.land.area_unit)

    @property
    def animal_counts(self) -> dict[str, int]:
        return self.livestock.counts() if self.livestock else {}

    @property
    def has_details(self) -> bool:
        return bool(
            self.area_ha
            or self.animal_counts
            or self.assets
            or self.past_work
            or self.money_level
            or self.family_workers
        )


class NearbyOut(BaseModel):
    """Answer to "what is near this point": labelled resources only, no ideas."""

    centre: "Centre"
    radius_m: int
    resources: list["ResourceOut"]
    counts: "Counts"
    is_sample_data: bool


class ProfileOut(BaseModel):
    """A saved profile as the app sees it. `area_ha` is the converted land area."""

    profile: "ProfileIn"
    area_ha: float | None = None
    village: "VillageRef | None" = None
    created_at: datetime
    updated_at: datetime


# ── source data the rules read ────────────────────────────────────────────────


class ResourceRecord(BaseModel):
    """One mapped resource. Every record keeps its source, date and confidence (rule L1)."""

    id: str
    kind: ResourceKind
    name_mr: str = ""
    name_en: str = ""
    geometry: dict[str, Any]  # GeoJSON Point | LineString | Polygon, WGS 84 [lng, lat]
    attrs: dict[str, Any] = Field(default_factory=dict)
    tag_hint: str = "none"  # cfr | village | none
    sensitive: bool = False
    status: str = "active"  # active | wrong
    source: str
    source_date: str = "unknown"
    confidence: str = "low"  # high | medium | low
    check_status: str = "to_verify"  # to_verify | confirmed
    dataset: str = ""
    is_sample: bool = False
    district: str = ""


class VillageGeo(BaseModel):
    """Village location. The host Village model has none, so this lives in `lv_village_geo`."""

    village_id: str
    name_mr: str
    name_en: str
    centroid_lat: float
    centroid_lng: float
    boundary: dict[str, Any] | None = None
    cfr_polygons: list[dict[str, Any]] = Field(default_factory=list)
    source: str = ""
    source_date: str = "unknown"
    is_sample: bool = False


class GateFlags(BaseModel):
    needs_sale_or_lease: bool = False
    hunting_trapping: bool = False
    timber_or_harm: bool = False
    not_in_cfr: bool = False


class PHints(BaseModel):
    past_work: list[str] = Field(default_factory=list)
    animals: list[str] = Field(default_factory=list)


class Idea(BaseModel):
    """One row of the editable idea library (docs/IDEA_LIBRARY.md). Draft until expert review."""

    code: str
    name_en: str
    name_mr: str
    family: str
    # each inner list is a group of alternatives; every group must be satisfied by ANY entry.
    # an entry is a resource kind ("well") or an own asset ("asset:pump")
    needs: list[list[str]] = Field(default_factory=list)
    gate_flags: GateFlags = Field(default_factory=GateFlags)
    cost_level: Level = Level.LOW
    best_season: str = "year_round"
    wildlife_risk: WildlifeRisk = WildlifeRisk.LOW
    min_land_ha: float | None = None  # placeholder until the agriculture expert sets it
    group_only: bool = False
    through_gram_sabha: bool = False
    touches_forest: bool = False
    tags: list[str] = Field(default_factory=list)  # water_hungry | heat_sensitive | flood_sensitive
    ease: float = 0.5  # E, 0-1, starting value
    green: float = 0.5  # G, 0-1, starting value
    p_hints: PHints = Field(default_factory=PHints)
    status: str = "draft"  # draft | reviewed
    enabled: bool = True
    show_in_removed_list: bool = True


# ── the report (the contract) ────────────────────────────────────────────────


class TrustLabel(BaseModel):
    source: str
    source_date: str
    check_status: str
    confidence: str | None = None


class ResourceOut(BaseModel):
    id: str
    kind: ResourceKind
    name_mr: str
    name_en: str
    distance_m: int
    tag: Tag
    label: Label
    reason: Reason
    checked_on_ground: bool
    unknown_checks: list[str]
    use_only_through_gram_sabha: bool
    trust: TrustLabel


class Counts(BaseModel):
    useful: int = 0
    partly_useful: int = 0
    not_useful: int = 0
    total: int = 0


class ToldByYou(BaseModel):
    kind: str  # animal | asset
    code: str
    count: int | None = None
    tag: str = "told_by_you"


class Analysis(BaseModel):
    headline: Reason
    strengths: list[Reason] = Field(default_factory=list)
    constraints: list[Reason] = Field(default_factory=list)
    own_resources: list[Reason] = Field(default_factory=list)
    next_steps: list[Reason] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)


class IdeaOut(BaseModel):
    rank: int
    code: str
    name_mr: str
    name_en: str
    group: IdeaGroup
    fit: FitLabel
    reason: Reason
    resources_used: list[str]
    cost_level: Level
    best_season: str
    wildlife_risk: WildlifeRisk
    flags: list[Reason]
    schemes_count: int = 0
    draft: bool = True  # not expert-reviewed yet (docs/IDEA_LIBRARY.md)


class RemovedOut(BaseModel):
    """An idea that is not in the top list: removed by a gate, or held back for a lower fit."""

    code: str
    name_mr: str
    name_en: str
    gate: Gate | None = None  # None = held back, not removed
    reason: Reason
    # for an idea held back (not removed): how it fared, so "why not fishing?" can be answered
    fit: FitLabel | None = None
    flags: list[Reason] = Field(default_factory=list)


class VillageRef(BaseModel):
    id: str
    name_mr: str
    name_en: str


class Centre(BaseModel):
    lat: float
    lng: float
    source: LocationSource


class Header(BaseModel):
    name: str
    village: VillageRef
    report_level: ReportLevel
    centre: Centre
    radius_m: int
    cfr_status: str | None = None  # from Module 2 later
    trust: TrustLabel


class WeatherMonth(BaseModel):
    month: int
    rain_mm: float
    tmax_c: float


class WeatherOut(BaseModel):
    is_sample: bool
    months: list[WeatherMonth]
    note_key: str = "weather.typical_not_forecast"  # "Typical, from past years. Not a forecast."


class DisastersOut(BaseModel):
    is_sample: bool
    items: list[Reason] = Field(default_factory=list)
    none_found_notice: bool = True  # "No record found... does not mean there were none" (L7)


class ReportOut(BaseModel):
    id: str
    generated_at: datetime
    data_version: str
    is_sample_data: bool
    newer_version_available: bool = False
    header: Header
    resources: list[ResourceOut]
    counts: Counts
    told_by_you: list[ToldByYou]
    analysis: Analysis
    ideas: list[IdeaOut]
    removed: list[RemovedOut]
    weather: WeatherOut | None = None
    disasters: DisastersOut | None = None
    footer_key: str = "footer.suggestion_only"
