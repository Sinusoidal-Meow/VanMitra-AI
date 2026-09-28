"""API tests that need no database (the configured one is unreachable on purpose)."""

from fastapi.testclient import TestClient


def test_health_is_200_even_without_database(client: TestClient) -> None:
    res = client.get("/api/v1/health")
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "ok"
    assert body["database"] == "unavailable"
    assert body["legacy_api"] is False


def test_legacy_routes_absent_when_disabled(client: TestClient) -> None:
    assert client.post("/api/v1/eligibility-check", json={}).status_code == 404


def test_me_without_token_uses_error_format(client: TestClient) -> None:
    res = client.get("/api/v1/me")
    assert res.status_code == 401
    assert res.json() == {
        "error": "NOT_AUTHENTICATED",
        "message_key": "auth.required",
        "details": {},
    }


def test_me_with_garbage_token(client: TestClient) -> None:
    res = client.get("/api/v1/me", headers={"Authorization": "Bearer not-a-jwt"})
    assert res.status_code == 401
    assert res.json()["error"] == "TOKEN_INVALID"


def test_login_validation_error_format(client: TestClient) -> None:
    # Rejected before any database access: bad phone and a 4-digit PIN.
    res = client.post("/api/v1/auth/login", json={"phone": "12345", "pin": "1234"})
    assert res.status_code == 422
    body = res.json()
    assert body["error"] == "VALIDATION_ERROR"
    assert body["message_key"] == "validation.invalid"
    assert {e["loc"][-1] for e in body["details"]["errors"]} == {"phone", "pin"}


def test_unknown_route_uses_error_format(client: TestClient) -> None:
    res = client.get("/api/v1/does-not-exist")
    assert res.status_code == 404
    assert res.json()["error"] == "HTTP_404"


def test_openapi_lists_stage0_endpoints(client: TestClient) -> None:
    paths = client.get("/openapi.json").json()["paths"]
    assert {"/api/v1/health", "/api/v1/auth/login", "/api/v1/auth/refresh", "/api/v1/me"} <= set(
        paths
    )


def test_form_b_endpoints_need_login(client: TestClient) -> None:
    case = "00000000-0000-0000-0000-000000000000"
    assert client.get(f"/api/v1/cases/{case}/form-b").status_code == 401
    assert client.put(f"/api/v1/cases/{case}/form-b", json={}).status_code == 401
    assert client.get("/api/v1/forms/form-b/fields").status_code == 401
    assert (
        client.post(f"/api/v1/villages/{case}/cases", json={"claim_type": "cr"}).status_code == 401
    )
