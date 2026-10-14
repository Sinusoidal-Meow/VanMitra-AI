"""
[USER RUNS] Check a deployed VanMitra server the way the phone will use it. Reads from the
server only; nothing is written to the database by this script. (Signing in makes the server note
the last-login time of that user, as it does for every sign-in.)

    python -m scripts.check_deploy https://your-server.up.railway.app
    python -m scripts.check_deploy https://your-server.up.railway.app --login 9000000001:123456

Without --login it checks the server, its database and that Module 4 is mounted. With --login it
also signs in, reads the profile and the schemes register, and tells you if Module 4's data has
not been loaded yet (python -m scripts.setup_module4_demo --apply).

Exit code 0 only when every check passes.
"""

import json
import sys
import urllib.error
import urllib.request
from collections.abc import Callable
from typing import Any

Http = Callable[[str, str, dict[str, str], Any], tuple[int, Any]]


def _http(method: str, url: str, headers: dict[str, str], body: Any) -> tuple[int, Any]:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)  # noqa: S310 (https/http only)
    for k, v in {"Accept": "application/json", **headers}.items():
        req.add_header(k, v)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:  # noqa: S310
            raw = r.read().decode() or "null"
            return r.status, json.loads(raw)
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode() or "null")
        except ValueError:
            return e.code, None
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        return 0, str(e)


def run(base: str, login: tuple[str, str] | None = None, http: Http = _http) -> int:
    base = base.rstrip("/")
    if base.endswith("/api/v1"):
        base = base[: -len("/api/v1")]
    api = f"{base}/api/v1"
    failed = 0

    def report(ok: bool, what: str, hint: str = "") -> None:
        nonlocal failed
        print(
            f"  {'PASS' if ok else 'FAIL'}  {what}"
            + (f"\n        -> {hint}" if not ok and hint else "")
        )
        failed += 0 if ok else 1

    print(f"server: {base}")
    status, body = http("GET", f"{api}/health", {}, None)
    if status == 0:
        report(False, "the server answers", f"no connection: {body}")
        return 1
    served = status == 200 and isinstance(body, dict) and body.get("service") == "vanmitra-backend"
    report(
        served, "the server answers as VanMitra", "check the address (and that the deploy finished)"
    )
    if not served:
        return 1
    db_ok = body.get("database") == "ok"
    report(
        db_ok,
        "the database is connected",
        "MongoDB Atlas > Network Access: allow the server (demo: 0.0.0.0/0), wait a minute",
    )
    legacy = bool(body.get("legacy_api"))
    print(f"  info  old AI endpoints: {'on' if legacy else 'off (as intended for the lean image)'}")

    status, meta = http("GET", f"{api}/livelihood/meta", {}, None)
    report(
        status == 200,
        "Module 4 (livelihood) is mounted",
        "the deployed code is older than Module 4",
    )
    if status == 200 and isinstance(meta, dict):
        sample = bool(meta.get("dataset", {}).get("is_sample"))
        print(f"  info  dataset: {meta.get('dataset', {}).get('name')} (sample={sample})")

    if login is None:
        print("(no --login given: skipped sign-in checks)")
    else:
        phone, pin = login
        status, tokens = http("POST", f"{api}/auth/login", {}, {"phone": phone, "pin": pin})
        ok = status == 200 and isinstance(tokens, dict) and "access_token" in tokens
        report(
            ok,
            f"sign in as {phone}",
            "wrong phone or PIN, or that demo user is not in this database",
        )
        if ok:
            auth = {"Authorization": f"Bearer {tokens['access_token']}"}
            status, _ = http("GET", f"{api}/me", auth, None)
            report(status == 200, "the signed-in user can be read")
            status, _ = http("GET", f"{api}/livelihood/profile", auth, None)
            report(
                status in (200, 404),
                "Module 4 accepts this user (details saved or not yet)",
                "403 means this user's role (villager or Gram Sabha only) cannot use Module 4",
            )
            status, reg = http("GET", f"{api}/livelihood/schemes", auth, None)
            has_data = (
                status == 200 and isinstance(reg, dict) and not reg.get("register_empty", True)
            )
            report(
                has_data,
                "Module 4 data is loaded (schemes register has rows)",
                "run: python -m scripts.setup_module4_demo --apply",
            )

    print("ALL CHECKS PASSED" if failed == 0 else f"{failed} CHECK(S) FAILED")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    creds: tuple[str, str] | None = None
    if "--login" in sys.argv:
        pair = sys.argv[sys.argv.index("--login") + 1]
        phone_, _, pin_ = pair.partition(":")
        creds = (phone_, pin_)
        args = [a for a in args if a != pair]
    if len(args) != 1:
        raise SystemExit(
            "usage: python -m scripts.check_deploy <server address> [--login phone:pin]"
        )
    raise SystemExit(run(args[0], creds))
