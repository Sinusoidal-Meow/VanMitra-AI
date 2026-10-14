import copy
import json
from pathlib import Path
from typing import Any

import pytest

from app.livelihood import seed
from app.livelihood.loader import validate_dataset

SAMPLE = Path(seed.__file__).resolve().parent / "sample_resources.geojson"  # same in any repo


@pytest.fixture
def raw() -> dict[str, Any]:
    return json.loads(SAMPLE.read_text(encoding="utf-8"))


def feature(**props: Any) -> dict[str, Any]:
    base: dict[str, Any] = {"id": "f1", "kind": "well", "attrs": {}}
    base.update(props)
    return {
        "type": "Feature",
        "geometry": {"type": "Point", "coordinates": [73.22, 19.78]},
        "properties": base,
    }


def dataset(*features: dict[str, Any], **header: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "type": "FeatureCollection",
        "dataset": "t",
        "data_version": "v1",
        "is_sample": True,
        "source": "test",
        "source_date": "2026-10-14",
        "features": list(features),
    }
    base.update(header)
    return base


def test_the_bundled_sample_dataset_is_clean(raw: dict[str, Any]) -> None:
    report = validate_dataset(raw)
    assert report.ok and not report.rejected and not report.warnings
    assert len(report.records) == 12
    assert report.counts_by_kind()["water_body"] == 4  # dry pond, unchecked tank, two edge ponds
    assert all(r.is_sample and r.dataset == "sample_demo" for r in report.records)


def test_not_a_feature_collection() -> None:
    assert not validate_dataset({"type": "Feature"}).ok
    assert not validate_dataset({"type": "FeatureCollection", "features": "x"}).ok


@pytest.mark.parametrize(
    "missing", ["dataset", "data_version", "is_sample", "source", "source_date"]
)
def test_every_header_field_is_required(raw: dict[str, Any], missing: str) -> None:
    broken = copy.deepcopy(raw)
    del broken[missing]
    report = validate_dataset(broken)
    assert not report.ok and any(missing in e for e in report.header_errors)


def test_is_sample_must_be_a_real_boolean() -> None:
    report = validate_dataset(dataset(feature(), is_sample="yes"))
    assert not report.ok and any("is_sample" in e for e in report.header_errors)


def test_an_empty_source_is_refused() -> None:
    assert not validate_dataset(dataset(feature(), source="")).ok  # rule L1: no source, no data


def test_unknown_kind_is_rejected_with_the_reason() -> None:
    report = validate_dataset(dataset(feature(kind="spaceship"), feature(id="f2")))
    assert [r.feature_id for r in report.rejected] == ["f1"]
    assert "unknown kind" in report.rejected[0].reason
    assert len(report.records) == 1 and report.ok


def test_swapped_coordinates_are_caught() -> None:
    swapped = feature()
    swapped["geometry"]["coordinates"] = [19.78, 73.22]  # [lat, lng] instead of [lng, lat]
    report = validate_dataset(dataset(swapped))
    assert "outside Maharashtra" in report.rejected[0].reason
    assert "swapped" in report.rejected[0].reason


def test_a_self_crossing_polygon_is_rejected() -> None:
    bowtie = feature(kind="forest_compartment")
    bowtie["geometry"] = {
        "type": "Polygon",
        "coordinates": [[[73.2, 19.7], [73.3, 19.8], [73.3, 19.7], [73.2, 19.8], [73.2, 19.7]]],
    }
    report = validate_dataset(dataset(bowtie))
    assert "not valid" in report.rejected[0].reason


def test_unsupported_geometry_types_are_rejected() -> None:
    multi = feature()
    multi["geometry"] = {"type": "MultiPoint", "coordinates": [[73.2, 19.7], [73.3, 19.8]]}
    assert "geometry type" in validate_dataset(dataset(multi)).rejected[0].reason


