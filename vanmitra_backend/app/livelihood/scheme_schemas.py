"""
Schemes and the idea detail (docs/to_do.md stage 3).

Rules for schemes (PDF §13, rule L1): we only LINK to an official page; we never take an
application, never say "you qualify", and never show an amount unless the official page does. So
there is deliberately NO field for an amount here, and unknown fields are refused.

Every scheme row says who last checked it and when. All the bundled rows are labelled SAMPLE
until a real, hand-checked register exists (docs/OPEN_QUESTIONS.md Q23).
"""

from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .schemas import FitLabel, Level, Reason, ResourceOut, WildlifeRisk

HELP_TYPES = ("farming", "fishing", "livestock", "small_business", "forest_produce")
AUDIENCES = ("women", "tribal", "farmers", "groups")


class SchemeKind(StrEnum):
    GOVERNMENT = "government"
    NGO = "ngo"


class SchemeRecord(BaseModel):
    """One row of the scheme register. Text is kept in English and Marathi (Hindi to follow)."""

    model_config = ConfigDict(extra="forbid")  # no amount field: refused if one is sent

    code: str
    kind: SchemeKind
    name_en: str
    name_mr: str
    runs_en: str  # who runs it
    runs_mr: str
    what_en: str  # what it is, in plain words
    what_mr: str
    who_en: str  # who can apply, AS THE OFFICIAL PAGE SAYS (never "you qualify")
    who_mr: str
    documents_en: list[str] = Field(default_factory=list)
    documents_mr: list[str] = Field(default_factory=list)
    help_types: list[str] = Field(default_factory=list)
    audiences: list[str] = Field(default_factory=list)
    idea_codes: list[str] = Field(default_factory=list)  # the ideas it may relate to
    official_url: str | None = None  # the official page; None if not added yet
    note_en: str = ""
    note_mr: str = ""
    last_checked_on: str = "unknown"  # ISO date, or "unknown"
    checked_by: str | None = None
    is_sample: bool = True
    status: str = "draft"  # draft | reviewed

    @field_validator("help_types")
    @classmethod
    def _help_known(cls, value: list[str]) -> list[str]:
        bad = sorted(set(value) - set(HELP_TYPES))
        if bad:
            raise ValueError(f"unknown help types: {bad}")
        return value

    @field_validator("audiences")
    @classmethod
    def _audiences_known(cls, value: list[str]) -> list[str]:
        bad = sorted(set(value) - set(AUDIENCES))
        if bad:
            raise ValueError(f"unknown audiences: {bad}")
        return value

    @field_validator("official_url")
    @classmethod
    def _https_only(cls, value: str | None) -> str | None:
        if value is not None and not value.startswith("https://"):
            raise ValueError("an official page must be an https link")
        return value


class SchemesOut(BaseModel):
    schemes: list[SchemeRecord]
    help_types: list[str]  # the filters that have at least one scheme
    audiences: list[str]
    is_sample_data: bool
    register_empty: bool  # nothing is in the register at all (not "nothing matched")


class NeedOut(BaseModel):
    """One thing an idea needs. `options` are alternatives; `met_by` is the one he has or that is
    near him, or None if there is none."""

    options: list[str]
    met_by: str | None = None


class CheckOut(BaseModel):
    """One check that ran on an idea, as a label and a reason (never a number)."""

    check: str  # law | wildlife | needs | land | community
    result: str  # passed | flagged | not_checked
    reason: Reason


class IdeaDetailOut(BaseModel):
    code: str
    name_en: str
    name_mr: str
    status: str  # in_report | held_back | removed
    rank: int | None = None
    group: str | None = None
    fit: FitLabel | None = None
    reason: Reason
    cost_level: Level
    best_season: str
    wildlife_risk: WildlifeRisk
    needs: list[NeedOut] = Field(default_factory=list)
    checks: list[CheckOut] = Field(default_factory=list)
    resources: list[ResourceOut] = Field(default_factory=list)
    flags: list[Reason] = Field(default_factory=list)
    weather_note: Reason | None = None
    schemes: list[SchemeRecord] = Field(default_factory=list)
    draft: bool = True
    is_sample_data: bool = False
