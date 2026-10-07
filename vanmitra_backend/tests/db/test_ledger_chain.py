"""The hash chain stays whole when two writers take turns on one Gram Sabha's chain."""

from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from app.models import Gender, GramSabha, GsMember, MemberCategory
from app.services import ledger

from .conftest import make_village


def _member(gram_sabha_id: object, name: str) -> GsMember:
    return GsMember(
        gram_sabha_id=gram_sabha_id,
        name=name,
        gender=Gender.FEMALE,
        category=MemberCategory.ST,
        active=True,
    )


def test_chain_holds_when_another_writer_appends_in_between(
    session_factory: sessionmaker[Session],
) -> None:
    with session_factory() as db:
        village = make_village(db, "LedgerVillage")
        db.commit()
        gs_id = db.scalar(select(GramSabha.id).where(GramSabha.village_id == village.id))
    assert gs_id is not None

    # the first writer keeps its session (and the Gram Sabha in it) across commits
    with session_factory() as first, session_factory() as second:
        one = _member(gs_id, "One")
        first.add(one)
        ledger.append(first, gs_id, one)
        first.commit()

        two = _member(gs_id, "Two")  # another writer moves the head on
        second.add(two)
        ledger.append(second, gs_id, two)
        second.commit()

        three = _member(gs_id, "Three")
        first.add(three)
        ledger.append(first, gs_id, three)
        first.commit()

    with session_factory() as db:
        report = ledger.verify(db, gs_id)
    assert report.ok, report
    assert report.length == 3
