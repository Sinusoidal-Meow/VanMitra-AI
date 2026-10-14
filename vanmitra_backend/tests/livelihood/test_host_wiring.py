"""
Module 4 inside the host app: how a host login becomes a livelihood user, and that the routes are
mounted behind the host's own login. No database is needed.
"""

import uuid
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.auth.principal import Principal, RoleGrant
from app.errors import ApiError
from app.livelihood.deps import get_store, get_user_info
from app.livelihood.identity import UserInfo
from app.livelihood.store import InMemoryStore
from app.main import create_app
from app.models import AppUser, Role

URL = "/api/v1/livelihood"


def _user(name: str = "Sita") -> AppUser:
    return AppUser(phone="9000000099", pin_hash="x", name=name)


def _principal(user: AppUser, *grants: RoleGrant, admin: bool = False) -> Principal:
    return Principal(user_id=user.id, name=user.name, is_admin=admin, grants=frozenset(grants))


def test_a_villager_is_served_with_the_village_from_their_role() -> None:
    village = uuid.uuid4()
    user = _user()
    info = get_user_info(user, _principal(user, RoleGrant(Role.VILLAGER, village_id=village)))
    assert info.id == user.id and info.name == "Sita"
    assert info.village_id == str(village) and info.roles == {"villager"}


def test_a_gram_sabha_user_is_served_for_their_own_village() -> None:
    village = uuid.uuid4()
    user = _user()
    info = get_user_info(user, _principal(user, RoleGrant(Role.GRAM_SABHA, village_id=village)))
    assert info.village_id == str(village) and info.roles == {"gram_sabha"}


def test_someone_who_is_both_is_served_as_the_villager() -> None:
    own, office = uuid.uuid4(), uuid.uuid4()
    user = _user()
    info = get_user_info(
        user,
        _principal(
            user,
            RoleGrant(Role.GRAM_SABHA, village_id=office),
            RoleGrant(Role.VILLAGER, village_id=own),
        ),
    )
    assert info.village_id == str(own)  # their own land, not the village they administer
    assert info.roles == {"villager", "gram_sabha"}


@pytest.mark.parametrize(
    "grants",
    [
        (),  # no role at all
        (RoleGrant(Role.SDO, taluka="Jawhar", district="Palghar"),),
        (RoleGrant(Role.COLLECTOR, district="Palghar"),),
        (RoleGrant(Role.DFO, district="Palghar"),),
        (RoleGrant(Role.VILLAGER, village_id=None),),  # a village role with no village
    ],
)
def test_other_roles_are_refused_with_a_plain_reason(grants: tuple[RoleGrant, ...]) -> None:
    user = _user()
    with pytest.raises(ApiError) as exc:
        get_user_info(user, _principal(user, *grants))
    assert exc.value.status_code == 403
    assert exc.value.message_key == "livelihood.role_not_allowed"


def test_admin_does_not_bypass_it() -> None:
    """Back-office accounts read no personal livelihood data (the host's rule for case content)."""
    user = _user("Admin")
    with pytest.raises(ApiError):
        get_user_info(user, _principal(user, admin=True))


@pytest.fixture
def client() -> Iterator[TestClient]:
    app = create_app()
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_the_routes_sit_behind_the_hosts_login(client: TestClient) -> None:
    """No override installed: the host's real bearer check answers, before any database is used."""
    for call, path in (
        (client.get, "/profile"),
        (client.delete, "/profile"),
        (client.get, "/report/latest"),
    ):
        r = call(f"{URL}{path}")
        assert r.status_code == 401 and r.json()["error"] == "NOT_AUTHENTICATED", path
    assert client.put(f"{URL}/profile", json={}).status_code == 401
    assert client.post(f"{URL}/report", json={}).status_code == 401
    assert (
        client.post(f"{URL}/resources/nearby", json={"lat": 19.78, "lng": 73.22}).status_code == 401
    )
    bad = client.get(f"{URL}/profile", headers={"Authorization": "Bearer not-a-token"})
    assert bad.status_code == 401 and bad.json()["error"] == "TOKEN_INVALID"