@pytest.mark.parametrize(
    ("attrs", "fragment"),
    [
        ({"months_available": 13}, "months_available"),
        ({"months_available": -1}, "months_available"),
        ({"months_available": "4"}, "months_available"),
        ({"months_available": True}, "months_available"),
        ({"condition": "excellent"}, "condition"),
        ({"perennial": "yes"}, "perennial"),
        ({"silted": 1}, "silted"),
        ({"road_access": "no"}, "road_access"),
    ],
)
def test_silly_attribute_values_are_rejected_not_silently_ignored(
    attrs: dict[str, Any], fragment: str
) -> None:
    report = validate_dataset(dataset(feature(attrs=attrs)))
    assert fragment in report.rejected[0].reason


@pytest.mark.parametrize(
    "prop", [{"confidence": "certain"}, {"check_status": "done"}, {"tag_hint": "forest"}]
)
def test_controlled_values_are_enforced(prop: dict[str, str]) -> None:
    assert validate_dataset(dataset(feature(**prop))).rejected


def test_duplicate_ids_and_near_duplicates() -> None:
    twin = feature(id="f1")
    near = feature(id="f3")
    near["geometry"]["coordinates"] = [73.220001, 19.780001]  # about 0.15 m away
    report = validate_dataset(dataset(feature(), twin, near))
    assert any("duplicate id" in r.reason for r in report.rejected)
    assert any("same kind within" in w for w in report.warnings)
    assert [r.id for r in report.records] == ["f1", "f3"]


def test_a_feature_may_override_the_dataset_source() -> None:
    report = validate_dataset(
        dataset(feature(source="Gram Panchayat survey", source_date="2025-01"))
    )
    assert report.ok and report.records[0].source == "Gram Panchayat survey"


def test_a_huge_polygon_is_a_warning_not_a_rejection() -> None:
    big = feature(kind="forest_compartment")
    big["geometry"] = {
        "type": "Polygon",
        "coordinates": [[[73.0, 18.0], [76.0, 18.0], [76.0, 21.0], [73.0, 21.0], [73.0, 18.0]]],
    }
    report = validate_dataset(dataset(big))
    assert report.ok and any("please check" in w for w in report.warnings)


def test_malformed_features_do_not_crash_the_validator() -> None:
    report = validate_dataset(dataset({"type": "Feature"}, {}, feature()))
    assert len(report.rejected) == 2 and len(report.records) == 1


def test_no_surviving_feature_means_not_ok() -> None:
    assert not validate_dataset(dataset(feature(kind="nope"))).ok


def test_non_object_features_are_rejected_not_a_crash() -> None:
    report = validate_dataset(dataset("abc", 5, None, [1, 2], feature()))
    assert len(report.rejected) == 4 and len(report.records) == 1
    assert all("JSON object" in r.reason or "properties" in r.reason for r in report.rejected)


@pytest.mark.parametrize("attrs", [["dry"], "x", 5, True])
def test_attrs_that_is_not_an_object_is_rejected_not_a_crash(attrs: Any) -> None:
    report = validate_dataset(dataset(feature(attrs=attrs)))
    assert "attrs must be an object" in report.rejected[0].reason


def test_duplicate_detection_finds_neighbours_across_grid_cells() -> None:
    a = feature(id="a")
    a["geometry"]["coordinates"] = [73.21999, 19.78]  # either side of a cell edge
    b = feature(id="b")
    b["geometry"]["coordinates"] = [73.22001, 19.78]  # about 2 m from a
    far = feature(id="c")
    far["geometry"]["coordinates"] = [73.23, 19.78]
    report = validate_dataset(dataset(a, b, far))
    assert len(report.warnings) == 1 and "a and b" in report.warnings[0].replace(
        "b and a", "a and b"
    )


def test_a_large_file_validates_quickly() -> None:
    import time

    feats = []
    for i in range(4000):
        f = feature(id=f"f{i}")
        f["geometry"]["coordinates"] = [73.0 + (i % 80) * 0.01, 19.0 + (i // 80) * 0.01]
        feats.append(f)
    start = time.perf_counter()
    report = validate_dataset(dataset(*feats))
    assert len(report.records) == 4000 and not report.warnings
    assert time.perf_counter() - start < 20  # was quadratic; this is a generous ceiling
