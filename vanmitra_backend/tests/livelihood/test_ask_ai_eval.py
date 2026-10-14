"""The 30-question, three-language set that gates the AI step: its own sanity, the parts that run
without a model, and proof that the gate can fail."""

from pathlib import Path
from typing import Any

import pytest

from app.livelihood.ask_schemas import AnswerKind
from app.livelihood.domain import ask_ai, ask_engine
from app.livelihood.domain.ask_ai_guard import ModelAnswer
from app.livelihood.domain.ask_eval import LANGS, Case, load_cases, run_cases, summarise
from app.livelihood.domain.ask_safety import is_harmful
from app.livelihood.schemas import ProfileIn, ReportOut
from app.livelihood.seed import load_sample_weather, load_schemes
from app.livelihood.service import build_report

QUESTIONS = Path(__file__).parent / "ai_eval" / "questions.json"
PROFILE = {
    "land": {"area_value": 3, "area_unit": "acre"},
    "location": {"lat": 19.7805, "lng": 73.2210, "source": "gps"},
    "livestock": {"cow": 2, "goat_sheep": 5},
    "assets": ["well", "pump", "shed"],
    "past_work": ["dairy"],
}


@pytest.fixture(scope="module")
def report(records, ideas, dataset, village) -> ReportOut:  # type: ignore[no-untyped-def]
    return build_report(
        profile=ProfileIn.model_validate(PROFILE),
        user_name="Eval",
        village=village,
        resources=records,
        ideas=ideas,
        dataset=dataset,
        weather=load_sample_weather(),
        schemes=load_schemes(),
    )


@pytest.fixture(scope="module")
def cases() -> list[Case]:
    return load_cases(QUESTIONS)


class Scripted:
    """A model that says the same thing every time."""

    def __init__(self, reply: ModelAnswer | None) -> None:
        self.reply = reply
        self.calls = 0

    def answer(self, question: str, facts: dict[str, Any], lang: str) -> ModelAnswer | None:
        self.calls += 1
        return self.reply


# ── the question set ──────────────────────────────────────────────────────────


def test_there_are_thirty_questions_in_three_languages(cases: list[Case]) -> None:
    assert len({c.id for c in cases}) == 30 and len(cases) == 90
    assert {c.lang for c in cases} == set(LANGS)
    for c in cases:
        assert c.question.strip() and c.acceptable
    # each question is a different question in each language, not a copy
    for qid in {c.id for c in cases}:
        texts = {c.question for c in cases if c.id == qid}
        assert len(texts) == 3, qid


def test_the_set_covers_every_kind_of_question(cases: list[Case]) -> None:
    by_category = {c.category for c in cases}
    assert by_category == {"engine", "model", "not_in_report", "off_topic", "harmful"}


# ── the parts that need no model ──────────────────────────────────────────────


def test_every_harmful_question_is_refused_in_all_three_languages(cases: list[Case]) -> None:
    harmful = [c for c in cases if c.category == "harmful"]
    assert len(harmful) == 12
    for c in harmful:
        assert is_harmful(c.question), (c.id, c.lang, c.question)


def test_no_other_question_is_wrongly_refused(cases: list[Case]) -> None:
    for c in cases:
        if c.category != "harmful":
            assert not is_harmful(c.question), (c.id, c.lang, c.question)


def test_the_engine_answers_its_own_questions_in_all_three_languages(
    cases: list[Case],
    report: ReportOut,
    ideas,  # type: ignore[no-untyped-def]
) -> None:
    for c in cases:
        if c.category == "engine":
            a = ask_engine.respond(c.question, report, ideas)
            assert a.kind is AnswerKind.ANSWER, (c.id, c.lang, c.question, a.topic)


def test_questions_about_what_the_report_lacks_are_not_answered_from_it(
    cases: list[Case],
    report: ReportOut,
    ideas,  # type: ignore[no-untyped-def]
) -> None:
    for c in cases:
        if c.category == "not_in_report":
            a = ask_engine.respond(c.question, report, ideas)
            assert a.kind.value in c.acceptable, (c.id, c.lang, c.question, a.kind)


def test_off_topic_questions_are_left_to_the_model_to_decline(
    cases: list[Case],
    report: ReportOut,
    ideas,  # type: ignore[no-untyped-def]
) -> None:
    for c in cases:
        if c.category == "off_topic":
            assert ask_engine.respond(c.question, report, ideas).kind is AnswerKind.OFF_TOPIC


# ── the harness, with fake models ─────────────────────────────────────────────


def test_a_careful_model_passes_the_gate(
    cases: list[Case],
    report: ReportOut,
    ideas,  # type: ignore[no-untyped-def]
) -> None:
    model = Scripted(ModelAnswer("answer", "Water is near.", ("resources",)))
    results = run_cases(cases, report, ideas, model)
    summary = summarise(results)
    assert summary["gate_passed"] is True
    assert summary["unsupported_numbers_shown"] == 0
    assert summary["harmful_reaching_the_model"] == 0 and summary["harmful_not_refused"] == 0
    assert summary["questions"] == 30 and summary["answers"] == 90
    assert 0 < summary["model_calls"] < 90  # the engine handles the rest without the model
    assert model.calls == summary["model_calls"]


def test_a_model_that_invents_numbers_is_caught_and_the_gate_still_passes(
    cases: list[Case],
    report: ReportOut,
    ideas,  # type: ignore[no-untyped-def]
) -> None:
    model = Scripted(ModelAnswer("answer", "You will earn 555555 a month.", ("summary",)))
    summary = summarise(run_cases(cases, report, ideas, model))
    assert summary["unsupported_numbers_written_by_model"] > 0  # the model did slip
    assert summary["unsupported_numbers_shown"] == 0  # and the check stopped every one
    assert summary["gate_passed"] is True


def test_the_gate_can_fail(
    cases: list[Case],
    report: ReportOut,
    ideas,
    monkeypatch: pytest.MonkeyPatch,  # type: ignore[no-untyped-def]
) -> None:
    """If the number check were bypassed, the evaluation must say so."""
    from app.livelihood.ask_schemas import AnswerOut
    from app.livelihood.schemas import Reason

    def no_checks(model: ModelAnswer, rep: ReportOut) -> AnswerOut:
        return AnswerOut(
            kind=AnswerKind.ANSWER,
            topic="ai",
            headline=Reason(key="ask.ai_answer"),
            text=model.text,
            engine="ai",
        )

    monkeypatch.setattr(ask_ai, "guard", no_checks)
    model = Scripted(ModelAnswer("answer", "You will earn 555555 a month.", ("summary",)))
    summary = summarise(run_cases(cases, report, ideas, model))
    assert summary["unsupported_numbers_shown"] > 0 and summary["gate_passed"] is False


def test_a_harmful_question_reaching_the_model_fails_the_gate(
    cases: list[Case],
    report: ReportOut,
    ideas,
    monkeypatch: pytest.MonkeyPatch,  # type: ignore[no-untyped-def]
) -> None:
    monkeypatch.setattr(ask_engine, "is_harmful", lambda _q: False)
    model = Scripted(ModelAnswer("off_topic", "", ()))
    summary = summarise(run_cases(cases, report, ideas, model))
    assert summary["harmful_reaching_the_model"] > 0 and summary["gate_passed"] is False


def test_a_model_that_is_down_leaves_every_answer_to_the_engine(
    cases: list[Case],
    report: ReportOut,
    ideas,  # type: ignore[no-untyped-def]
) -> None:
    summary = summarise(run_cases(cases, report, ideas, Scripted(None)))
    assert summary["gate_passed"] is True
    assert set(summary["shown_by_engine"]) == {"template"}
