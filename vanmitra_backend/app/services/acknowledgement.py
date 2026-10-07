"""
Written acknowledgement of every claim received [Rule 11(3)], issued when the claim is
filed with the Gram Panchayat / Gram Sabha. Serial: <village code>/<year>/<nnnn>.
"""

from datetime import date

from ..db import Store
from ..models import ClaimCase, Village
from ..models.procedure import ClaimCall


def issue(db: Store, case: ClaimCase, village: Village, today: date | None = None) -> None:
    """Give the case its serial (once) and link it to the current call for claims."""
    today = today or date.today()
    if case.ack_serial is None:
        code = (village.lgd_code or village.name_en[:3]).upper().replace(" ", "")
        prefix = f"{code}/{today.year}/"
        # A counter per Gram Sabha register and year, taken inside the transaction: two
        # filings at once cannot get the same number, and a rolled-back one uses none.
        number = db.next_number(f"ack/{case.gram_sabha_id}/{today.year}")
        case.ack_serial = f"{prefix}{number:04d}"
        case.acknowledged_on = today
    if case.claim_call_id is None:
        call = db.find_one(ClaimCall, {"gram_sabha_id": case.gram_sabha_id, "is_current": True})
        if call is not None:
            case.claim_call_id = call.id
            case.filed_within_window = call.called_on <= today <= call.closes_on