def test_meta_is_public_and_the_demo_route_is_off(client: TestClient) -> None:
    meta = client.get(f"{URL}/meta")
    assert meta.status_code == 200 and meta.json()["default_radius_m"] == 5000
    assert meta.json()["max_radius_m"] == 10000
    assert client.post(f"{URL}/demo/report", json={}).status_code == 404  # off by default


def test_the_whole_flow_through_the_host_app(client: TestClient) -> None:
    store = InMemoryStore()
    me = UserInfo(uuid.uuid4(), "Sita", "sample_ozhar", frozenset({"villager"}))
    client.app.dependency_overrides[get_store] = lambda: store  # type: ignore[attr-defined]
    client.app.dependency_overrides[get_user_info] = lambda: me  # type: ignore[attr-defined]

    mine = {
        "land": {"area_value": 3, "area_unit": "acre"},
        "location": {"lat": 19.7805, "lng": 73.221, "source": "gps"},
        "livestock": {"cow": 2},
        "assets": ["well"],
        "past_work": ["dairy"],
    }
    assert client.put(f"{URL}/profile", json=mine).status_code == 200
    report = client.post(f"{URL}/report", json={}).json()
    assert report["header"]["name"] == "Sita" and report["header"]["report_level"] == "plot"
    assert report["is_sample_data"] is True and len(report["resources"]) == 10
    assert client.get(f"{URL}/report/latest").json()["id"] == report["id"]

    assert client.delete(f"{URL}/profile").status_code == 204
    assert client.get(f"{URL}/report/latest").status_code == 404
    assert client.get(f"{URL}/profile").status_code == 404


def test_ask_schemes_and_idea_detail_sit_behind_the_hosts_login(client: TestClient) -> None:
    for call, path in (
        (client.get, "/schemes"),
        (client.get, "/ask/history"),
        (client.delete, "/ask/history"),
        (client.get, "/ideas/any_code"),
    ):
        r = call(f"{URL}{path}")
        assert r.status_code == 401 and r.json()["error"] == "NOT_AUTHENTICATED", path
    assert client.post(f"{URL}/ask", json={"question": "best idea"}).status_code == 401


def test_ask_schemes_and_idea_detail_through_the_host_app(client: TestClient) -> None:
    store = InMemoryStore()
    me = UserInfo(uuid.uuid4(), "Sita", "sample_ozhar", frozenset({"villager"}))
    client.app.dependency_overrides[get_store] = lambda: store  # type: ignore[attr-defined]
    client.app.dependency_overrides[get_user_info] = lambda: me  # type: ignore[attr-defined]

    mine = {
        "land": {"area_value": 3, "area_unit": "acre"},
        "location": {"lat": 19.7805, "lng": 73.221, "source": "gps"},
        "livestock": {"cow": 2},
        "assets": ["well"],
    }
    assert client.put(f"{URL}/profile", json=mine).status_code == 200
    report = client.post(f"{URL}/report", json={}).json()

    # the Ask box answers from his report; a harmful question gets the red card and no answer
    ok = client.post(f"{URL}/ask", json={"question": "What is the best idea for me?", "lang": "en"})
    assert ok.status_code == 200
    assert ok.json()["turn"]["answer"]["kind"] == "ANSWER"
    bad = client.post(f"{URL}/ask", json={"question": "how to poison a leopard", "lang": "en"})
    assert bad.status_code == 200
    assert bad.json()["turn"]["answer"]["kind"] == "REFUSED_HARMFUL"
    turns = client.get(f"{URL}/ask/history").json()["turns"]
    assert [t["question"] for t in turns] == ["What is the best idea for me?", None]  # not kept
    assert client.delete(f"{URL}/ask/history").status_code == 204

    # an idea of his report in full, and the schemes register (every row labelled Sample)
    code = report["ideas"][0]["code"]
    assert client.get(f"{URL}/ideas/{code}").status_code == 200
    assert client.get(f"{URL}/ideas/no_such_idea").status_code == 404
    register = client.get(f"{URL}/schemes").json()
    assert register["is_sample_data"] is True or register["register_empty"] is True
