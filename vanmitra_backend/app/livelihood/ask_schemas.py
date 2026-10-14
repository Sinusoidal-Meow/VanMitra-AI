"""
Shapes of the Ask box (PDF §11). Like the report, an answer travels as {key, params} reasons, so
the app writes it in the language he chose and an answer saved earlier is re-written when he
switches language. Nothing here carries a numeric score (rule L5).
"""

from datetime import UTC, datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, model_validator

from .schemas import Reason

MAX_QUESTION_CHARS = 500


class AnswerKind(StrEnum):
    ANSWER = "ANSWER"  # answered from his own report
    REFUSED_HARMFUL = "REFUSED_HARMFUL"  # the only RED message; no answer is given
    OFF_TOPIC = "OFF_TOPIC"  # grey: "I can only answer questions about your report"
    NOT_IN_REPORT = "NOT_IN_REPORT"  # grey: "ask the agriculture officer or the Forest Department"


class Lang(StrEnum):
    EN = "en"
    MR = "mr"
    HI = "hi"


class AskRequest(BaseModel):
    """One question: typed text, or the id of a suggested question (a chip). Exactly one."""

    model_config = ConfigDict(extra="forbid")

    question: str | None = Field(default=None, max_length=MAX_QUESTION_CHARS)
    chip: str | None = Field(default=None, max_length=60, pattern=r"^[a-z0-9_:]+$")
    lang: Lang = Lang.EN
    # He has said the AI assistant may see the facts of his report (never his name or plot). The
    # server uses the AI only when this is true AND the AI step is switched on there.
    ai_consent: bool = False

    @model_validator(mode="after")
    def _exactly_one(self) -> "AskRequest":
        if self.question is not None:
            self.question = self.question.strip()
        if bool(self.question) == bool(self.chip):
            raise ValueError("send either a question or a chip, not both and not neither")
        return self


class AnswerOut(BaseModel):
    kind: AnswerKind
    topic: str  # which part of the report this is about, e.g. "top_ideas"; "none" if refused
    headline: Reason
    items: list[Reason] = Field(default_factory=list)
    from_parts: list[str] = Field(default_factory=list)  # "From: ..." (summary, ideas, ...)
    engine: str = "template"  # "template" now; "ai" when the language model writes the words
    text: str | None = None  # free text, only ever set by the AI step, and only if number-checked
    is_sample_data: bool = False


class ChatTurn(BaseModel):
    id: str
    at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    question: str | None = None  # what he typed (None for a chip)
    chip: str | None = None
    lang: Lang = Lang.EN
    report_id: str | None = None  # the report this was answered from
    answer: AnswerOut


class ChipOut(BaseModel):
    """A suggested question, built from facts in HIS report (different for each person)."""

    id: str
    label: Reason


class AskOut(BaseModel):
    turn: ChatTurn
    chips: list[ChipOut]


class AskHistoryOut(BaseModel):
    turns: list[ChatTurn]
    chips: list[ChipOut]
    has_report: bool
    ai_available: bool = False  # the AI step is on, so the app may ask for his permission
