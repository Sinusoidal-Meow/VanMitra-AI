"""Calendar arithmetic for statutory periods."""

import calendar
from datetime import date


def add_months(d: date, months: int) -> date:
    """Same day `months` later, clamped to the month's last day (31 Jan + 1 = 28/29 Feb)."""
    month_index = d.month - 1 + months
    year = d.year + month_index // 12
    month = month_index % 12 + 1
    day = min(d.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


CLAIM_WINDOW_MONTHS = 3  # Rule 11(1)(a)
