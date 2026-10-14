"""Loaders for the bundled seed files (idea library, SAMPLE resources, demo village, weather)."""

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from ..schemas import Idea, ResourceRecord, VillageGeo, WeatherMonth, WeatherOut
from ..scheme_schemas import SchemeRecord

_DIR = Path(__file__).parent


def _read(name: str) -> dict[str, Any]:
    data: dict[str, Any] = json.loads((_DIR / name).read_text(encoding="utf-8"))
    return data


# The seed files are read once. Callers treat the results as read-only.


@lru_cache
def load_ideas() -> list[Idea]:
    return [Idea.model_validate(i) for i in _read("ideas.json")["ideas"]]


@lru_cache
def load_sample_dataset() -> tuple[dict[str, Any], list[ResourceRecord]]:
    """The SAMPLE resource set: returns (dataset header, records). Every record is is_sample."""
    raw = _read("sample_resources.geojson")
    header = {k: v for k, v in raw.items() if k != "features"}
    defaults = {
        "dataset": header["dataset"],
        "is_sample": bool(header["is_sample"]),
        "source": header["source"],
        "source_date": header["source_date"],
    }
    records = [
        # a feature's own properties win over the dataset header, so there is no clash
        ResourceRecord.model_validate(
            {**defaults, **feature["properties"], "geometry": feature["geometry"]}
        )
        for feature in raw["features"]
    ]
    return header, records


@lru_cache
def load_demo_village() -> VillageGeo:
    return VillageGeo.model_validate(_read("sample_village_geo.json"))


@lru_cache
def load_sample_weather() -> WeatherOut:
    raw = _read("sample_weather.json")
    return WeatherOut(
        is_sample=True,
        months=[WeatherMonth.model_validate(m) for m in raw["months"]],
    )


@lru_cache
def load_schemes() -> list[SchemeRecord]:
    """The SAMPLE scheme register (every row is_sample). A real register replaces this."""
    return [SchemeRecord.model_validate(r) for r in _read("schemes.json")["schemes"]]
