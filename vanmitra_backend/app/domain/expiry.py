"""
A claim sent back to the villager expires when it is not resubmitted in time: the
deadline is RESUBMIT_DAYS after the day it was sent back. The claim is then closed and
marked expired, and two people are told: the villager who filed it, and the Gram Sabha
of that village. This module holds the rule and the wording; services/expiry.py does
the work in the database.
"""

from dataclasses import dataclass
from datetime import date

from ..models.enums import ClaimType
from .workflow import RESUBMIT_DAYS

FORM_EN = {ClaimType.IFR: "Form A", ClaimType.CR: "Form B", ClaimType.CFR: "Form C"}
FORM_MR = {ClaimType.IFR: "फॉर्म अ", ClaimType.CR: "फॉर्म ब", ClaimType.CFR: "फॉर्म क"}


def is_overdue(resubmit_by: date, today: date) -> bool:
    """True once the last day to resubmit has passed."""
    return today > resubmit_by


@dataclass(frozen=True)
class Message:
    title_en: str
    body_en: str
    title_mr: str
    body_mr: str


def _d(day: date) -> str:
    return day.strftime("%d-%m-%Y")


def to_villager(claim_type: ClaimType, returned_on: date) -> Message:
    """For the person who filed the claim."""
    return Message(
        title_en="Claim closed: the time to resubmit has ended",
        body_en=(
            f"Your claim ({FORM_EN[claim_type]}) was sent back to you on {_d(returned_on)}. "
            f"It was not resubmitted within {RESUBMIT_DAYS} days, so it has been closed and "
            "marked as expired. Please file a new claim."
        ),
        title_mr="दावा बंद: पुन्हा सादर करण्याची मुदत संपली",
        body_mr=(
            f"आपला दावा ({FORM_MR[claim_type]}) {_d(returned_on)} रोजी आपल्याकडे परत पाठवला "
            f"होता. तो {RESUBMIT_DAYS} दिवसांत पुन्हा सादर केला नाही, त्यामुळे तो बंद करून "
            "कालबाह्य म्हणून नोंदवला आहे. कृपया नवीन दावा दाखल करा."
        ),
    )


def to_gram_sabha(claim_type: ClaimType, claimant: str, returned_on: date) -> Message:
    """For the Gram Sabha of the claim's village."""
    return Message(
        title_en=f"Claim expired: not resubmitted in {RESUBMIT_DAYS} days",
        body_en=(
            f"The claim of {claimant} ({FORM_EN[claim_type]}) was sent back on "
            f"{_d(returned_on)}. The villager did nothing, although {RESUBMIT_DAYS} days were "
            "given to correct and resubmit it. It has been closed and marked as expired."
        ),
        title_mr=f"दावा कालबाह्य: {RESUBMIT_DAYS} दिवसांत पुन्हा सादर केला नाही",
        body_mr=(
            f"{claimant} यांचा दावा ({FORM_MR[claim_type]}) {_d(returned_on)} रोजी परत "
            f"पाठवला होता. दुरुस्त करून पुन्हा सादर करण्यासाठी {RESUBMIT_DAYS} दिवस दिले "
            "होते, तरीही ग्रामस्थाने काहीही केले नाही. दावा बंद करून कालबाह्य म्हणून "
            "नोंदवला आहे."
        ),
    )
