"""
Distance maths for "resources within N km of the land".

Why not trust a database distance: MongoDB's distance for polygons is not guaranteed to be the
distance to the polygon EDGE. So the database only finds CANDIDATES (a circle polygon passed to
$geoIntersects, see `circle_polygon`), and the exact distance is computed here, in a local
azimuthal-equidistant projection centred on the plot. That is accurate anywhere in Maharashtra and
avoids choosing a UTM zone (the west is zone 43, Vidarbha is zone 44).
"""

import math
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

import numpy as np
import shapely
from pyproj import Geod, Transformer
from shapely.geometry import Point, shape

from .schemas import (
    LocationIn,
    LocationSource,
    ResourceKind,
    ResourceRecord,
    Tag,
    VillageGeo,
)

# Rough bounding box of Maharashtra (lat_min, lng_min, lat_max, lng_max): a sanity check only.
MH_BBOX = (15.5, 72.5, 22.1, 80.95)

_GEOD = Geod(ellps="WGS84")


@dataclass(frozen=True)
class CentrePoint:
    lat: float
    lng: float
    source: LocationSource


@dataclass(frozen=True)
class Nearby:
    record: ResourceRecord
    distance_m: float
    tag: Tag


def validate_point(lat: float, lng: float) -> None:
    lat_min, lng_min, lat_max, lng_max = MH_BBOX
    if not (lat_min <= lat <= lat_max and lng_min <= lng <= lng_max):
        raise ValueError("point is outside Maharashtra")


def centre_for(location: LocationIn | None, village: VillageGeo) -> CentrePoint:
    """His pinned plot if he gave one, else the village centre (a village report)."""
    if location is not None and location.source != LocationSource.VILLAGE_CENTRE:
        validate_point(location.lat, location.lng)
        return CentrePoint(location.lat, location.lng, location.source)
    return CentrePoint(village.centroid_lat, village.centroid_lng, LocationSource.VILLAGE_CENTRE)


@lru_cache(maxsize=256)
def _local(lat0: float, lng0: float) -> Transformer:
    crs = f"+proj=aeqd +lat_0={lat0} +lon_0={lng0} +datum=WGS84 +units=m +no_defs"
    return Transformer.from_crs("EPSG:4326", crs, always_xy=True)


def distance_to_geometry_m(centre: CentrePoint, geometry: dict[str, Any]) -> float:
    """Metres from the centre to the nearest point of the geometry; 0 if the centre is inside it."""
    projector = _local(centre.lat, centre.lng)

    def to_local(coords: np.ndarray) -> np.ndarray:  # (N, 2) lng/lat -> (N, 2) metres
        x, y = projector.transform(coords[:, 0], coords[:, 1])
        return np.column_stack([x, y])

    local = shapely.transform(shape(geometry), to_local)
    return float(local.distance(Point(0.0, 0.0)))


def centroid_latlng(geometry: dict[str, Any]) -> tuple[float, float]:
    c = shape(geometry).centroid
    return (c.y, c.x)


def point_in_polygon(lat: float, lng: float, polygon: dict[str, Any]) -> bool:
    return bool(shape(polygon).contains(Point(lng, lat)))


def circle_polygon(centre: CentrePoint, radius_m: float, sides: int = 64) -> dict[str, Any]:
    """
    A GeoJSON polygon that CONTAINS the true circle (the polygon is circumscribed), for the
    database's $geoIntersects candidate search. Slightly more candidates are fine because the
    exact distance filters them afterwards; fewer would silently lose resources.
    """
    outer = radius_m / math.cos(math.pi / sides)
    ring: list[list[float]] = []
    for i in range(sides):
        lng, lat, _ = _GEOD.fwd(centre.lng, centre.lat, 360.0 * i / sides, outer)
        ring.append([lng, lat])
    ring.append(ring[0])
    return {"type": "Polygon", "coordinates": [ring]}


def destination(
    lat: float, lng: float, bearing_deg: float, distance_m: float
) -> tuple[float, float]:
    """The point `distance_m` away along `bearing_deg` (used to build the sample dataset)."""
    new_lng, new_lat, _ = _GEOD.fwd(lng, lat, bearing_deg, distance_m)
    return (new_lat, new_lng)


def tag_for(record: ResourceRecord, village: VillageGeo) -> Tag:
    """inside_cfr beats inside_village beats near (resources in CFR belong to the Gram Sabha)."""
    if record.tag_hint == "cfr":
        return Tag.INSIDE_CFR
    lat, lng = centroid_latlng(record.geometry)
    if any(point_in_polygon(lat, lng, poly) for poly in village.cfr_polygons):
        return Tag.INSIDE_CFR
    if record.tag_hint == "village":
        return Tag.INSIDE_VILLAGE
    if village.boundary is not None and point_in_polygon(lat, lng, village.boundary):
        return Tag.INSIDE_VILLAGE
    return Tag.NEAR


def centre_inside_cfr(centre: CentrePoint, village: VillageGeo) -> bool:
    return any(point_in_polygon(centre.lat, centre.lng, poly) for poly in village.cfr_polygons)


def find_nearby(
    resources: Iterable[ResourceRecord],
    centre: CentrePoint,
    radius_m: float,
    village: VillageGeo,
    kinds: Sequence[ResourceKind] | None = None,
) -> list[Nearby]:
    """
    Every active, non-sensitive resource whose nearest point is within `radius_m` of the centre,
    nearest first. Sensitive places are never returned to the user (docs/DATA_PLAN.md §2).
    """
    found: list[Nearby] = []
    for record in resources:
        if record.status != "active" or record.sensitive:
            continue
        if kinds is not None and record.kind not in kinds:
            continue
        distance = distance_to_geometry_m(centre, record.geometry)
        if distance <= radius_m:
            found.append(Nearby(record, distance, tag_for(record, village)))
    found.sort(key=lambda n: (n.distance_m, n.record.id))
    return found
