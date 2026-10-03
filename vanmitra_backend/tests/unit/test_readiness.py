"""R1-R10 completeness, statutory dates and the hash-chain primitives (no database)."""

import uuid
from datetime import UTC, date, datetime, timedelta, timezone

import pytest

from app.domain.dates import add_months
from app.domain.readiness import ReadinessInput, readiness
from app.models import ClaimType, EvidenceKind, EvidenceRule
from app.models.procedure import Evidence
from app.services.ledger import GENESIS, canonical_payload, link_hash


def _input(**overrides: object) -> ReadinessInput:
    base: dict[str, object] = {
        "claim_type": ClaimType.CFR,
        "verified_general": 2,
        "verified_cfr": 1,
        "signed_elder_statement": True,
        "acknowledged": True,
        "boundary_gs_approved": True,
        "segments_without_landmark": 0,
        "verification_complete": True,
        "quorum_passed": True,
        "adjacent_total": 2,
        "adjacent_intimated": 2,
        "open_disputes": 0,
    }
    base.update(overrides)
    return ReadinessInput(**base)  # type: ignore[arg-type]


def _failing(r: ReadinessInput) -> set[str]:
    return {i.id for i in readiness(r).items if not i.ok}


def test_complete_cfr_case_passes_all_ten() -> None:
    c = readiness(_input())
    assert (c.done, c.total) == (10, 10)


@pytest.mark.parametrize(
    ("overrides", "fails"),
    [
        ({"verified_general": 1}, {"R1"}),
        ({"verified_cfr": 0}, {"R2"}),
        ({"boundary_gs_approved": False}, {"R3"}),
        ({"segments_without_landmark": None}, {"R4"}),
        ({"segments_without_landmark": 2}, {"R4"}),
        ({"verification_complete": False}, {"R5"}),
        ({"signed_elder_statement": False}, {"R6"}),
        ({"quorum_passed": False}, {"R7"}),
        ({"adjacent_intimated": 1}, {"R8"}),
        ({"adjacent_total": 0, "adjacent_intimated": 0}, {"R8"}),
        ({"acknowledged": False}, {"R9"}),
        ({"open_disputes": 1}, {"R10"}),
    ],
)
def test_each_check_fails_on_its_own(overrides: dict[str, object], fails: set[str]) -> None:
    assert _failing(_input(**overrides)) == fails


def test_three_general_evidences_stand_in_for_the_elder_statement() -> None:
    assert "R6" not in _failing(_input(signed_elder_statement=False, verified_general=3))


def test_non_cfr_claims_get_only_the_checks_that_apply() -> None:
    c = readiness(_input(claim_type=ClaimType.IFR))
    assert [i.id for i in c.items] == ["R1", "R5", "R6", "R7", "R9"]


def test_gps_and_satellite_are_never_substitutable() -> None:
    assert not EvidenceKind.GPS_POINT.is_substitutable
    assert not EvidenceKind.SATELLITE.is_substitutable
    assert EvidenceKind.ELDER_STATEMENT.is_substitutable


@pytest.mark.parametrize(
    ("start", "months", "expected"),
    [
        (date(2026, 1, 15), 3, date(2026, 4, 15)),
        (date(2026, 11, 30), 3, date(2027, 2, 28)),
        (date(2027, 11, 30), 3, date(2028, 2, 29)),
        (date(2026, 12, 31), 1, date(2027, 1, 31)),
    ],
)
def test_add_months(start: date, months: int, expected: date) -> None:
    assert add_months(start, months) == expected


def _evidence(created_at: datetime) -> Evidence:
    return Evidence(
        id=uuid.UUID("01900000-0000-7000-8000-000000000001"),
        case_id=uuid.UUID("01900000-0000-7000-8000-000000000002"),
        rule_ref=EvidenceRule.R13_1_A,
        kind=EvidenceKind.DOCUMENT_SCAN,
        description="7/12 extract",
        is_substitutable=True,
        added_by_user_id=uuid.UUID("01900000-0000-7000-8000-000000000003"),
        created_at=created_at,
    )


def test_canonical_payload_is_stable_and_time_zone_neutral() -> None:
    utc = datetime(2026, 10, 3, 6, 0, tzinfo=UTC)
    ist = utc.astimezone(timezone(timedelta(hours=5, minutes=30)))
    a, b = canonical_payload(_evidence(utc)), canonical_payload(_evidence(ist))
    assert a == b
    assert '"rule_ref":"13(1)(a)"' in a and " " not in a.split('"description"')[0]


def test_link_hash_chains_on_the_previous_hash() -> None:
    payload = canonical_payload(_evidence(datetime(2026, 10, 3, tzinfo=UTC)))
    first = link_hash(payload, GENESIS)
    assert len(first) == 64
    assert link_hash(payload, first) != first
    assert link_hash(payload, GENESIS) == first
