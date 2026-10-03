"""
Statutory clocks (Spec §8). Pure date arithmetic: the service gathers the start dates
and this module says when each period ends and where it stands today.
"""

from dataclasses import dataclass
from datetime import date, timedelta
from enum import StrEnum

from .dates import CLAIM_WINDOW_MONTHS, add_months

PETITION_DAYS = 60  # against a Gram Sabha resolution [Sec 6(2), Rule 14(1)]
PETITION_EXTENSION_DAYS = 30
MUTUAL_SOLUTION_DAYS = 30  # between Gram Sabhas [Rule 14(7)]
RECORD_UPDATE_MONTHS = 3  # after title [Rule 12A(9)]
ALERT_DAYS = (30, 45, 55, 58)  # days after the start at which to remind (60-day clocks)


class ClockStatus(StrEnum):
    RUNNING = "running"
    OVERDUE = "overdue"
    MET = "met"


@dataclass(frozen=True)
class Clock:
    kind: str
    rule: str
    starts_on: date
    due_on: date
    status: ClockStatus
    days_remaining: int  # negative when overdue
    next_alert_on: date | None


def petition_due(resolution_on: date) -> date:
    return resolution_on + timedelta(days=PETITION_DAYS)


def claim_window_due(called_on: date) -> date:
    return add_months(called_on, CLAIM_WINDOW_MONTHS)


def clock(
    kind: str,
    rule: str,
    starts_on: date,
    due_on: date,
    today: date,
    *,
    met_on: date | None = None,
    alerts: tuple[int, ...] = (),
) -> Clock:
    if met_on is not None:
        status = ClockStatus.MET
    elif today > due_on:
        status = ClockStatus.OVERDUE
    else:
        status = ClockStatus.RUNNING
    next_alert = None
    if status is ClockStatus.RUNNING:
        upcoming = [
            starts_on + timedelta(days=d) for d in alerts if starts_on + timedelta(days=d) >= today
        ]
        next_alert = min(upcoming) if upcoming else None
    return Clock(
        kind=kind,
        rule=rule,
        starts_on=starts_on,
        due_on=due_on,
        status=status,
        days_remaining=(due_on - today).days,
        next_alert_on=next_alert,
    )
