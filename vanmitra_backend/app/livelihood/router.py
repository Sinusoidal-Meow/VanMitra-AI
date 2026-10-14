"""
Livelihood routes, mounted at /api/v1/livelihood.

Two groups:
- the real routes, which need a login and work only on the signed-in user's OWN data:
  PUT/GET/DELETE /profile, POST /report, GET /report/latest, POST /resources/nearby
  (docs/BACKEND_PLAN.md §3);
- the stateless DEMO routes: they build a report from the bundled SAMPLE dataset, store nothing
  and need no login. Switched by VANMITRA_LIVELIHOOD_DEMO_ENDPOINTS; OFF wherever real data or
  real users are involved.
"""

from dataclasses import replace
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, ConfigDict, Field
from uuid6 import uuid7

from ..config import get_settings
from ..errors import ApiError
from .deps import CurrentUser, get_store
from .domain.config import DEFAULT_CONFIG, LivelihoodConfig
from .domain.units import AreaUnit
from .geo import circle_polygon, find_nearby, validate_point
from .identity import UserInfo
from .schemas import (
    ANIMAL_CODES,
    ASSET_CODES,
    PAST_WORK_CODES,
    Centre,
    LocationIn,
    LocationSource,
    NearbyOut,
    ProfileIn,
    ProfileOut,
    ReportOut,
    ResourceKind,
    VillageGeo,
    VillageRef,
)
from .seed import (
    load_demo_village,
    load_ideas,
    load_sample_dataset,
    load_sample_weather,
)
from .service import (
    DatasetMeta,
    build_report,
    count_labels,
    label_nearby,
    resolve_search,
    resource_card,
    search_radius,
)
from .store import LivelihoodStore, StoredProfile

router = APIRouter(prefix="/livelihood", tags=["livelihood"])

DEMO_PLOT = {
    "lat": 19.7805,
    "lng": 73.2210,
}  # inside the sample dataset's 5 km (see seed generator)


class DemoReportRequest(BaseModel):
    profile: ProfileIn | None = None
    radius_m: int | None = None
    name: str = "Demo villager"


Store = Annotated[LivelihoodStore, Depends(get_store)]


def _profile_out(stored: StoredProfile, store: LivelihoodStore) -> ProfileOut:
    village = store.get_village(stored.village_id) if stored.village_id else None
    return ProfileOut(
        profile=stored.profile,
        area_ha=stored.profile.area_ha,
        village=(
            VillageRef(id=village.village_id, name_mr=village.name_mr, name_en=village.name_en)
            if village
            else None
        ),
        created_at=stored.created_at,
        updated_at=stored.updated_at,
    )


@router.get("/profile", response_model=ProfileOut)
def get_profile(user: CurrentUser, store: Store) -> ProfileOut:
    """His saved details. Only ever his own: the user comes from the login, never the URL."""
    stored = store.get_profile(str(user.id))
    if stored is None:
        raise ApiError(404, "NO_PROFILE", "livelihood.no_profile")
    return _profile_out(stored, store)


@router.put("/profile", response_model=ProfileOut)
def put_profile(body: ProfileIn, user: CurrentUser, store: Store) -> ProfileOut:
    """
    Save his details, REPLACING any earlier answers. His village comes from his login (his role),
    not from the request, so he cannot file under another village.
    """
    loc = body.location
    if loc is not None and loc.source is not LocationSource.VILLAGE_CENTRE:
        try:
            validate_point(loc.lat, loc.lng)
        except ValueError as exc:
            raise ApiError(
                422, "LOCATION_OUTSIDE_MAHARASHTRA", "livelihood.location_outside_maharashtra"
            ) from exc
    stored = store.put_profile(str(user.id), user.village_id, body)
    return _profile_out(stored, store)


@router.delete("/profile", status_code=204)
def delete_profile(user: CurrentUser, store: Store) -> Response:
    """
    Delete his answers (rule L8), and his saved reports with them: a report is built from his
    answers, so it goes too. Deleting nothing is not an error: the end state is the same.
    """
    # Reports first: if the second step fails, he still has his profile and simply retries. The
    # other order could leave a report holding his name after the profile was already gone.
    store.delete_reports(str(user.id))
    store.delete_profile(str(user.id))
    return Response(status_code=204)


def _settings_config() -> LivelihoodConfig:
    """The default tuning, with the radius limits from the settings."""
    s = get_settings()
    return replace(
        DEFAULT_CONFIG,
        default_radius_m=s.livelihood_default_radius_m,
        max_radius_m=s.livelihood_max_radius_m,
    )


def _village_of(user: UserInfo, store: LivelihoodStore) -> VillageGeo:
    """His village, from his login. With no village on his role there is no report."""
    if user.village_id is None:
        raise ApiError(422, "NO_VILLAGE", "livelihood.no_village")
    village = store.get_village(user.village_id)
    if village is None:
        raise ApiError(422, "VILLAGE_NOT_FOUND", "livelihood.village_not_found")
    return village


class ReportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    radius_m: int | None = None  # default 5000, capped at 10000


@router.post("/report", response_model=ReportOut)
def make_report(body: ReportRequest, user: CurrentUser, store: Store) -> ReportOut:
    """
    Build his report now from his saved details (or a general village report if he has saved none),
    keep it as his latest, and return it.
    """
    cfg = _settings_config()
    village = _village_of(user, store)
    stored = store.get_profile(str(user.id))
    profile = stored.profile if stored else None

    dataset = store.dataset_meta()
    ideas = store.list_ideas()
    if dataset is None or not ideas:
        # an empty database must not look like "nothing is near you" (rule L1). Checked before
        # the request itself, so a missing-data problem is reported the same way every time.
        raise ApiError(503, "DATA_NOT_LOADED", "livelihood.data_not_loaded")
    centre, radius = resolve_search(profile, village, body.radius_m, cfg)
    candidates = store.resource_candidates(circle_polygon(centre, search_radius(radius, cfg)))

    report = build_report(
        profile=profile,
        user_name=user.name,
        village=village,
        resources=candidates,
        ideas=ideas,
        dataset=dataset,
        cfg=cfg,
        radius_m=radius,
        weather=load_sample_weather(),  # sample numbers until a real source is chosen (Q11)
        report_id=uuid7().hex,
    )
    store.save_report(str(user.id), report)
    return report


@router.get("/report/latest", response_model=ReportOut)
def latest_report(user: CurrentUser, store: Store) -> ReportOut:
    """His latest report, as it was made. Says so if newer data has been loaded since."""
    report = store.latest_report(str(user.id))
    if report is None:
        raise ApiError(404, "NO_REPORT", "livelihood.no_report")
    dataset = store.dataset_meta()
    if dataset is not None and dataset.data_version != report.data_version:
        report = report.model_copy(update={"newer_version_available": True})
    return report


class NearbyRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    radius_m: int | None = None
    kinds: list[ResourceKind] | None = None


@router.post("/resources/nearby", response_model=NearbyOut)
def resources_nearby(body: NearbyRequest, user: CurrentUser, store: Store) -> NearbyOut:
    """What is near any point, labelled. No ideas and nothing is saved: a quick look."""
    cfg = _settings_config()
    village = _village_of(user, store)
    probe = ProfileIn(location=LocationIn(lat=body.lat, lng=body.lng, source=LocationSource.MANUAL))
    dataset = store.dataset_meta()
    if dataset is None:
        raise ApiError(503, "DATA_NOT_LOADED", "livelihood.data_not_loaded")
    centre, radius = resolve_search(probe, village, body.radius_m, cfg)

    candidates = store.resource_candidates(circle_polygon(centre, radius))
    nearby = find_nearby(candidates, centre, radius, village, body.kinds)
    listed = label_nearby(nearby, cfg, within_m=radius)
    return NearbyOut(
        centre=Centre(lat=centre.lat, lng=centre.lng, source=centre.source),
        radius_m=radius,
        resources=[resource_card(r) for r in listed],
        counts=count_labels(listed),
        is_sample_data=dataset.is_sample or any(r.near.record.is_sample for r in listed),
    )


def _require_demo() -> None:
    if not get_settings().livelihood_demo_endpoints:
        raise ApiError(404, "NOT_FOUND", "error.not_found")


@router.get("/meta")
def meta() -> dict[str, Any]:
    """What the form needs: vocabularies, radius limits, and which dataset is loaded."""
    header, _ = load_sample_dataset()
    settings = get_settings()
    return {
        "default_radius_m": settings.livelihood_default_radius_m,
        "max_radius_m": settings.livelihood_max_radius_m,
        "area_units": [u.value for u in AreaUnit],
        "asset_codes": list(ASSET_CODES),
        "animal_codes": list(ANIMAL_CODES),
        "past_work_codes": list(PAST_WORK_CODES),
        "dataset": {
            "name": header["dataset"],
            "data_version": header["data_version"],
            "is_sample": header["is_sample"],
            "source": header["source"],
        },
        "demo_plot": DEMO_PLOT,
        "bands": {  # labels only; the numbers behind them are never sent to the app (rule L5)
            "resource": ["useful", "partly_useful", "not_useful"],
            "fit": ["good", "fair", "weak"],
        },
    }


@router.post("/demo/report", response_model=ReportOut)
def demo_report(body: DemoReportRequest) -> ReportOut:
    """A full report from the SAMPLE dataset for the details given. Stores nothing."""
    _require_demo()
    header, records = load_sample_dataset()
    cfg = _settings_config()
    return build_report(
        profile=body.profile,
        user_name=body.name,
        village=load_demo_village(),
        resources=records,
        ideas=load_ideas(),
        dataset=DatasetMeta(
            name=header["dataset"],
            data_version=header["data_version"],
            is_sample=header["is_sample"],
            source=header["source"],
            source_date=header["source_date"],
        ),
        cfg=cfg,
        radius_m=body.radius_m,
        weather=load_sample_weather(),
    )
