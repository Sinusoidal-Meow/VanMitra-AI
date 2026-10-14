from app.livelihood.domain.gates import failed_gate
from app.livelihood.domain.wildlife import wildlife_risk
from app.livelihood.schemas import Gate, Idea, WildlifeRisk


def _idea(**kw: object) -> Idea:
    base: dict[str, object] = {"code": "x", "name_en": "x", "name_mr": "x", "family": "f"}
    base.update(kw)
    return Idea.model_validate(base)


def test_shown_ideas_pass_every_gate(ideas: list[Idea]) -> None:
    for idea in ideas:
        if idea.family != "gate_demo":
            assert failed_gate(idea, plot_in_cfr=True) is None, idea.code


def test_each_gate_fires() -> None:
    assert (
        failed_gate(_idea(gate_flags={"needs_sale_or_lease": True}), plot_in_cfr=False)
        is Gate.LAND_SALE_OR_LEASE
    )
    assert (
        failed_gate(_idea(gate_flags={"hunting_trapping": True}), plot_in_cfr=False)
        is Gate.HUNTING_OR_TRAPPING
    )
    assert (
        failed_gate(_idea(gate_flags={"timber_or_harm": True}), plot_in_cfr=False)
        is Gate.TIMBER_OR_HARM
    )


def test_not_in_cfr_gate_only_applies_inside_cfr() -> None:
    idea = _idea(gate_flags={"not_in_cfr": True})
    assert failed_gate(idea, plot_in_cfr=False) is None
    assert failed_gate(idea, plot_in_cfr=True) is Gate.NOT_ALLOWED_IN_CFR


def test_gate_order_is_stable() -> None:
    idea = _idea(gate_flags={"timber_or_harm": True, "needs_sale_or_lease": True})
    assert failed_gate(idea, plot_in_cfr=False) is Gate.LAND_SALE_OR_LEASE


def test_forest_ideas_need_permission_near_protected_area() -> None:
    forest = _idea(touches_forest=True, wildlife_risk="medium")
    farm = _idea(wildlife_risk="low")
    assert wildlife_risk(forest, protected_near=True) is WildlifeRisk.NEEDS_PERMISSION
    assert wildlife_risk(forest, protected_near=False) is WildlifeRisk.MEDIUM
    assert wildlife_risk(farm, protected_near=True) is WildlifeRisk.MEDIUM
    assert wildlife_risk(farm, protected_near=False) is WildlifeRisk.LOW
