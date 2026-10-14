"""The smoke script's two exercises, run over the in-memory store: this proves the script logic.
(The same exercises run over the real MongoStore when a person runs scripts.smoke_mongo.)"""

import pytest

from app.livelihood.store import InMemoryStore
from scripts import smoke_mongo


def test_the_profile_exercise_passes_on_the_in_memory_store() -> None:
    smoke_mongo.exercise_profile(InMemoryStore())


def test_the_route_exercise_passes_on_the_in_memory_store(
    capsys: pytest.CaptureFixture[str],
) -> None:
    smoke_mongo.exercise_routes(InMemoryStore())
    out = capsys.readouterr().out
    assert "resources were found within 5 km" in out and "delete my answers" in out


def test_it_refuses_a_database_that_is_not_a_throwaway(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("VANMITRA_MONGODB_DB", "vanmitra")
    from app.config import get_settings

    get_settings.cache_clear()
    try:
        with pytest.raises(SystemExit, match="does not end with _test"):
            smoke_mongo.main()
    finally:
        get_settings.cache_clear()
