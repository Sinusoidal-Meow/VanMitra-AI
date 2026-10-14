"""
Where profiles, reports and resources are kept.

`LivelihoodStore` is the one interface the routes use. Two implementations:
- `InMemoryStore`: nothing persists across restarts. Development and tests. It serves the bundled
  SAMPLE dataset, so it needs no database.
- `MongoStore` (mongo_store.py): the real database.

Which one a request gets is decided in deps.py (the one file that differs in the host).
Everything personal is keyed by the signed-in user's id: there is no way to ask for someone
else's profile or report.
"""

import threading
from collections.abc import Sequence
from datetime import UTC, datetime
from typing import Any, Protocol

from pydantic import BaseModel, Field
from shapely.geometry import shape

from .ask_schemas import ChatTurn
from .schemas import Idea, ProfileIn, ReportOut, ResourceRecord, VillageGeo
from .scheme_schemas import SchemeRecord
from .seed import load_demo_village, load_ideas, load_sample_dataset, load_schemes
from .service import DatasetMeta

KEEP_REPORTS = 5  # the latest few per user; older ones are removed
KEEP_CHAT = 50  # the latest questions and answers per user


class StoredProfile(BaseModel):
    """A saved profile: what he told us, and when. Exists once per user."""

    user_id: str
    village_id: str | None
    profile: ProfileIn
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class LivelihoodStore(Protocol):
    # profile
    def get_profile(self, user_id: str) -> StoredProfile | None: ...

    def put_profile(
        self, user_id: str, village_id: str | None, profile: ProfileIn
    ) -> StoredProfile:
        """Create or REPLACE (never merge) the user's profile. created_at is kept on replace."""
        ...

    def delete_profile(self, user_id: str) -> bool:
        """Delete his answers (rule L8). True if there was something to delete."""
        ...

    # reports (personal data: they hold his name and his answers' consequences)
    def save_report(self, user_id: str, report: ReportOut) -> None:
        """Keep it as his latest; only the latest KEEP_REPORTS are retained."""
        ...

    def latest_report(self, user_id: str) -> ReportOut | None: ...

    def delete_reports(self, user_id: str) -> int:
        """Delete all his reports (done whenever he deletes his answers). Returns how many."""
        ...

    # the Ask box history (personal: it holds what he typed)
    def append_chat(self, user_id: str, turn: ChatTurn) -> None:
        """Keep a question and its answer; only the latest KEEP_CHAT are retained."""
        ...

    def list_chat(self, user_id: str) -> list[ChatTurn]:
        """His history, oldest first."""
        ...

    def delete_chat(self, user_id: str) -> int:
        """Delete all his history (rule L8). Returns how many turns."""
        ...

    # a cost cap for the AI step: a counter, NOT part of his history, so clearing his questions
    # cannot reset it
    def take_ai_use(self, user_id: str, day: str, limit: int) -> bool:
        """Count one AI call for this person on this UTC day, BEFORE the call is made. False
        (and nothing counted) if he has already used `limit` today. Failed calls count too."""
        ...

    # shared data
    def get_village(self, village_id: str) -> VillageGeo | None: ...

    def list_ideas(self) -> list[Idea]: ...

    def list_schemes(self) -> list[SchemeRecord]:
        """The scheme register (links to official pages only). Empty if none is loaded."""
        ...

    def dataset_meta(self) -> DatasetMeta | None:
        """The newest resource dataset, or None if none is loaded."""
        ...

    def resource_candidates(self, circle: dict[str, Any]) -> Sequence[ResourceRecord]:
        """
        Active, non-sensitive resources whose geometry touches the circle polygon. This is only a
        coarse candidate search: the exact distance is computed afterwards (geo.find_nearby).
        """
        ...


def _dataset_of(header: dict[str, Any]) -> DatasetMeta:
    return DatasetMeta(
        header["dataset"],
        header["data_version"],
        bool(header["is_sample"]),
        header["source"],
        header["source_date"],
    )


class InMemoryStore:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._profiles: dict[str, StoredProfile] = {}
        self._reports: dict[str, list[ReportOut]] = {}
        self._chat: dict[str, list[ChatTurn]] = {}
        self._ai_use: dict[tuple[str, str], int] = {}
        self._header, self._resources = load_sample_dataset()

    # profile
    def get_profile(self, user_id: str) -> StoredProfile | None:
        with self._lock:
            stored = self._profiles.get(user_id)
            return stored.model_copy(deep=True) if stored else None

    def put_profile(
        self, user_id: str, village_id: str | None, profile: ProfileIn
    ) -> StoredProfile:
        with self._lock:
            now = datetime.now(UTC)
            existing = self._profiles.get(user_id)
            stored = StoredProfile(
                user_id=user_id,
                village_id=village_id,
                profile=profile,
                created_at=existing.created_at if existing else now,
                updated_at=now,
            )
            self._profiles[user_id] = stored
            return stored.model_copy(deep=True)

    def delete_profile(self, user_id: str) -> bool:
        with self._lock:
            return self._profiles.pop(user_id, None) is not None

    # reports
    def save_report(self, user_id: str, report: ReportOut) -> None:
        with self._lock:
            kept = [report, *self._reports.get(user_id, [])]
            self._reports[user_id] = kept[:KEEP_REPORTS]

    def latest_report(self, user_id: str) -> ReportOut | None:
        with self._lock:
            reports = self._reports.get(user_id)
            return reports[0].model_copy(deep=True) if reports else None

    def delete_reports(self, user_id: str) -> int:
        with self._lock:
            return len(self._reports.pop(user_id, []))

    # the Ask box history
    def append_chat(self, user_id: str, turn: ChatTurn) -> None:
        with self._lock:
            self._chat[user_id] = [*self._chat.get(user_id, []), turn][-KEEP_CHAT:]

    def list_chat(self, user_id: str) -> list[ChatTurn]:
        with self._lock:
            return [t.model_copy(deep=True) for t in self._chat.get(user_id, [])]

    def delete_chat(self, user_id: str) -> int:
        with self._lock:
            return len(self._chat.pop(user_id, []))

    def take_ai_use(self, user_id: str, day: str, limit: int) -> bool:
        with self._lock:
            used = self._ai_use.get((user_id, day), 0)
            if used >= limit:
                return False
            self._ai_use[(user_id, day)] = used + 1
            return True

    # shared data
    def get_village(self, village_id: str) -> VillageGeo | None:
        demo = load_demo_village()
        return demo if demo.village_id == village_id else None

    def list_ideas(self) -> list[Idea]:
        return list(load_ideas())

    def list_schemes(self) -> list[SchemeRecord]:
        return list(load_schemes())

    def dataset_meta(self) -> DatasetMeta | None:
        return _dataset_of(self._header)

    def resource_candidates(self, circle: dict[str, Any]) -> Sequence[ResourceRecord]:
        area = shape(circle)
        return [
            r
            for r in self._resources
            if r.status == "active" and not r.sensitive and area.intersects(shape(r.geometry))
        ]
