import pytest

from app.livelihood.domain.config import LivelihoodConfig
from app.livelihood.domain.labels import label_for, label_resource, reach
from app.livelihood.schemas import Label, ResourceKind


def test_weights_must_add_up() -> None:
    with pytest.raises(ValueError):
        LivelihoodConfig(w_a=0.5)
    with pytest.raises(ValueError):
        LivelihoodConfig(w_m=0.5)


def test_perennial_good_well_close_by_is_useful() -> None:
    res = label_resource(
        ResourceKind.WELL,
        {"perennial": True, "months_available": 12, "condition": "good"},
        420,
    )
    assert res.label is Label.USEFUL
    assert res.reason.key == "reason.good_all_round"
    assert res.unknown_checks == []


def test_dry_pond_is_not_useful() -> None:
    res = label_resource(
        ResourceKind.WATER_BODY,
        {"dry": True, "months_available": 2, "condition": "poor"},
        1200,
    )
    assert res.label is Label.NOT_USEFUL
    assert res.reason.key == "reason.water_dry"


def test_pdf_example_check_dam_silted_four_months() -> None:
    res = label_resource(
        ResourceKind.WATER_STRUCTURE,
        {"perennial": False, "months_available": 4, "silted": True},
        2000,
    )
    assert res.label is Label.PARTLY_USEFUL
    assert res.reason.key == "reason.silted"


def test_missing_data_is_neutral_and_reported() -> None:
    res = label_resource(ResourceKind.WATER_BODY, {}, 420)
    assert res.unknown_checks == ["availability", "condition", "season"]
    assert res.u == pytest.approx(0.35 * 0.5 + 0.25 * 0.5 + 0.25 * 0.5 + 0.15 * 1.0)
    assert res.label is Label.PARTLY_USEFUL
    assert res.reason.key == "reason.not_checked"


def test_useful_with_unknown_check_does_not_claim_good_all_round() -> None:
    res = label_resource(ResourceKind.RIVER, {"perennial": True, "months_available": 12}, 3000)
    assert res.label is Label.USEFUL
    assert res.unknown_checks == ["condition"]
    assert res.reason.key == "reason.good_on_what_is_known"


def test_forest_has_no_availability_from_map_data() -> None:
    res = label_resource(ResourceKind.FOREST_COMPARTMENT, {}, 1000)
    assert "availability" in res.unknown_checks


@pytest.mark.parametrize(
    ("u", "expected"),
    [
        (0.70, Label.USEFUL),
        (0.699, Label.PARTLY_USEFUL),
        (0.40, Label.PARTLY_USEFUL),
        (0.399, Label.NOT_USEFUL),
        (0.0, Label.NOT_USEFUL),
        (1.0, Label.USEFUL),
    ],
)
def test_band_edges(u: float, expected: Label) -> None:
    assert label_for(u) is expected


def test_reach_bands_and_no_road() -> None:
    assert reach(900, {}) == 1.0
    assert reach(1000, {}) == 1.0
    assert reach(2500, {}) == 0.7
    assert reach(4999, {}) == 0.4
    assert reach(9000, {}) == 0.2
    assert reach(900, {"road_access": False}) == pytest.approx(0.8)


def test_u_always_in_unit_range() -> None:
    """Every combination of the inputs gives a score in [0, 1] (a plain grid, no extra library)."""
    distances = [0, 1, 999, 1000, 2500, 4999, 5000, 9000, 20000]
    for d in distances:
        for months in range(0, 13):
            for perennial in (True, False, None):
                for condition in ("good", "fair", "poor", None):
                    attrs: dict[str, object] = {"months_available": months}
                    if perennial is not None:
                        attrs["perennial"] = perennial
                    if condition is not None:
                        attrs["condition"] = condition
                    res = label_resource(ResourceKind.WELL, attrs, d)
                    assert 0.0 <= res.u <= 1.0, (d, attrs)
