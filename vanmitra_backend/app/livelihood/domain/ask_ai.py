"""
Where the language model plugs in (docs/to_do.md, the AI agent). The order is fixed:

  1. the safety check on the question, in code, BEFORE any model is called (ask_engine.respond);
  2. the deterministic engine answers whatever it understands, exactly, with no model;
  3. only a question the engine could not place (it would be a grey "only about your report") is
     offered to the model, with the facts of HIS report and nothing else;
  4. whatever the model says goes through `guard`: the number check, the safety check, no
     "you qualify", no links. A failed check becomes the grey "not in your report".

If the model cannot be reached, refuses, or is over its limit, the person simply gets step 2's
answer: the AI step can only add an answer, never remove a safety.
"""

from collections.abc import Callable, Sequence
from typing import Any, Protocol

from ..ask_schemas import AnswerKind, AnswerOut
from ..schemas import Idea, ReportOut
from . import ask_engine
from .ask_ai_guard import ModelAnswer, guard
from .ask_facts import build_facts
from .ask_text import mask_long_digits


class Answerer(Protocol):
    def answer(self, question: str, facts: dict[str, Any], lang: str) -> ModelAnswer | None:
        """The model's reply to one question about one report, or None if there is none."""
        ...


def respond_with_ai(
    question: str,
    report: ReportOut,
    library: Sequence[Idea],
    answerer: Answerer,
    lang: str,
    permit: Callable[[], bool] | None = None,
) -> AnswerOut:
    """A typed question: safety first, the engine second, the model only for what is left."""
    base = ask_engine.respond(question, report, library)
    if base.kind is not AnswerKind.OFF_TOPIC:
        return base  # harmful, answered, or "not in your report": no model involved
    # the cost cap is checked, and counted, only now that the model is really about to be called
    if permit is not None and not permit():
        return base
    # the typed words reach the model, so long digit runs (a phone or ID number) are hidden first
    reply = answerer.answer(mask_long_digits(question), build_facts(report), lang)
    if reply is None:
        return base
    # marked "ai" even when the guard replaces the words, because the call cost money (the daily
    # limit counts these)
    return guard(reply, report).model_copy(update={"engine": "ai"})
