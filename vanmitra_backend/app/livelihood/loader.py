"""
Validate a resource dataset before it is loaded (docs/DATA_PLAN.md §3). PURE: it reads a parsed
GeoJSON dict and returns what is good and what is rejected, with the reason. It never touches a
database, so anyone (including Claude) may run it on a file; the loading script that writes is
run by a person.

Why this is strict: a resource with a wrong kind, a flipped coordinate or a silly attribute type
does not crash the report, it quietly gives wrong advice ("Not yet checked" instead of "dry").
Better to refuse it at the door and say why.
"""

from dataclasses import dataclass, field
from typing import Any

from pydantic import ValidationError
from pyproj import Geod
from shapely.geometry import shape

from .geo import MH_BBOX
from .schemas import ResourceKind, ResourceRecord

HEADER_KEYS = ("dataset", "data_version", "is_sample", "source", "source_date")
GEOMETRY_TYPES = {"Point", "LineString", "Polygon"}
CONFIDENCE = {"high", "medium", "low"}
CHECK_STATUS = {"to_verify", "confirmed"}
TAG_HINTS = {"cfr", "village", "none"}
CONDITIONS = {"good", "fair", "poor"}
BOOL_ATTRS = ("perennial", "silted", "working", "dry", "road_access")
MAX_POLYGON_HA = 50_000
DUPLICATE_WITHIN_M = 5.0
# A grid cell of 0.0002 degrees (about 22 m) is wider than the duplicate distance, so a
# near-duplicate is always in the same cell or one of its 8 neighbours.
_CELL_DEG = 0.0002

_GEOD = Geod(ellps="WGS84")


@dataclass
class Rejected:
    index: int
    feature_id: str
    reason: str


@dataclass
class LoadReport:
    header: dict[str, Any] = field(default_factory=dict)
    records: list[ResourceRecord] = field(default_factory=list)
    rejected: list[Rejected] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    header_errors: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        """Safe to load: the header is complete and at least one feature survived."""
        return not self.header_errors and bool(self.records)

    def counts_by_kind(self) -> dict[str, int]:
        counts: dict[str, int] = {}
        for r in self.records:
            counts[r.kind.value] = counts.get(r.kind.value, 0) + 1
        return dict(sorted(counts.items()))


def _in_maharashtra(lng: float, lat: float) -> bool:
    lat_min, lng_min, lat_max, lng_max = MH_BBOX
    return lat_min <= lat <= lat_max and lng_min <= lng <= lng_max


def _vertices(geometry: dict[str, Any]) -> list[tuple[float, float]]:
    coords = geometry["coordinates"]
    kind = geometry["type"]
    if kind == "Point":
        return [(coords[0], coords[1])]
    if kind == "LineString":
        return [(c[0], c[1]) for c in coords]
    return [(c[0], c[1]) for ring in coords for c in ring]


def _check_attrs(attrs: dict[str, Any]) -> str | None:
    months = attrs.get("months_available")
    if months is not None and (
        isinstance(months, bool) or not isinstance(months, int | float) or not 0 <= months <= 12
    ):
        return "attrs.months_available must be a number from 0 to 12"
    condition = attrs.get("condition")
    if condition is not None and condition not in CONDITIONS:
        return "attrs.condition must be good, fair or poor"
    for name in BOOL_ATTRS:
        if name in attrs and not isinstance(attrs[name], bool):
            return f"attrs.{name} must be true or false"
    return None


