"""Statutory clock arithmetic (no database)."""

from datetime import date, timedelta

from app.documents import map_svg, render
from app.domain.clocks import ALERT_DAYS, ClockStatus, claim_window_due, clock, petition_due

TODAY = date(2026, 10, 3)


def test_petition_is_sixty_days_from_the_resolution() -> None:
    assert petition_due(date(2026, 9, 1)) == date(2026, 10, 31)


def test_claim_window_is_three_months() -> None:
    assert claim_window_due(date(2026, 11, 30)) == date(2027, 2, 28)


def test_running_clock_reports_days_and_next_alert() -> None:
    start = TODAY - timedelta(days=40)
    c = clock("petition", "Sec 6(2)", start, petition_due(start), TODAY, alerts=ALERT_DAYS)
    assert c.status is ClockStatus.RUNNING
    assert c.days_remaining == 20
    assert c.next_alert_on == start + timedelta(days=45)


def test_overdue_and_met() -> None:
    start = TODAY - timedelta(days=70)
    overdue = clock("petition", "Sec 6(2)", start, petition_due(start), TODAY)
    assert overdue.status is ClockStatus.OVERDUE and overdue.days_remaining == -10
    assert overdue.next_alert_on is None
    met = clock("x", "r", start, petition_due(start), TODAY, met_on=TODAY - timedelta(days=5))
    assert met.status is ClockStatus.MET


def test_due_day_itself_is_still_running() -> None:
    assert clock("x", "r", TODAY, TODAY, TODAY).status is ClockStatus.RUNNING


class _Village:
    name_mr = "ओझर"
    name_en = "Ozhar <script>"
    gram_panchayat = "Ozhar"
    taluka = "Jawhar"
    district = "Palghar"


def test_document_is_escaped_hashed_and_carries_the_disclaimer() -> None:
    html = render("g13", "mr", _Village(), "case-1", {
        "r": {"number": "1/2026", "decision_text": "<b>approved</b>",
              "votes_for": 3, "votes_against": 0},
        "meeting": {"held_on": "2026-09-10", "place": "GP", "agenda": "CFR"},
        "q": {"present": 3, "registered": 6, "women_present": 1, "claimants_present": 1,
              "claimants_total": 2, "passed": True},
        "boundary_sealed": "a" * 64,
    })  # fmt: skip
    assert "&lt;b&gt;approved&lt;/b&gt;" in html and "<script>" not in html
    assert "Not a government document" in html and "SHA-256" in html
    assert "ग्रामसभा ठराव" in html


def test_map_svg_numbers_the_landmarks() -> None:
    outline = {
        "type": "Polygon",
        "coordinates": [[[73.2, 19.9], [73.21, 19.9], [73.21, 19.91], [73.2, 19.91], [73.2, 19.9]]],
    }
    svg = map_svg(outline, [(73.205, 19.9), (73.21, 19.905)], [])
    assert svg.startswith("<svg") and svg.count("<circle") == 2 and ">2</text>" in svg
