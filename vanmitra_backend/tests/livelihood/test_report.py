import json
from typing import Any

import pytest

from app.errors import ApiError
from app.livelihood.schemas import (
    Idea,
    Label,
    ProfileIn,
    ReportOut,
    ResourceRecord,
    VillageGeo,
    WildlifeRisk,
)
from app.livelihood.seed import load_sample_weather
from app.livelihood.service import DatasetMeta, build_report

from .conftest import PLOT


def _build(
    profile: ProfileIn | None,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
    **kw: Any,
) -> ReportOut:
    return build_report(
        profile=profile,
        user_name="Demo",
        village=village,
        resources=records,
        ideas=ideas,
        dataset=dataset,
        weather=load_sample_weather(),
        **kw,
    )


def _keys(node: Any) -> set[str]:
    if isinstance(node, dict):
        return set(node) | {k for v in node.values() for k in _keys(v)}
    if isinstance(node, list):
        return {k for v in node for k in _keys(v)}
    return set()


def test_demo_report_shape(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    r = _build(demo_profile, records, village, ideas, dataset)
    assert r.header.report_level.value == "plot"
    assert r.header.radius_m == 5000
    assert r.is_sample_data is True
    assert r.footer_key == "footer.suggestion_only"
    # 12 sample features: 1 wildlife (feeds the wildlife check only), 1 beyond 5 km => 10 listed
    assert r.counts.total == len(r.resources) == 10
    assert r.counts.useful + r.counts.partly_useful + r.counts.not_useful == r.counts.total
    distances = [x.distance_m for x in r.resources]
    assert distances == sorted(distances)
    assert max(distances) <= 5000


def test_no_numeric_scores_anywhere_in_the_report(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    """Rule L5: labels, never scores."""
    r = _build(demo_profile, records, village, ideas, dataset)
    payload = json.loads(r.model_dump_json())
    banned = {"u", "f", "score", "fit_score", "_u", "percent", "percentage", "rating"}
    assert not (_keys(payload) & banned)


def test_every_resource_has_a_trust_label_and_reason(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    """Rule L1: nothing appears without its label."""
    r = _build(demo_profile, records, village, ideas, dataset)
    for res in r.resources:
        assert res.trust.source and res.trust.source_date and res.trust.check_status
        assert res.reason.key.startswith("reason.")


def test_community_forest_is_gram_sabha_only(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    r = _build(demo_profile, records, village, ideas, dataset)
    cfr = [x for x in r.resources if x.tag.value == "inside_cfr"]
    assert cfr and all(x.use_only_through_gram_sabha for x in cfr)
    assert not any(
        x.use_only_through_gram_sabha for x in r.resources if x.tag.value != "inside_cfr"
    )


def test_top_five_and_build_on_your_work_first(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    r = _build(demo_profile, records, village, ideas, dataset)
    assert len(r.ideas) == 5
    assert [i.rank for i in r.ideas] == [1, 2, 3, 4, 5]
    codes = [i.code for i in r.ideas]
    assert "dairy_small" in codes[:3] and "goat_rearing" in codes[:3]  # animals + past work
    groups = [i.group.value for i in r.ideas]
    assert set(groups) <= {"build_on_your_work", "other_options"}
    # once an "other option" appears, no "build on your work" idea may follow it
    if "other_options" in groups:
        assert "build_on_your_work" not in groups[groups.index("other_options") :]


def test_no_details_gives_one_ranked_list_and_a_prompt(
    records: list[ResourceRecord], village: VillageGeo, ideas: list[Idea], dataset: DatasetMeta
) -> None:
    r = _build(None, records, village, ideas, dataset)
    assert r.header.report_level.value == "village"
    assert {i.group.value for i in r.ideas} == {"ranked"}
    assert "profile_incomplete" in r.analysis.notes
    assert any(s.key == "analysis.add_details" for s in r.analysis.next_steps)


def test_gates_remove_illegal_ideas_and_trapping_is_never_listed(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    r = _build(demo_profile, records, village, ideas, dataset)
    shown = {i.code for i in r.ideas}
    assert not shown & {"lease_land_commercial", "timber_sale", "wildlife_trapping"}
    gated = {x.code: x.gate for x in r.removed if x.gate is not None}
    assert gated["lease_land_commercial"].value == "LAND_SALE_OR_LEASE"
    assert gated["timber_sale"].value == "TIMBER_OR_HARM"
    assert "wildlife_trapping" not in {x.code for x in r.removed}


def test_told_by_you_lists_animals_and_assets(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    r = _build(demo_profile, records, village, ideas, dataset)
    told = {(t.kind, t.code): t.count for t in r.told_by_you}
    assert told[("animal", "cow")] == 2 and told[("animal", "goat_sheep")] == 5
    assert ("asset", "pump") in told
    assert all(t.tag == "told_by_you" for t in r.told_by_you)


def test_tiny_land_flags_farm_ideas(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    small = demo_profile.model_copy(
        update={
            "land": demo_profile.land.model_copy(  # type: ignore[union-attr]
                update={"area_value": 0.05, "area_unit": "hectare"}
            )
        }
    )
    r = _build(small, records, village, ideas, dataset, radius_m=5000)
    needs_land = {i.code: i.min_land_ha for i in ideas if i.min_land_ha and i.min_land_ha > 0.05}
    shown = [i for i in r.ideas if i.code in needs_land]
    assert shown, "expected at least one land-hungry idea in the top five"
    for card in shown:
        assert any(f.key == "flag.needs_more_land" for f in card.flags), card.code


def test_protected_area_close_by_flags_every_idea(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    # the sample wildlife compartment is ~2.6 km north-north-east; stand 1 km nearer to it
    moved = demo_profile.model_copy(
        update={
            "location": demo_profile.location.model_copy(  # type: ignore[union-attr]
                update={"lat": PLOT["lat"] + 0.0090, "lng": PLOT["lng"] + 0.0016}
            )
        }
    )
    r = _build(moved, records, village, ideas, dataset)
    assert any(c.key == "analysis.near_protected_area" for c in r.analysis.constraints)
    assert all(any(f.key == "flag.ask_forest_dept" for f in i.flags) for i in r.ideas)
    # a forest idea becomes "needs permission" there
    for i in r.ideas:
        if i.code in {"mfp_collection_group", "forest_watch_work"}:
            assert i.wildlife_risk is WildlifeRisk.NEEDS_PERMISSION


def test_default_demo_is_not_near_a_protected_area(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    r = _build(demo_profile, records, village, ideas, dataset)
    assert not any(c.key == "analysis.near_protected_area" for c in r.analysis.constraints)


def test_empty_area_gives_honest_empty_state(
    records: list[ResourceRecord], village: VillageGeo, ideas: list[Idea], dataset: DatasetMeta
) -> None:
    far = ProfileIn.model_validate({"location": {"lat": 21.0, "lng": 79.0, "source": "gps"}})
    r = _build(far, records, village, ideas, dataset)
    assert r.resources == [] and r.counts.total == 0
    assert "no_resources_found" in r.analysis.notes
    assert any(c.key == "analysis.no_water_nearby" for c in r.analysis.constraints)
    assert r.disasters is not None and r.disasters.none_found_notice  # L7


def test_radius_limits(
    records: list[ResourceRecord], village: VillageGeo, ideas: list[Idea], dataset: DatasetMeta
) -> None:
    with pytest.raises(ApiError) as too_big:
        _build(None, records, village, ideas, dataset, radius_m=10_001)
    assert too_big.value.message_key == "livelihood.radius_too_large"
    assert too_big.value.details == {"max_m": 10000}
    with pytest.raises(ApiError):
        _build(None, records, village, ideas, dataset, radius_m=0)
    wider = _build(None, records, village, ideas, dataset, radius_m=10_000)
    assert wider.counts.total >= _build(None, records, village, ideas, dataset).counts.total


def test_location_outside_maharashtra_is_a_clean_error(
    records: list[ResourceRecord], village: VillageGeo, ideas: list[Idea], dataset: DatasetMeta
) -> None:
    delhi = ProfileIn.model_validate({"location": {"lat": 28.6, "lng": 77.2, "source": "gps"}})
    with pytest.raises(ApiError) as exc:
        _build(delhi, records, village, ideas, dataset)
    assert exc.value.message_key == "livelihood.location_outside_maharashtra"


def test_profile_rejects_unknown_codes_and_extra_fields() -> None:
    with pytest.raises(ValueError):
        ProfileIn.model_validate({"assets": ["spaceship"]})
    with pytest.raises(ValueError):
        ProfileIn.model_validate({"caste": "x"})  # we never ask (rule L8)
    with pytest.raises(ValueError):
        ProfileIn.model_validate({"income": 100000})
    for nested in (
        {"land": {"income": 1}},
        {"livestock": {"caste": "x"}},
        {"location": {"lat": 19.7, "lng": 73.2, "caste": "x"}},
    ):
        with pytest.raises(ValueError):
            ProfileIn.model_validate(nested)


def test_own_well_means_no_false_no_water_constraint(
    records: list[ResourceRecord], village: VillageGeo, ideas: list[Idea], dataset: DatasetMeta
) -> None:
    far = ProfileIn.model_validate(
        {"location": {"lat": 21.0, "lng": 79.0, "source": "gps"}, "assets": ["well"]}
    )
    r = _build(far, records, village, ideas, dataset)
    assert not any(c.key == "analysis.no_water_nearby" for c in r.analysis.constraints)
    assert any(s.key == "analysis.own_water_source" for s in r.analysis.strengths)


def test_draft_ideas_are_marked_draft(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    r = _build(demo_profile, records, village, ideas, dataset)
    assert all(i.draft for i in r.ideas)  # none is expert-reviewed yet


def test_resources_label_mix_covers_all_three_labels(
    demo_profile: ProfileIn,
    records: list[ResourceRecord],
    village: VillageGeo,
    ideas: list[Idea],
    dataset: DatasetMeta,
) -> None:
    r = _build(demo_profile, records, village, ideas, dataset)
    assert {x.label for x in r.resources} == {Label.USEFUL, Label.PARTLY_USEFUL, Label.NOT_USEFUL}
