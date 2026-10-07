"""Calendar arithmetic for statutory periods."""

import calendar
from datetime import date, datetime, timedelta, timezone

# Indian Standard Time. India has no daylight saving, so a fixed offset is exact. Days
# counted for villagers (such as the 60 days to resubmit) follow the Indian calendar,
# whatever time zone the server itself runs in.
IST = timezone(timedelta(hours=5, minutes=30), "IST")


def today_ist() -> date:
    """Today's date in India."""
    return datetime.now(IST).date()


def ist_date(moment: datetime) -> date:
    """The Indian calendar date of a recorded moment (stored with its time zone)."""
    return moment.astimezone(IST).date()


def add_months(d: date, months: int) -> date:
    """Same day `months` later, clamped to the month's last day (31 Jan + 1 = 28/29 Feb)."""
    month_index = d.month - 1 + months
    year = d.year + month_index // 12
    month = month_index % 12 + 1
    day = min(d.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


CLAIM_WINDOW_MONTHS = 3  # Rule 11(1)(a)
