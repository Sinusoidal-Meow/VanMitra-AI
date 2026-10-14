"""
Answer a question from HIS saved report, with no language model (stage 2 of docs/to_do.md).

The order is fixed and is the contract the real AI step plugs into (PDF §11-12):
  1. safety check, in code            → harmful: red message, NO answer
  2. which part of the report?        → nothing: grey "only about your report"
  3. build the answer from the report → only facts that are in it
  4. number check                     → a number not in the report: replaced by "not in your report"

Answers are {key, params} reasons, never finished sentences, so the app writes them in his chosen
language and a saved answer re-renders when he switches language. The question text is never
copied into an answer.
"""

from collections.abc import Callable, Sequence

from ..ask_schemas import AnswerKind, AnswerOut, ChipOut
from ..schemas import (
    WATER_KINDS,
    Idea,
    IdeaOut,
    Reason,
    RemovedOut,
    ReportOut,
    ResourceKind,
    ResourceOut,
)
from . import ask_topics as topics
from .ask_numbers import unsupported_numbers
from .ask_safety import is_harmful

# the "From: ..." labels, one per part of the report
PART_SUMMARY = "summary"
PART_IDEAS = "ideas"
PART_RESOURCES = "resources"
PART_REMOVED = "removed"
PART_WEATHER = "weather"
PART_YOUR_DETAILS = "your_details"

MAX_LISTED = 5  # items shown in one answer


def _named(idea: IdeaOut | RemovedOut) -> dict[str, object]:
    return {"code": idea.code, "name_en": idea.name_en, "name_mr": idea.name_mr}


def _resource_item(r: ResourceOut) -> Reason:
    return Reason(
        key="ask.item.resource",
        params={
            "kind": r.kind.value,
            "name_en": r.name_en,
            "name_mr": r.name_mr,
            "distance_m": r.distance_m,
            "label": r.label.value,
        },
    )


def _idea_item(idea: IdeaOut) -> Reason:
    return Reason(
        key="ask.item.idea",
        params={"rank": idea.rank, **_named(idea), "fit": idea.fit.value},
    )


def _answer(
    report: ReportOut,
    topic: str,
    headline: Reason,
    items: Sequence[Reason] = (),
    parts: Sequence[str] = (),
    kind: AnswerKind = AnswerKind.ANSWER,
) -> AnswerOut:
    return AnswerOut(
        kind=kind,
        topic=topic,
        headline=headline,
        items=list(items),
        from_parts=list(parts),
        is_sample_data=report.is_sample_data,
    )


def not_in_report(report: ReportOut | None, topic: str, detail: str | None = None) -> AnswerOut:
    """Grey: "This is not in your report. Ask the agriculture officer or the Forest Department"."""
    return AnswerOut(
        kind=AnswerKind.NOT_IN_REPORT,
        topic=topic,
        headline=Reason(key="ask.not_in_report"),
        items=[Reason(key=detail)] if detail else [],
        is_sample_data=bool(report and report.is_sample_data),
    )


def refused_harmful() -> AnswerOut:
    """Red, and the only red: no answer is given and nothing from the report is used."""
    return AnswerOut(
        kind=AnswerKind.REFUSED_HARMFUL, topic="none", headline=Reason(key="ask.refused_harmful")
    )


def off_topic(report: ReportOut | None) -> AnswerOut:
    return AnswerOut(
        kind=AnswerKind.OFF_TOPIC,
        topic=topics.OFF_TOPIC,
        headline=Reason(key="ask.off_topic"),
        is_sample_data=bool(report and report.is_sample_data),
    )


# ── one builder per topic ─────────────────────────────────────────────────────


