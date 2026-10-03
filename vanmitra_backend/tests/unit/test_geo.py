"""GeoJSON → WKT and the split of the boundary ring into segments (no database)."""

import pytest

from app.geo import (
    GeoError,
    accuracy_stats,
    line_wkt,
    point_wkt,
    polygon_wkt,
    ring,
    split_ring,
)

SQUARE = [[73.2, 19.9], [73.21, 19.9], [73.21, 19.91], [73.2, 19.91]]


def test_ring_is_closed_for_the_caller() -> None:
    r = ring(SQUARE)
    assert r[0] == r[-1] and len(r) == 5
    assert ring([*SQUARE, SQUARE[0]]) == r


@pytest.mark.parametrize(
    ("coords", "key"),
    [
        ([[73.2, 19.9], [73.21, 19.9], [73.2, 19.9]], "geo.ring_too_short"),
        ([[73.2, 19.9], [190, 19.9], [73.2, 19.91]], "geo.out_of_range"),
        ([[73.2], [73.21, 19.9], [73.2, 19.91]], "geo.bad_position"),
    ],
)
def test_bad_rings(coords: list[list[float]], key: str) -> None:
    with pytest.raises(GeoError) as e:
        ring(coords)
    assert e.value.key == key


def test_wkt() -> None:
    assert polygon_wkt([ring(SQUARE)]).startswith("POLYGON((73.2 19.9, 73.21 19.9")
    assert line_wkt([(1.0, 2.0), (3.0, 4.0)]) == "LINESTRING(1.0 2.0, 3.0 4.0)"
    assert point_wkt(73.2, 19.9) == "POINT(73.2 19.9)"
    with pytest.raises(GeoError):
        line_wkt([(1.0, 2.0)])


def test_one_break_is_the_whole_ring() -> None:
    r = ring(SQUARE)
    assert split_ring(r, [0]) == [r]


def test_four_breaks_are_the_four_sides() -> None:
    r = ring(SQUARE)
    parts = split_ring(r, [3, 0, 2, 1, 1])  # order and duplicates do not matter
    assert len(parts) == 4
    assert parts[0] == [r[0], r[1]]
    assert parts[3] == [r[3], r[0]]  # wraps round to the first break


def test_breaks_split_where_asked() -> None:
    r = ring(SQUARE)
    parts = split_ring(r, [1, 3])
    assert parts == [[r[1], r[2], r[3]], [r[3], r[0], r[1]]]


@pytest.mark.parametrize("breaks", [[], [4], [-1]])
def test_bad_breaks(breaks: list[int]) -> None:
    with pytest.raises(GeoError):
        split_ring(ring(SQUARE), breaks)


def test_accuracy_stats_flags_points_over_the_limit() -> None:
    stats = accuracy_stats([3.0, None, 22.5, 15.0], 4, 15.0)
    assert stats == {
        "points": 4, "with_accuracy": 3, "worst_m": 22.5, "over_limit": 1, "limit_m": 15.0,
    }  # fmt: skip
    assert accuracy_stats(None, 4, 15.0)["worst_m"] is None
