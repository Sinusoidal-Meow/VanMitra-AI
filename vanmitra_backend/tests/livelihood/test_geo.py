import pytest

from app.livelihood.geo import (
    CentrePoint,
    centre_for,
    circle_polygon,
    destination,
    distance_to_geometry_m,
    find_nearby,
    point_in_polygon,
    validate_point,
)
from app.livelihood.schemas import LocationIn, LocationSource, ResourceRecord, Tag, VillageGeo

from .conftest import PLOT

CENTRE = CentrePoint(PLOT["lat"], PLOT["lng"], LocationSource.GPS)


def test_point_distance_is_exact() -> None:
    lat, lng = destination(CENTRE.lat, CENTRE.lng, 77, 1234.0)
    geom = {"type": "Point", "coordinates": [lng, lat]}
    assert distance_to_geometry_m(CENTRE, geom) == pytest.approx(1234.0, abs=0.5)


def test_centre_inside_polygon_is_zero() -> None:
    d = 100 / 111_320
    ring = [
        [CENTRE.lng - d, CENTRE.lat - d],
        [CENTRE.lng + d, CENTRE.lat - d],
        [CENTRE.lng + d, CENTRE.lat + d],
        [CENTRE.lng - d, CENTRE.lat + d],
        [CENTRE.lng - d, CENTRE.lat - d],
    ]
    assert distance_to_geometry_m(CENTRE, {"type": "Polygon", "coordinates": [ring]}) == 0.0


def test_line_distance_is_to_nearest_point_not_a_vertex() -> None:
    # a north-south line 3 km west whose vertices are 1.5 km north and south: nearest point is 3 km
    west = destination(CENTRE.lat, CENTRE.lng, 270, 3000)
    south = destination(*west, 180, 1500)
    north = destination(*west, 0, 1500)
    line = {"type": "LineString", "coordinates": [[south[1], south[0]], [north[1], north[0]]]}
    assert distance_to_geometry_m(CENTRE, line) == pytest.approx(3000, abs=2)


def test_sample_edge_cases(records: list[ResourceRecord], village: VillageGeo) -> None:
    found = {n.record.id: n for n in find_nearby(records, CENTRE, 5000, village)}
    assert "smp_09_edge_inside" in found  # 4,999 m
    assert "smp_10_edge_outside" not in found  # 5,001 m
    assert 4998 < found["smp_09_edge_inside"].distance_m <= 5000
    # large polygon: centroid is 6.6 km away but its edge is 4.1 km away, so it must be found
    assert found["smp_08_forest_large"].distance_m == pytest.approx(4100, abs=5)


def test_results_are_nearest_first(records: list[ResourceRecord], village: VillageGeo) -> None:
    distances = [n.distance_m for n in find_nearby(records, CENTRE, 5000, village)]
    assert distances == sorted(distances)


def test_tags(records: list[ResourceRecord], village: VillageGeo) -> None:
    tags = {n.record.id: n.tag for n in find_nearby(records, CENTRE, 5000, village)}
    assert tags["smp_05_forest_cfr"] is Tag.INSIDE_CFR
    assert tags["smp_11_grazing"] is Tag.INSIDE_CFR
    assert tags["smp_01_well"] is Tag.NEAR


def test_wrong_and_sensitive_records_are_never_returned(
    records: list[ResourceRecord], village: VillageGeo
) -> None:
    wrong = records[0].model_copy(update={"status": "wrong"})
    hidden = records[1].model_copy(update={"sensitive": True})
    ids = {n.record.id for n in find_nearby([wrong, hidden], CENTRE, 5000, village)}
    assert ids == set()


def test_nothing_nearby_is_an_empty_list_not_an_error(
    records: list[ResourceRecord], village: VillageGeo
) -> None:
    far = CentrePoint(21.0, 79.0, LocationSource.GPS)
    assert find_nearby(records, far, 5000, village) == []


def test_circle_polygon_contains_the_true_circle() -> None:
    poly = circle_polygon(CENTRE, 5000)
    for bearing in range(0, 360, 7):
        lat, lng = destination(CENTRE.lat, CENTRE.lng, bearing, 5000)
        assert point_in_polygon(lat, lng, poly), bearing


def test_centre_prefers_pin_then_village(village: VillageGeo) -> None:
    pin = LocationIn(lat=19.78, lng=73.22, source=LocationSource.GPS)
    assert centre_for(pin, village).source is LocationSource.GPS
    assert centre_for(None, village).source is LocationSource.VILLAGE_CENTRE
    assert centre_for(None, village).lat == village.centroid_lat


def test_point_outside_maharashtra_is_rejected() -> None:
    validate_point(19.78, 73.22)
    with pytest.raises(ValueError):
        validate_point(28.6, 77.2)  # Delhi
