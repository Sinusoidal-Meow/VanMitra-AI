"""Cases, workflow actions, history and the title draft."""

import uuid
from datetime import date, datetime
from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

from ..models.enums import CaseState, ClaimType, Role, WorkflowAction

Remarks = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=4000)]


class CaseCreate(BaseModel):
    claim_type: ClaimType = Field(description="ifr → Form A, cr → Form B, cfr → Form C")


class ReturnedOut(BaseModel):
    """Why the claim was sent back, and how long the villager has to resubmit it."""

    by_role: Role
    by_name: str
    remarks: str
    returned_on: date
    resubmit_by: date
    days_left: int


class CaseOut(BaseModel):
    id: uuid.UUID
    claim_type: ClaimType
    form: str = Field(description="'A', 'B' or 'C'")
    state: CaseState
    village_id: uuid.UUID
    village_name_en: str
    village_name_mr: str
    taluka: str
    district: str
    claimant_label: str = Field(description="Claimant name(s) from the form, for lists")
    created_by_user_id: uuid.UUID
    is_mine: bool
    allowed_actions: list[WorkflowAction] = Field(description="What the caller may do now")
    returned: ReturnedOut | None = Field(
        default=None, description="Set when the claim was sent back to the villager"
    )
    created_at: datetime
    updated_at: datetime


class ActionIn(BaseModel):
    remarks: Remarks | None = Field(
        default=None, description="Required for return and reject (reasons for rejection)"
    )


class EventOut(BaseModel):
    action: WorkflowAction
    from_state: CaseState
    to_state: CaseState
    actor_name: str
    actor_role: Role
    remarks: str | None
    at: datetime


class SignatoryOut(BaseModel):
    designation: str
    role: Role | None
    name: str | None
    signed_at: datetime | None


class TitleDraftOut(BaseModel):
    """
    Draft of the title for the claim: Annexure II (Form A), III (Form B) or IV (Form C)
    [Rule 8(h), 8(i)]. A draft for printing and signature; the signed paper is the title.
    """

    case_id: uuid.UUID
    annexure: str
    title: str
    status: str = Field(description="'issued' once the district committee has signed")
    fields: dict[str, object] = Field(description="Title fields, in the order printed")
    declaration: str
    signatories: list[SignatoryOut]
    note: str
