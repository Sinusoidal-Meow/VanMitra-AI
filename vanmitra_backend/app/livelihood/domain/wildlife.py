"""
Wildlife-risk badge on every idea (rule L4). The wording is "check with the Forest Department",
never "safe": the map layers are incomplete (PDF §12).

Proposed rule (to be reviewed by the Forest Department and an animal-welfare NGO):
- near a protected area, EVERY idea shows "Ask the Forest Department first" (PDF §9, §12);
- an idea that brings people into the forest becomes `needs_permission` there;
- otherwise the idea keeps the risk written in the idea library.
"""

from ..schemas import Idea, WildlifeRisk


def wildlife_risk(idea: Idea, *, protected_near: bool) -> WildlifeRisk:
    if protected_near and idea.touches_forest:
        return WildlifeRisk.NEEDS_PERMISSION
    if protected_near and idea.wildlife_risk is WildlifeRisk.LOW:
        return WildlifeRisk.MEDIUM  # never show "low" next to "Ask the Forest Department first"
    return idea.wildlife_risk
