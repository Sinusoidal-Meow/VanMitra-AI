"""The deploy checker, run against a fake server: it must say what is wrong, in order."""

from typing import Any

from scripts.check_deploy import run

OK_HEALTH = {"status": "ok", "service": "vanmitra-backend", "database": "ok", "legacy_api": False}


def fake(routes: dict[tuple[str, str], tuple[int, Any]]) -> Any:
    calls: list[tuple[str, str]] = []

    def http(method: str, url: str, headers: dict[str, str], body: Any) -> tuple[int, Any]:
        path = url.split("/api/v1", 1)[1]
        calls.append((method, path))
        return routes.get((method, path), (404, None))

    http.calls = calls  # type: ignore[attr-defined]
    return http


GOOD = {
    ("GET", "/health"): (200, OK_HEALTH),
    ("GET", "/livelihood/meta"): (200, {"dataset": {"name": "sample_demo", "is_sample": True}}),
    ("POST", "/auth/login"): (200, {"access_token": "t"}),
    ("GET", "/me"): (200, {}),
    ("GET", "/livelihood/profile"): (404, None),
    ("GET", "/livelihood/schemes"): (200, {"register_empty": False}),
}


def test_everything_fine(capsys: Any) -> None:
    http = fake(GOOD)
    assert run("https://x.app/", ("9000000001", "123456"), http) == 0
    assert "ALL CHECKS PASSED" in capsys.readouterr().out


def test_without_login_it_signs_in_nowhere() -> None:
    http = fake(GOOD)
    assert run("https://x.app", None, http) == 0
    assert ("POST", "/auth/login") not in http.calls


def test_unreachable_server(capsys: Any) -> None:
    assert run("https://x.app", None, fake({("GET", "/health"): (0, "refused")})) == 1
    assert "no connection" in capsys.readouterr().out


def test_not_a_vanmitra_server() -> None:
    assert run("https://x.app", None, fake({("GET", "/health"): (200, {"hello": 1})})) == 1


def test_database_down_names_the_atlas_fix(capsys: Any) -> None:
    routes = {**GOOD, ("GET", "/health"): (200, {**OK_HEALTH, "database": "unavailable"})}
    assert run("https://x.app", None, fake(routes)) == 1
    assert "Network Access" in capsys.readouterr().out


def test_empty_register_names_the_setup_command(capsys: Any) -> None:
    routes = {**GOOD, ("GET", "/livelihood/schemes"): (200, {"register_empty": True})}
    assert run("https://x.app", ("9000000001", "123456"), fake(routes)) == 1
    assert "setup_module4_demo --apply" in capsys.readouterr().out


def test_wrong_pin_stops_the_user_checks(capsys: Any) -> None:
    routes = {**GOOD, ("POST", "/auth/login"): (401, {"error": "INVALID_CREDENTIALS"})}
    http = fake(routes)
    assert run("https://x.app", ("9000000001", "000000"), http) == 1
    assert ("GET", "/me") not in http.calls


def test_a_role_without_module_4_is_called_out(capsys: Any) -> None:
    routes = {**GOOD, ("GET", "/livelihood/profile"): (403, None)}
    assert run("https://x.app", ("9000000005", "123456"), fake(routes)) == 1
    assert "403" in capsys.readouterr().out


def test_an_address_with_api_v1_is_accepted() -> None:
    http = fake(GOOD)
    assert run("https://x.app/api/v1", None, http) == 0
