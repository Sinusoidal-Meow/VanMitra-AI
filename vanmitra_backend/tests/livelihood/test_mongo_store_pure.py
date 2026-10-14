"""The parts of the Mongo store that need no database: document conversion and index definitions."""

from datetime import UTC, datetime

from app.livelihood.geo import CentrePoint, circle_polygon
from app.livelihood.mongo_store import (
    INDEXES,
    candidate_query,
    current_versions,
    doc_to_profile,
    doc_to_report,
    doc_to_resource,
    profile_to_doc,
    report_to_doc,
    resource_to_doc,
)
from app.livelihood.schemas import LocationSource, ProfileIn
from app.livelihood.seed import load_sample_dataset
from app.livelihood.store import InMemoryStore, StoredProfile


def _stored() -> StoredProfile:
    return StoredProfile(
        user_id="u1",
        village_id="sample_ozhar",
        profile=ProfileIn.model_validate(
            {
                "land": {"area_value": 40, "area_unit": "guntha", "land_type": "rain_fed"},
                "location": {"lat": 19.78, "lng": 73.22, "source": "gps"},
                "livestock": {"cow": 2},
                "assets": ["pump", "well"],
                "past_work": ["dairy"],
                "money_level": "low",
            }
        ),
        created_at=datetime(2026, 10, 14, 12, 0, tzinfo=UTC),
        updated_at=datetime(2026, 10, 14, 13, 0, tzinfo=UTC),
    )


def test_document_round_trip_is_lossless() -> None:
    stored = _stored()
    assert doc_to_profile(profile_to_doc(stored)) == stored


def test_document_holds_only_plain_json_types() -> None:
    doc = profile_to_doc(_stored())
    # enums are stored as their text, so the database never holds Python-specific values
    assert doc["profile"]["land"]["area_unit"] == "guntha"
    assert doc["profile"]["money_level"] == "low"
    assert set(doc) == {"user_id", "village_id", "profile", "created_at", "updated_at"}


def test_document_never_carries_sensitive_fields() -> None:
    """We never ask or store caste, income or ID numbers (rule L8)."""
    text = repr(profile_to_doc(_stored())).lower()
    for banned in ("caste", "income", "aadhaar", "pan"):
        assert banned not in text


def test_user_id_index_is_unique() -> None:
    names = {ix.document["name"]: ix.document for ixs in INDEXES.values() for ix in ixs}
    assert names["user_unique"].get("unique") is True
    assert names["village_unique"].get("unique") is True


def test_resource_document_round_trip_and_geo_fields() -> None:
    for record in load_sample_dataset()[1]:
        doc = resource_to_doc(record, "v1")
        assert doc["geom"] == record.geometry  # what the 2dsphere index reads
        assert doc["data_version"] == "v1"
        assert "geometry" not in doc
        assert doc_to_resource({**doc, "_id": "x"}) == record


def test_candidate_query_uses_geo_intersects_and_excludes_hidden_records() -> None:
    circle = circle_polygon(CentrePoint(19.78, 73.22, LocationSource.GPS), 5000)
    q = candidate_query(circle)
    assert q["geom"] == {"$geoIntersects": {"$geometry": circle}}
    assert q["status"] == "active" and q["sensitive"] is False


def test_only_the_newest_version_of_each_dataset_is_served() -> None:
    from datetime import UTC, datetime

    def doc(name: str, version: str, day: int) -> dict[str, object]:
        return {
            "dataset": name,
            "data_version": version,
            "is_sample": False,
            "source": "s",
            "source_date": "2026",
            "loaded_at": datetime(2026, 10, day, tzinfo=UTC),
        }

    docs = [doc("nashik", "v1", 1), doc("nashik", "v2", 5), doc("palghar", "v1", 3)]
    # a re-load of nashik replaces v1 with v2, and the other district stays visible
    assert current_versions(docs) == {"nashik": "v2", "palghar": "v1"}
    assert current_versions([]) == {}


def test_report_document_round_trip() -> None:
    from app.livelihood.schemas import ProfileIn as P
    from app.livelihood.seed import load_demo_village, load_ideas, load_sample_weather
    from app.livelihood.service import build_report

    store = InMemoryStore()
    meta = store.dataset_meta()
    assert meta is not None
    report = build_report(
        profile=P(),
        user_name="x",
        village=load_demo_village(),
        resources=list(load_sample_dataset()[1]),
        ideas=load_ideas(),
        dataset=meta,
        weather=load_sample_weather(),
    )
    doc = report_to_doc("u1", report)
    assert doc["user_id"] == "u1" and doc["generated_at"] == report.generated_at
    assert doc_to_report(doc) == report


def test_new_collections_have_the_right_indexes() -> None:
    by_name = {ix.document["name"]: ix.document for ixs in INDEXES.values() for ix in ixs}
    assert dict(by_name["geom_2dsphere"]["key"]) == {"geom": "2dsphere"}
    assert by_name["dataset_feature_unique"].get("unique") is True
    assert by_name["code_unique"].get("unique") is True
    assert "user_latest" in by_name


def test_several_datasets_never_borrow_one_anothers_source() -> None:
    from datetime import UTC, datetime

    from app.livelihood.mongo_store import combine_datasets

    def doc(
        name: str, version: str, day: int, sample: bool, source: str, date: str
    ) -> dict[str, object]:
        return {
            "dataset": name,
            "data_version": version,
            "is_sample": sample,
            "source": source,
            "source_date": date,
            "loaded_at": datetime(2026, 10, day, tzinfo=UTC),
        }

    one = combine_datasets([doc("nashik", "v1", 1, False, "MRSAC", "2018-02")])
    assert one is not None and (one.name, one.data_version, one.source) == ("nashik", "v1", "MRSAC")

    both = combine_datasets(
        [
            doc("nashik", "v1", 1, False, "MRSAC", "2018-02"),
            doc("palghar", "v1", 3, True, "Sample", "2026-10-14"),
        ]
    )
    assert both is not None
    assert both.is_sample is True  # sample if ANY is a sample
    assert both.source == "MRSAC; Sample" and both.source_date == "2026-10-14"
    assert both.data_version == "nashik:v1;palghar:v1"

    # reloading either dataset changes the combined version, so reports are flagged as outdated
    reloaded = combine_datasets(
        [
            doc("nashik", "v2", 5, False, "MRSAC", "2018-02"),
            doc("palghar", "v1", 3, True, "Sample", "2026-10-14"),
        ]
    )
    assert reloaded is not None and reloaded.data_version != both.data_version
    unknown = combine_datasets(
        [doc("a", "v1", 1, False, "A", "unknown"), doc("b", "v1", 2, False, "B", "2020")]
    )
    assert unknown is not None and unknown.source_date == "unknown"
    assert combine_datasets([]) is None


def test_a_malformed_dataset_document_is_skipped_not_a_crash() -> None:
    from datetime import UTC, datetime

    good = {
        "dataset": "n",
        "data_version": "v1",
        "is_sample": False,
        "source": "s",
        "source_date": "2020",
        "loaded_at": datetime(2026, 10, 1, tzinfo=UTC),
    }
    broken = {"dataset": "x", "data_version": "v1"}  # no loaded_at, source and so on
    assert current_versions([broken, good]) == {"n": "v1"}
    assert current_versions([broken]) == {}


def test_resource_documents_carry_no_unused_centroid() -> None:
    doc = resource_to_doc(load_sample_dataset()[1][0], "v1")
    assert "centroid" not in doc
