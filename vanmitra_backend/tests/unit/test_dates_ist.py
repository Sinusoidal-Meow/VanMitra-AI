"""Days for villagers follow the Indian calendar, whatever the server's time zone."""

from datetime import UTC, date, datetime

from app.domain.dates import ist_date


def test_late_evening_utc_is_already_the_next_day_in_india() -> None:
    # 19:00 UTC on 7 October is 00:30 IST on 8 October
    assert ist_date(datetime(2026, 10, 7, 19, 0, tzinfo=UTC)) == date(2026, 10, 8)


def test_early_utc_morning_is_the_same_day_in_india() -> None:
    assert ist_date(datetime(2026, 10, 7, 3, 0, tzinfo=UTC)) == date(2026, 10, 7)
