"""
The facts about one person's report that may be sent to the AI model. Pure code.

PRIVACY (rules L5 and L8): the model gets facts, not the person. Never sent: his name, the
plot's coordinates or the village centre, resource and idea ids, source file names. Distances and
labels stay (they are what he asks about). If a field is not copied here it is not sent, so this
function is the whole list of what leaves the server.
"""

from typing import Any

from ..schemas import Reason, ReportOut


def _reason(r: Reason) -> dict[str, Any]:
    return {"key": r.key, "params": r.params}


def build_facts(report: ReportOut) -> dict[str, Any]:
    """The report as plain facts for the model. Reasons keep their {key, params} form: the keys
    are descriptive ("analysis.water_nearby") and the model is told to treat them as facts."""
    return {
        "data_is_sample": report.is_sample_data,
        "measured_from": report.header.report_level.value,  # plot | village
        "radius_m": report.header.radius_m,
        "resource_counts": report.counts.model_dump(),
        "resources": [
            {
                "kind": r.kind.value,
                "name_en": r.name_en,
                "name_mr": r.name_mr,
                "distance_m": r.distance_m,
                "label": r.label.value,  # useful | partly_useful | not_useful
                "why": _reason(r.reason),
                "checked_on_ground": r.checked_on_ground,
                "use_only_through_gram_sabha": r.use_only_through_gram_sabha,
            }
            for r in report.resources
        ],
        "told_by_the_person": [
            {"kind": t.kind, "code": t.code, **({"count": t.count} if t.count else {})}
            for t in report.told_by_you
        ],
        "summary": {
            "heading": _reason(report.analysis.headline),
            "helps": [_reason(r) for r in report.analysis.strengths],
            "watch_out_for": [_reason(r) for r in report.analysis.constraints],
            "owns": [_reason(r) for r in report.analysis.own_resources],
            "next_steps": [_reason(r) for r in report.analysis.next_steps],
        },
        "ideas": [
            {
                "rank": i.rank,
                "name_en": i.name_en,
                "name_mr": i.name_mr,
                "fit": i.fit.value,  # good | fair | weak
                "why": _reason(i.reason),
                "cost_level": i.cost_level.value,
                "best_season": i.best_season,
                "wildlife_risk": i.wildlife_risk.value,
                "flags": [_reason(f) for f in i.flags],
                "related_schemes": i.schemes_count,
            }
            for i in report.ideas
        ],
        "ideas_not_in_top_list": [
            {
                "name_en": r.name_en,
                "name_mr": r.name_mr,
                "removed_by_law_check": r.gate.value if r.gate else None,
                "why": _reason(r.reason),
            }
            for r in report.removed
        ],
        "typical_weather": (
            None
            if report.weather is None
            else {
                "is_sample": report.weather.is_sample,
                "months": [m.model_dump() for m in report.weather.months],
            }
        ),
    }
