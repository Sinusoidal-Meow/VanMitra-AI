"""
Written acknowledgement of every claim received [Rule 11(3)], issued when the claim is
filed with the Gram Panchayat / Gram Sabha. Serial: <village code>/<year>/<nnnn>.
"""

from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..models import ClaimCase, GramSabha, Village
from ..models.procedure import ClaimCall


def issue(db: Session, case: ClaimCase, village: Village, today: date | None = None) -> None:
    """Give the case its serial (once) and link it to the current call for claims."""
    today = today or date.today()
    if case.ack_serial is None:
        # Lock the Gram Sabha row so two filings cannot take the same number.
        db.execute(select(GramSabha.id).where(GramSabha.id == case.gram_sabha_id).with_for_update())
        code = (village.lgd_code or village.name_en[:3]).upper().replace(" ", "")
        prefix = f"{code}/{today.year}/"
        issued = db.scalar(
            select(func.count())
            .select_from(ClaimCase)
            .where(ClaimCase.gram_sabha_id == case.gram_sabha_id)
            .where(ClaimCase.ack_serial.like(f"{prefix}%"))
        )
        case.ack_serial = f"{prefix}{(issued or 0) + 1:04d}"
        case.acknowledged_on = today
    if case.claim_call_id is None:
        call = db.scalar(
            select(ClaimCall).where(
                ClaimCall.gram_sabha_id == case.gram_sabha_id, ClaimCall.is_current.is_(True)
            )
        )
        if call is not None:
            case.claim_call_id = call.id
            case.filed_within_window = call.called_on <= today <= call.closes_on
