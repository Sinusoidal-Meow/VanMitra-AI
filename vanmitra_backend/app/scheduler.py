"""
Background work while the server runs: every few minutes, close the claims whose time
to resubmit has passed (services.expiry). A failure (for example the database being
down) is logged and retried at the next turn; it never stops the server.
"""

import asyncio
import logging

from .db import get_db
from .services.expiry import expire_overdue

log = logging.getLogger(__name__)


def _check_once() -> None:
    for db in get_db():  # one session, closed afterwards
        expire_overdue(db)


async def _loop(minutes: int) -> None:
    while True:
        try:
            await asyncio.to_thread(_check_once)
        except Exception:  # noqa: BLE001 - keep the server alive, try again next turn
            log.exception("expiry check failed; will retry")
        await asyncio.sleep(minutes * 60)


def run_expiry_checks(minutes: int) -> "asyncio.Task[None] | None":
    """Start the periodic check (None when switched off with 0 minutes)."""
    if minutes <= 0:
        return None
    return asyncio.get_running_loop().create_task(_loop(minutes))
