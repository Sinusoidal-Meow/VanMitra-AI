"""
The checks that run AROUND the language model, in plain code, on everything it says. The model
cannot switch any of them off: they run after it and decide what the person sees.

  - the model may only say "answer", "off_topic" or "not_in_report" (anything else is dropped);
  - an answer must not carry a number that is not in the report (the number check);
  - an answer must not hold a harmful request or instruction (the safety check, again);
  - an answer must not say he qualifies, must not link anywhere, and must be of a sane length;
  - anything that fails becomes the grey "This is not in your report", never the model's words.

The safety check on the QUESTION runs before the model is ever called (ask_engine.respond).
"""

import re
from dataclasses import dataclass

from ..ask_schemas import AnswerKind, AnswerOut
from ..schemas import Reason, ReportOut
from . import ask_engine
from .ask_numbers import unsupported_numbers
from .ask_safety import is_harmful
from .ask_text import has_any, normalise

MAX_TEXT_CHARS = 700
VALID_PARTS = (
    ask_engine.PART_SUMMARY,
    ask_engine.PART_IDEAS,
    ask_engine.PART_RESOURCES,
    ask_engine.PART_REMOVED,
    ask_engine.PART_WEATHER,
    ask_engine.PART_YOUR_DETAILS,
)

# any link, address or handle: a scheme "site", a short link, a UPI id, a chat handle
_URL = re.compile(r"://|www\.|@|\b[a-z0-9-]+\.[a-z]{2,}(?:/|\b)", re.IGNORECASE)

# We never say he qualifies, is eligible, or will get money (rule L1, PDF §13). Checked on the
# normalised text, so curly apostrophes, extra spaces and zero-width characters do not hide it.
# Any use of these words is refused, even a negated one: the grey note is the safe outcome.
_ELIGIBILITY = re.compile(
    r"qualif|eligib|entitle"
    r"|\byou(?:'ll| will| can| could| may| might)? (?:be able to )?(?:get|receive|claim)\b"
    r"|\byou(?:'re| are) (?:given|granted|approved)\b"
)
_ELIGIBILITY_MR_HI = (
    "पात्र", "मिळेल", "मिळतील", "मिळू शकत", "मिलेगा", "मिलेंगे", "मिल सक", "हक्कदार", "हकदार",
)  # fmt: skip

# money, percentages, and numbers written as words (digits are number-checked; words cannot be).
# "one" is left out: it is an ordinary word ("one of the ideas").
_MONEY = re.compile(
    r"₹|\brs\b|rupee|\bpercent|%|\blakh|\bcrore|\bmillion|\bthousand|\bhundred|\bdozen"
    r"|रुपय|\bरु\b|टक्के|प्रतिशत|लाख|करोड|हजार|हज़ार|शंभर|\bसौ\b"
)
_NUMBER_WORDS = re.compile(
    r"\b(?:zero|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen"
    r"|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy"
    r"|eighty|ninety|half|double|triple)\b"
)
_NUMBER_WORDS_MR_HI = (
    "=दोन", "=दो", "=तीन", "=चार", "=पाच", "=पांच", "=पाँच", "=सहा", "=छह", "=छः", "=सात", "=आठ",
    "=नऊ", "=नौ", "=दहा", "=दस", "=वीस", "=बीस", "=तीस", "=चाळीस", "=पन्नास", "=साठ",
)  # fmt: skip


def _breaks_a_rule(text: str) -> bool:
    norm = normalise(text).replace("\u2019", "'").replace("\u2018", "'")
    if _URL.search(norm) or _ELIGIBILITY.search(norm) or _MONEY.search(norm):
        return True
    if _NUMBER_WORDS.search(norm) or any(w in norm for w in _ELIGIBILITY_MR_HI):
        return True
    return has_any(norm, _NUMBER_WORDS_MR_HI)


@dataclass(frozen=True)
class ModelAnswer:
    """What the model returned, before any check."""

    kind: str  # answer | off_topic | not_in_report
    text: str
    parts: tuple[str, ...]


def _not_in_report(report: ReportOut) -> AnswerOut:
    return ask_engine.not_in_report(report, "ai")


def guard(model: ModelAnswer, report: ReportOut) -> AnswerOut:
    """Turn the model's reply into what the person may see."""
    if model.kind == "off_topic":
        return ask_engine.off_topic(report)
    if model.kind != "answer":
        return _not_in_report(report)

    text = model.text.strip()
    if not text or len(text) > MAX_TEXT_CHARS:
        return _not_in_report(report)
    if _breaks_a_rule(text):
        return _not_in_report(report)
    if is_harmful(text):
        return _not_in_report(report)

    parts = [p for p in dict.fromkeys(model.parts) if p in VALID_PARTS]
    answer = AnswerOut(
        kind=AnswerKind.ANSWER,
        topic="ai",
        headline=Reason(key="ask.ai_answer"),
        from_parts=parts or [ask_engine.PART_SUMMARY],
        engine="ai",
        text=text,
        is_sample_data=report.is_sample_data,
    )
    if unsupported_numbers(answer, report, strict=True):
        return _not_in_report(report)
    return answer