def _heading(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    a = report.analysis
    return _answer(
        report, topics.HEADING, a.headline, [*a.strengths, *a.constraints], [PART_SUMMARY]
    )


def _top_ideas(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    if not report.ideas:
        return not_in_report(report, topics.TOP_IDEAS, "ask.nir.no_ideas")
    return _answer(
        report,
        topics.TOP_IDEAS,
        Reason(key="ask.top_ideas", params={"count": len(report.ideas)}),
        [_idea_item(i) for i in report.ideas],
        [PART_IDEAS],
    )


def _water(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    a = report.analysis
    wanted = (
        "analysis.water_nearby",
        "analysis.own_water_source",
        "analysis.no_water_nearby",
        "analysis.water_is_seasonal",
    )
    facts = [r for r in (*a.strengths, *a.constraints) if r.key in wanted]
    water = [r for r in report.resources if r.kind in WATER_KINDS]
    return _answer(
        report,
        topics.WATER,
        Reason(key="ask.water.header", params={"radius_m": report.header.radius_m}),
        [*facts, *(_resource_item(r) for r in water[:MAX_LISTED])],
        [PART_RESOURCES, PART_SUMMARY],
    )


def _resources(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    c = report.counts
    return _answer(
        report,
        topics.RESOURCES,
        Reason(
            key="ask.resources.header",
            params={
                "total": c.total,
                "useful": c.useful,
                "partly_useful": c.partly_useful,
                "not_useful": c.not_useful,
                "radius_m": report.header.radius_m,
            },
        ),
        [_resource_item(r) for r in report.resources[:MAX_LISTED]],
        [PART_RESOURCES],
    )


def _wildlife(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    a = report.analysis
    near = [
        r for r in (*a.constraints, *a.next_steps) if "protected" in r.key or "forest_dept" in r.key
    ]
    risks = [
        Reason(
            key="ask.item.idea_wildlife",
            params={**_named(i), "wildlife_risk": i.wildlife_risk.value},
        )
        for i in report.ideas
    ]
    # no distance in the "none found" line: the check looks within a few km of the plot, which is
    # not the report radius, so quoting 5 km would claim more than was checked (rule L1)
    headline = Reason(key="ask.wildlife.near" if near else "ask.wildlife.none_found")
    return _answer(report, topics.WILDLIFE, headline, [*near, *risks], [PART_SUMMARY, PART_IDEAS])


def _flood(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    risk = [r for r in report.analysis.constraints if r.key == "analysis.possible_flood_risk"]
    headline = Reason(key="ask.flood.possible" if risk else "ask.flood.none_found")
    return _answer(report, topics.FLOOD, headline, risk, [PART_SUMMARY])


def _weather(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    w = report.weather
    if w is None or not w.months:
        return not_in_report(report, topics.WEATHER)
    hottest = max(w.months, key=lambda m: m.tmax_c)
    wettest = max(w.months, key=lambda m: m.rain_mm)
    driest = min(w.months, key=lambda m: m.rain_mm)
    return _answer(
        report,
        topics.WEATHER,
        Reason(key="ask.weather.header", params={"is_sample": w.is_sample}),
        [
            Reason(
                key="ask.weather.hottest", params={"month": hottest.month, "tmax_c": hottest.tmax_c}
            ),
            Reason(
                key="ask.weather.wettest",
                params={"month": wettest.month, "rain_mm": wettest.rain_mm},
            ),
            Reason(
                key="ask.weather.driest", params={"month": driest.month, "rain_mm": driest.rain_mm}
            ),
        ],
        [PART_WEATHER],
    )


def _cost(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    if not report.ideas:
        return not_in_report(report, topics.COST, "ask.nir.no_ideas")
    return _answer(
        report,
        topics.COST,
        Reason(key="ask.cost.header"),
        [
            Reason(key="ask.item.idea_cost", params={**_named(i), "cost_level": i.cost_level.value})
            for i in report.ideas
        ],
        [PART_IDEAS],
    )


def _forest(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    forest = [r for r in report.analysis.strengths if r.key == "analysis.forest_nearby"]
    shared = [r for r in report.resources if r.use_only_through_gram_sabha]
    gram_sabha_ideas = [
        Reason(key="ask.item.idea_gram_sabha", params=_named(i))
        for i in report.ideas
        if any(f.key == "flag.through_gram_sabha" for f in i.flags)
    ]
    items: list[Reason] = [*forest, *gram_sabha_ideas]
    if shared:
        items.append(Reason(key="flag.through_gram_sabha"))
    return _answer(
        report,
        topics.FOREST,
        Reason(key="ask.forest.header" if forest or shared else "ask.forest.none_found"),
        items,
        [PART_SUMMARY, PART_RESOURCES, PART_IDEAS],
    )


def _own(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    own = report.analysis.own_resources
    if not own:
        return _answer(report, topics.OWN, Reason(key="ask.own.none"), [], [PART_YOUR_DETAILS])
    return _answer(report, topics.OWN, Reason(key="ask.own.header"), own, [PART_YOUR_DETAILS])


def _removed(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    if not report.removed:
        return _answer(report, topics.REMOVED, Reason(key="ask.removed.none"), [], [PART_REMOVED])
    return _answer(
        report,
        topics.REMOVED,
        Reason(key="ask.removed.header", params={"count": len(report.removed)}),
        [
            Reason(
                key="ask.item.removed",
                params={**_named(r), "gate": r.gate.value if r.gate else None},
            )
            for r in report.removed[: MAX_LISTED * 2]
        ],
        [PART_REMOVED],
    )


def _schemes(report: ReportOut, _lib: Sequence[Idea]) -> AnswerOut:
    """Which register rows relate to his ideas. Only counts and names: we cannot say whether he
    qualifies, and we show no amounts, so there is nothing else to say."""
    related = [i for i in report.ideas if i.schemes_count > 0]
    if not related:
        return not_in_report(report, topics.SCHEMES, "ask.nir.schemes")
    return _answer(
        report,
        topics.SCHEMES,
        Reason(key="ask.schemes.header"),
        [
            Reason(
                key="ask.item.idea_schemes",
                params={**_named(i), "count": i.schemes_count},
            )
            for i in related
        ],
        [PART_IDEAS],
    )


def idea_answer(report: ReportOut, library: Sequence[Idea], code: str) -> AnswerOut:
    """ "Trying another idea": what the report already found out about it, or an honest 'not
    checked'. Nothing is invented for an idea the report did not evaluate."""
    for card in report.ideas:
        if card.code == code:
            items = [
                card.reason,
                Reason(key="ask.item.cost", params={"cost_level": card.cost_level.value}),
                Reason(key="ask.item.season", params={"season": card.best_season}),
                Reason(key="ask.item.wildlife", params={"wildlife_risk": card.wildlife_risk.value}),
                *card.flags,
            ]
            return _answer(
                report,
                topics.IDEA,
                Reason(
                    key="ask.idea.in_report",
                    params={"rank": card.rank, **_named(card), "fit": card.fit.value},
                ),
                items,
                [PART_IDEAS],
            )
    for out in report.removed:
        if out.code == code:
            if out.gate is not None:
                head = Reason(
                    key="ask.idea.removed_by_gate", params={**_named(out), "gate": out.gate.value}
                )
                return _answer(report, topics.IDEA, head, [out.reason], [PART_REMOVED])
            head = Reason(
                key="ask.idea.held_back",
                params={**_named(out), "fit": out.fit.value if out.fit else None},
            )
            return _answer(report, topics.IDEA, head, out.flags, [PART_REMOVED])
    known = next((i for i in library if i.code == code), None)
    if known is not None:
        return not_in_report(report, topics.IDEA, "ask.nir.idea_not_shown")
    return not_in_report(report, topics.IDEA_UNCHECKED, "ask.nir.idea_unchecked")


_BUILDERS: dict[str, Callable[[ReportOut, Sequence[Idea]], AnswerOut]] = {
    topics.HEADING: _heading,
    topics.TOP_IDEAS: _top_ideas,
    topics.WATER: _water,
    topics.RESOURCES: _resources,
    topics.WILDLIFE: _wildlife,
    topics.COST: _cost,
    topics.FOREST: _forest,
    topics.OWN: _own,
    topics.WEATHER: _weather,
    topics.FLOOD: _flood,
    topics.REMOVED: _removed,
    topics.SCHEMES: _schemes,
}


def _checked(answer: AnswerOut, report: ReportOut) -> AnswerOut:
    """The number check. An answer with a number that is not in the report is not shown."""
    if answer.kind is AnswerKind.ANSWER and unsupported_numbers(answer, report):
        return not_in_report(report, answer.topic)
    return answer


def answer_topic(intent: topics.Intent, report: ReportOut, library: Sequence[Idea]) -> AnswerOut:
    """Build the answer for a topic, then number-check it."""
    if intent.topic == topics.IDEA and intent.idea_code:
        built = idea_answer(report, library, intent.idea_code)
    elif intent.topic == topics.OUTSIDE:
        built = not_in_report(report, topics.OUTSIDE, "ask.nir.outside")
    elif intent.topic == topics.IDEA_UNCHECKED:
        built = not_in_report(report, topics.IDEA_UNCHECKED, "ask.nir.idea_unchecked")
    elif intent.topic in _BUILDERS:
        built = _BUILDERS[intent.topic](report, library)
    else:
        built = off_topic(report)
    return _checked(built, report)


def respond(question: str, report: ReportOut, library: Sequence[Idea]) -> AnswerOut:
    """A typed question: safety first, then the report. Never raises on odd input."""
    if is_harmful(question):
        return refused_harmful()
    intent = topics.detect(question, list(library))
    return answer_topic(intent, report, library)


# ── suggested questions ───────────────────────────────────────────────────────

CHIP_IDEA_PREFIX = "idea:"


def build_chips(report: ReportOut) -> list[ChipOut]:
    """Suggested questions made from facts in HIS report, so two people see different ones."""
    chips: list[ChipOut] = []

    def add(chip_id: str, params: dict[str, object] | None = None) -> None:
        chips.append(
            ChipOut(
                id=chip_id,
                label=Reason(key=f"ask.chip.{chip_id.split(':')[0]}", params=params or {}),
            )
        )

    add("heading")
    if report.ideas:
        add("top_ideas")
        add(f"{CHIP_IDEA_PREFIX}{report.ideas[0].code}", _named(report.ideas[0]))
    if any(r.kind in WATER_KINDS for r in report.resources):
        add("water")
    if any("protected" in r.key for r in report.analysis.constraints):
        add("wildlife")
    if report.ideas:
        add("cost")
    if any(
        r.kind is ResourceKind.FOREST_COMPARTMENT or r.use_only_through_gram_sabha
        for r in report.resources
    ):
        add("forest")
    if report.analysis.own_resources:
        add("own")
    if report.weather is not None:
        add("weather")
    if any(i.schemes_count > 0 for i in report.ideas):
        add("schemes")
    if report.removed:
        add("removed")
    return chips


def respond_chip(chip_id: str, report: ReportOut, library: Sequence[Idea]) -> AnswerOut | None:
    """A tapped suggestion: it names its topic directly, so no guessing from words. None if the
    id is not one we offer."""
    if chip_id.startswith(CHIP_IDEA_PREFIX):
        code = chip_id[len(CHIP_IDEA_PREFIX) :]
        return answer_topic(topics.Intent(topics.IDEA, code), report, library) if code else None
    if chip_id in _BUILDERS:
        return answer_topic(topics.Intent(chip_id), report, library)
    return None
