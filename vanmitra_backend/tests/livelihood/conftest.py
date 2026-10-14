import pytest

from app.livelihood.schemas import Idea, ProfileIn, ResourceRecord, VillageGeo
from app.livelihood.seed import load_demo_village, load_ideas, load_sample_dataset
from app.livelihood.service import DatasetMeta

PLOT = {"lat": 19.7805, "lng": 73.2210}  # the demo plot the sample dataset is built around


@pytest.fixture(scope="session")
def records() -> list[ResourceRecord]:
    return load_sample_dataset()[1]


@pytest.fixture(scope="session")
def dataset() -> DatasetMeta:
    h = load_sample_dataset()[0]
    return DatasetMeta(
        h["dataset"], h["data_version"], h["is_sample"], h["source"], h["source_date"]
    )


@pytest.fixture(scope="session")
def village() -> VillageGeo:
    return load_demo_village()


@pytest.fixture(scope="session")
def ideas() -> list[Idea]:
    return load_ideas()


@pytest.fixture
def demo_profile() -> ProfileIn:
    """The walkthrough profile in docs/MVP_SPRINT.md §4: 3 acres, 2 cows, 5 goats, owns a well."""
    return ProfileIn.model_validate(
        {
            "land": {
                "area_value": 3,
                "area_unit": "acre",
                "land_type": "irrigated",
                "water_on_land": "open_well",
            },
            "location": {**PLOT, "source": "gps"},
            "livestock": {"cow": 2, "goat_sheep": 5, "poultry": 10},
            "assets": ["well", "pump", "shed"],
            "past_work": ["millets", "dairy"],
            "family_workers": 3,
            "money_level": "medium",
        }
    )
