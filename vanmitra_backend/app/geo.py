"""
GeoJSON in, WKT out, and the split of a boundary ring into named segments. Pure Python:
validity, areas and overlaps are computed by PostGIS (services/boundary.py).
"""

from collections.abc import Sequence

Position = tuple[float, float]  # (lon, lat), GeoJSON order


class GeoError(ValueError):
    """Input that cannot be a boundary; `key` is the message key for the app."""

    def __init__(self, key: str, detail: str) -> None:
        super().__init__(detail)
        self.key = key
        self.detail = detail


def position(p: Sequence[float]) -> Position:
    if len(p) < 2:
        raise GeoError("geo.bad_position", "a position needs longitude and latitude")
    lon, lat = float(p[0]), float(p[1])
    if not (-180 <= lon <= 180 and -90 <= lat <= 90):
        raise GeoError("geo.out_of_range", f"position out of range: {lon}, {lat}")
    return lon, lat


def ring(coords: Sequence[Sequence[float]]) -> list[Position]:
    """A closed linear ring (closed for the caller if the first point is not repeated)."""
    pts = [position(p) for p in coords]
    if pts and pts[0] != pts[-1]:
        pts.append(pts[0])
    if len(set(pts)) < 3 or len(pts) < 4:
        raise GeoError("geo.ring_too_short", "a boundary needs at least three distinct points")
    return pts


def _coords(pts: Sequence[Position]) -> str:
    return ", ".join(f"{lon!r} {lat!r}" for lon, lat in pts)


def polygon_wkt(rings: Sequence[Sequence[Position]]) -> str:
    return "POLYGON(" + ", ".join(f"({_coords(r)})" for r in rings) + ")"


def line_wkt(pts: Sequence[Position]) -> str:
    if len(pts) < 2:
        raise GeoError("geo.line_too_short", "a line needs at least two points")
    return f"LINESTRING({_coords(pts)})"


def point_wkt(lon: float, lat: float) -> str:
    lon, lat = position((lon, lat))
    return f"POINT({lon!r} {lat!r})"


def split_ring(closed: Sequence[Position], breaks: Sequence[int]) -> list[list[Position]]:
    """
    Cut the outer ring into segments at the given vertex indices. Segment k runs from
    break k to break k+1 (the last one wraps round to the first break). One break gives
    one segment: the whole ring.
    """
    n = len(closed) - 1  # distinct vertices; the last point repeats the first
    cuts = sorted(set(breaks))
    if not cuts:
        raise GeoError("geo.no_segments", "at least one segment break is needed")
    if cuts[0] < 0 or cuts[-1] >= n:
        raise GeoError("geo.break_out_of_range", f"segment breaks must be within 0..{n - 1}")
    segments = []
    for k, start in enumerate(cuts):
        end = cuts[k + 1] if k + 1 < len(cuts) else cuts[0] + n
        segments.append([closed[i % n] for i in range(start, end + 1)])
    return segments


def accuracy_stats(
    values: Sequence[float | None] | None, points: int, limit_m: float
) -> dict[str, float | int | None]:
    """Summary of GPS accuracy per vertex (B-14: points worse than the limit are flagged)."""
    known = [v for v in (values or []) if v is not None]
    return {
        "points": points,
        "with_accuracy": len(known),
        "worst_m": max(known) if known else None,
        "over_limit": sum(1 for v in known if v > limit_m),
        "limit_m": limit_m,
    }
