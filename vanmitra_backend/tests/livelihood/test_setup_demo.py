"""The one-command Module 4 demo setup: read-only check, dry run, and that nothing is written
without --apply. The database is a fake that records every write."""

from typing import Any

import pytest

from scripts import (
    load_livelihood_resources,
    seed_livelihood,
    setup_livelihood_indexes,
    setup_module4_demo,
)


class FakeCollection:
    def __init__(self, db: "FakeDB", name: str) -> None:
        self.db, self.name = db, name

    def count_documents(self, _filter: dict[str, Any]) -> int:
        return self.db.counts.get(self.name, 0)

    def find_one(self, _filter: dict[str, Any]) -> dict[str, Any] | None:
        return {"_id": "village-1"} if self.db.village and self.name == "village" else None

    def replace_one(self, *args: Any, **kwargs: Any) -> None:
        self.db.writes.append(self.name)


class FakeDB:
    def __init__(self, counts: dict[str, int] | None = None, village: bool = True) -> None:
        self.counts, self.village, self.writes = counts or {}, village, []

    def __getitem__(self, name: str) -> FakeCollection:
        return FakeCollection(self, name)


def _patch(monkeypatch: pytest.MonkeyPatch, db: FakeDB) -> None:
    class FakeClient:
        def __getitem__(self, _name: str) -> FakeDB:
            return db

    monkeypatch.setattr(setup_module4_demo, "_db", lambda: FakeClient())
    monkeypatch.setattr(seed_livelihood, "get_database", lambda: db)


FULL = {"lv_idea": 16, "lv_scheme": 8, "lv_resource": 12, "lv_dataset": 1, "lv_village_geo": 1}


def test_check_says_not_ready_when_the_collections_are_empty(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    _patch(monkeypatch, FakeDB())
    assert setup_module4_demo.check() == 1
    out = capsys.readouterr().out
    assert "EMPTY" in out and "NOT READY" in out


def test_check_says_ready_when_everything_is_there(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    _patch(monkeypatch, FakeDB(FULL))
    assert setup_module4_demo.check() == 0
    assert "READY" in capsys.readouterr().out


def test_check_needs_the_demo_village(monkeypatch: pytest.MonkeyPatch) -> None:
    _patch(monkeypatch, FakeDB(FULL, village=False))
    assert setup_module4_demo.check() == 1


def test_the_default_run_is_a_dry_run_that_writes_nothing(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    db = FakeDB()
    _patch(monkeypatch, db)
    assert setup_module4_demo.main(apply=False) == 0
    out = capsys.readouterr().out
    assert "dry run only" in out and "ideas: 16" in out and "schemes: 8" in out
    assert "accepted: 12" in out and "rejected: 0" in out
    assert db.writes == []


def test_apply_writes_ideas_schemes_village_and_resources(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    db = FakeDB()
    _patch(monkeypatch, db)
    # the module's own scripts open their own client for the writes: send them to the fake too
    monkeypatch.setattr(
        setup_livelihood_indexes, "MongoClient", lambda *a, **k: _FakeApplyClient(db)
    )
    monkeypatch.setattr(
        load_livelihood_resources, "MongoClient", lambda *a, **k: _FakeApplyClient(db)
    )
    assert setup_module4_demo.main(apply=True) == 0
    written = set(db.writes)
    assert {"lv_idea", "lv_scheme", "lv_village_geo", "lv_resource", "lv_dataset"} <= written


class _FakeApplyClient:
    def __init__(self, db: FakeDB) -> None:
        self.db = db

    def __getitem__(self, _name: str) -> "_FakeApplyDB":
        return _FakeApplyDB(self.db)


class _FakeApplyDB:
    def __init__(self, db: FakeDB) -> None:
        self.db = db

    def list_collection_names(self) -> list[str]:
        return []

    def create_collection(self, _name: str) -> None:
        return None

    def __getitem__(self, name: str) -> "_FakeApplyCollection":
        return _FakeApplyCollection(self.db, name)


class _FakeApplyCollection(FakeCollection):
    def create_indexes(self, _indexes: Any) -> None:
        return None