def _validate_feature(
    feature: dict[str, Any], defaults: dict[str, Any], warnings: list[str]
) -> ResourceRecord | str:
    """A record, or the reason this feature is refused."""
    if not isinstance(feature, dict):
        return "a feature must be a JSON object"
    props = feature.get("properties")
    geometry = feature.get("geometry")
    if not isinstance(props, dict) or not isinstance(geometry, dict):
        return "feature needs `properties` and `geometry`"
    if not props.get("id"):
        return "properties.id is required"
    if props.get("kind") not in {k.value for k in ResourceKind}:
        return f"unknown kind: {props.get('kind')!r}"
    if geometry.get("type") not in GEOMETRY_TYPES:
        return f"geometry type must be one of {sorted(GEOMETRY_TYPES)}"
    if props.get("confidence", "low") not in CONFIDENCE:
        return "confidence must be high, medium or low"
    if props.get("check_status", "to_verify") not in CHECK_STATUS:
        return "check_status must be to_verify or confirmed"
    if props.get("tag_hint", "none") not in TAG_HINTS:
        return "tag_hint must be cfr, village or none"
    attrs = props.get("attrs")
    if attrs is not None and not isinstance(attrs, dict):
        return "attrs must be an object"
    bad_attr = _check_attrs(attrs or {})
    if bad_attr:
        return bad_attr

    try:
        geom = shape(geometry)
    except Exception:
        return "geometry could not be read"
    if geom.is_empty or not geom.is_valid:
        return "geometry is empty or not valid (for example a self-crossing polygon)"
    for lng, lat in _vertices(geometry):
        if not _in_maharashtra(lng, lat):
            return (
                f"coordinate ({lng}, {lat}) is outside Maharashtra; "
                "GeoJSON order is [longitude, latitude]: check they are not swapped"
            )
    if geometry["type"] == "Polygon":
        area_ha = abs(_GEOD.geometry_area_perimeter(geom)[0]) / 10_000
        if area_ha > MAX_POLYGON_HA:
            warnings.append(f"{props['id']}: polygon is {area_ha:,.0f} ha, please check")

    try:
        return ResourceRecord.model_validate({**defaults, **props, "geometry": geometry})
    except ValidationError as exc:
        first = exc.errors()[0]
        return f"{'.'.join(str(p) for p in first['loc'])}: {first['msg']}"


def validate_dataset(raw: dict[str, Any]) -> LoadReport:
    report = LoadReport()
    if raw.get("type") != "FeatureCollection" or not isinstance(raw.get("features"), list):
        report.header_errors.append("file must be a GeoJSON FeatureCollection with `features`")
        return report
    report.header = {k: v for k, v in raw.items() if k != "features"}
    for key in HEADER_KEYS:
        if key not in raw or raw[key] in (None, ""):
            report.header_errors.append(f"header is missing `{key}`")
    if "is_sample" in raw and not isinstance(raw["is_sample"], bool):
        report.header_errors.append("`is_sample` must be true or false")
    if report.header_errors:
        return report

    defaults = {
        "dataset": raw["dataset"],
        "is_sample": raw["is_sample"],
        "source": raw["source"],
        "source_date": raw["source_date"],
    }
    seen_ids: set[str] = set()
    # centroids bucketed by (kind, grid cell), so finding near-duplicates stays close to linear
    # for a district-sized file instead of comparing every pair
    cells: dict[tuple[str, int, int], list[tuple[str, float, float]]] = {}
    for index, feature in enumerate(raw["features"]):
        props = feature.get("properties") if isinstance(feature, dict) else None
        fid = str(props.get("id", "")) if isinstance(props, dict) else ""
        result = _validate_feature(feature, defaults, report.warnings)
        if isinstance(result, str):
            report.rejected.append(Rejected(index, fid, result))
            continue
        if result.id in seen_ids:
            report.rejected.append(Rejected(index, fid, "duplicate id in this file"))
            continue
        seen_ids.add(result.id)
        c = shape(result.geometry).centroid
        cx, cy = int(c.x / _CELL_DEG), int(c.y / _CELL_DEG)
        kind = result.kind.value
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for other_id, olng, olat in cells.get((kind, cx + dx, cy + dy), []):
                    if _GEOD.inv(olng, olat, c.x, c.y)[2] < DUPLICATE_WITHIN_M:
                        report.warnings.append(
                            f"{result.id} and {other_id}: same kind within "
                            f"{DUPLICATE_WITHIN_M:.0f} m"
                        )
        cells.setdefault((kind, cx, cy), []).append((result.id, c.x, c.y))
        report.records.append(result)
    return report
