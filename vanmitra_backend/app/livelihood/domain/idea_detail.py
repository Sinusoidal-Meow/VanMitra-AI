"""
One idea in detail, made from his saved report and the idea library (docs/to_do.md stage 3).

Nothing new is decided here: it lays out what the report already found (why it was suggested, what
it needs and whether that is near or his own, the checks that ran, the resources it would use) and
adds the weather note and the schemes that may relate. Pure code: no database, no HTTP.
"""

from collections.abc import Sequence

from ..schemas import Idea, Reason, ReportOut, WildlifeRisk
from ..scheme_schemas import CheckOut, IdeaDetailOut, NeedOut, SchemeRecord

_LAND_FLAGS = ("flag.needs_more_land", "flag.land_unknown")


def matching_schemes(idea_code: str, schemes: Sequence[SchemeRecord]) -> list[SchemeRecord]:
    """The register rows that name this idea (a link to read, never "you qualify")."""
    return sorted((s for s in schemes if idea_code in s.idea_codes), key=lambda s: s.code)


def scheme_counts(schemes: Sequence[SchemeRecord]) -> dict[str, int]:
    """How many register rows relate to each idea code."""
    counts: dict[str, int] = {}
    for s in schemes:
        for code in set(s.idea_codes):
            counts[code] = counts.get(code, 0) + 1
    return counts


def _needs(idea: Idea, report: ReportOut) -> list[NeedOut]:
    kinds = {r.kind.value for r in report.resources}
    own = {f"asset:{t.code}" for t in report.told_by_you if t.kind == "asset"}
    out: list[NeedOut] = []
    for group in idea.needs:
        met = next((o for o in group if o in own or o in kinds), None)
        out.append(NeedOut(options=list(group), met_by=met))
    return out


def _weather_note(idea: Idea, report: ReportOut, flags: Sequence[Reason]) -> Reason | None:
    if any(f.key == "flag.possible_flood_risk" for f in flags):
        return Reason(key="detail.weather.flood_risk")
    w = report.weather
    if w is None or not w.months:
        return None
    hottest = max(w.months, key=lambda m: m.tmax_c)
    if "water_hungry" in idea.tags or "heat_sensitive" in idea.tags:
        return Reason(
            key="detail.weather.heat",
            params={"month": hottest.month, "tmax_c": hottest.tmax_c, "is_sample": w.is_sample},
        )
    return Reason(key="detail.weather.typical", params={"is_sample": w.is_sample})


def _checks(
    idea: Idea,
    report: ReportOut,
    needs: Sequence[NeedOut],
    flags: Sequence[Reason],
    wildlife: WildlifeRisk,
    gate_reason: Reason | None,
) -> list[CheckOut]:
    checks: list[CheckOut] = []
    # 1. the four legal gates run first
    if gate_reason is not None:
        checks.append(CheckOut(check="law", result="flagged", reason=gate_reason))
        return checks  # nothing after a failed gate is worth showing
    checks.append(CheckOut(check="law", result="passed", reason=Reason(key="detail.check.law")))
    # 2. wildlife: a label, with "ask the Forest Department" kept as the wording
    checks.append(
        CheckOut(
            check="wildlife",
            result="passed" if wildlife is WildlifeRisk.LOW else "flagged",
            reason=Reason(key=f"detail.check.wildlife_{wildlife.value}"),
        )
    )
    # 3. what it needs
    if needs:
        missing = [n for n in needs if n.met_by is None]
        checks.append(
            CheckOut(
                check="needs",
                result="flagged" if missing else "passed",
                reason=Reason(
                    key="detail.check.needs_missing" if missing else "detail.check.needs_met"
                ),
            )
        )
    # 4. enough land, if the idea has a minimum
    if idea.min_land_ha:
        land = next((f for f in flags if f.key in _LAND_FLAGS), None)
        if land is None:
            checks.append(
                CheckOut(check="land", result="passed", reason=Reason(key="detail.check.land_ok"))
            )
        else:
            result = "not_checked" if land.key == "flag.land_unknown" else "flagged"
            checks.append(CheckOut(check="land", result=result, reason=land))
    # 5. community forest
    if idea.through_gram_sabha or any(f.key == "flag.through_gram_sabha" for f in flags):
        checks.append(
            CheckOut(
                check="community",
                result="flagged",
                reason=Reason(key="flag.through_gram_sabha"),
            )
        )
    return checks


def build_idea_detail(
    report: ReportOut,
    idea: Idea,
    schemes: Sequence[SchemeRecord],
) -> IdeaDetailOut | None:
    """The detail for one idea code, or None if this report has nothing about it."""
    card = next((c for c in report.ideas if c.code == idea.code), None)
    removed = next((r for r in report.removed if r.code == idea.code), None)
    if card is None and removed is None:
        return None

    needs = _needs(idea, report)
    matched = matching_schemes(idea.code, schemes)
    by_id = {r.id: r for r in report.resources}
    sample = report.is_sample_data or any(s.is_sample for s in matched)

    if card is not None:
        wildlife = card.wildlife_risk
        flags = list(card.flags)
        return IdeaDetailOut(
            code=idea.code,
            name_en=card.name_en,
            name_mr=card.name_mr,
            status="in_report",
            rank=card.rank,
            group=card.group.value,
            fit=card.fit,
            reason=card.reason,
            cost_level=card.cost_level,
            best_season=card.best_season,
            wildlife_risk=wildlife,
            needs=needs,
            checks=_checks(idea, report, needs, flags, wildlife, None),
            resources=[by_id[i] for i in card.resources_used if i in by_id],
            flags=flags,
            weather_note=_weather_note(idea, report, flags),
            schemes=matched,
            draft=card.draft,
            is_sample_data=sample,
        )

    assert removed is not None
    flags = list(removed.flags)
    return IdeaDetailOut(
        code=idea.code,
        name_en=removed.name_en,
        name_mr=removed.name_mr,
        status="removed" if removed.gate is not None else "held_back",
        fit=removed.fit,
        reason=removed.reason,
        cost_level=idea.cost_level,
        best_season=idea.best_season,
        wildlife_risk=idea.wildlife_risk,
        needs=[] if removed.gate is not None else needs,
        checks=_checks(
            idea, report, needs, flags, idea.wildlife_risk, removed.reason if removed.gate else None
        ),
        flags=flags,
        # a removed idea shows no schemes: pointing a farmer to help for something he may not do
        # would read as encouragement
        schemes=[] if removed.gate is not None else matched,
        draft=idea.status != "reviewed",
        is_sample_data=sample,
    )
