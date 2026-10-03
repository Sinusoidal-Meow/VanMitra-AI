"""Boundary versions, landmarks, use zones, the boundary walk and disputes (GeoJSON)."""

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Any, Literal

from pydantic import BaseModel, Field, StringConstraints

from ..models.enums import BoundaryStatus, DisputeOutcome, LandmarkKind, UseZoneType

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
Text = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=4000)]
Coord = Annotated[list[float], Field(min_length=2, max_length=3)]


class PolygonIn(BaseModel):
    """GeoJSON Polygon, [lon, lat] order. Rings are closed for you if needed."""

    type: Literal["Polygon"]
    coordinates: list[Annotated[list[Coord], Field(min_length=3, max_length=5000)]] = Field(
        min_length=1, max_length=50
    )


class LineStringIn(BaseModel):
    type: Literal["LineString"]
    coordinates: Annotated[list[Coord], Field(min_length=2, max_length=20000)]


class BoundaryIn(BaseModel):
    polygon: PolygonIn
    source: Literal["gps_walk", "sketch_digitised", "imported"] = "gps_walk"
    segment_breaks: list[Annotated[int, Field(ge=0)]] = Field(
        default_factory=lambda: [0],
        max_length=200,
        description="Vertex indices of the outer ring where one segment ends and the next "
        "begins. [0] makes the whole ring one segment.",
    )
    vertex_accuracy_m: list[Annotated[float, Field(ge=0)] | None] | None = Field(
        default=None, description="GPS accuracy of each outer-ring vertex, in metres"
    )


class SegmentOut(BaseModel):
    seq: int
    geometry: dict[str, Any]
    length_m: float
    landmark_count: int


class LandmarkIn(BaseModel):
    segment_seq: int = Field(ge=0)
    name: Name
    kind: LandmarkKind
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    photo_media_id: uuid.UUID | None = None
    evidence_id: uuid.UUID | None = None


class LandmarkOut(BaseModel):
    id: uuid.UUID
    segment_seq: int
    name: str
    kind: LandmarkKind
    lat: float
    lon: float
    distance_to_segment_m: float
    photo_media_id: uuid.UUID | None
    evidence_id: uuid.UUID | None


class UseZoneIn(BaseModel):
    use_type: UseZoneType
    name: Name | None = None
    polygon: PolygonIn
    season: Annotated[str, StringConstraints(strip_whitespace=True, max_length=100)] | None = None
    user_hamlets: list[Name] = Field(default_factory=list, max_length=50)


class UseZoneOut(BaseModel):
    id: uuid.UUID
    use_type: UseZoneType
    name: str | None
    geometry: dict[str, Any]
    area_ha: Decimal
    season: str | None
    user_hamlets: list[str]
    within_boundary: bool


class BoundaryOut(BaseModel):
    id: uuid.UUID
    case_id: uuid.UUID
    version: int
    status: BoundaryStatus
    source: str
    geometry: dict[str, Any]
    area_ha: Decimal
    accuracy_stats: dict[str, Any]
    sealed_hash: str | None
    approved_on: date | None
    segments: list[SegmentOut]
    landmarks: list[LandmarkOut]
    use_zones: list[UseZoneOut]
    segments_without_landmark: int
    open_disputes: int
    created_at: datetime


class BoundaryVersionOut(BaseModel):
    id: uuid.UUID
    version: int
    status: BoundaryStatus
    source: str
    area_ha: Decimal
    is_current: bool
    created_at: datetime


class Participant(BaseModel):
    name: Name
    gs_member_id: uuid.UUID | None = None
    role: Literal["elder", "frc", "member", "other"] = "elder"


class WalkIn(BaseModel):
    walked_on: date
    participants: list[Participant] = Field(min_length=1, max_length=200)
    trace: LineStringIn | None = None
    notes: Text | None = None


class WalkOut(BaseModel):
    id: uuid.UUID
    walked_on: date
    participants: list[Participant]
    trace: dict[str, Any] | None
    trace_length_m: float | None
    notes: str | None
    created_at: datetime


class DisputeOut(BaseModel):
    """An overlap with a neighbouring claim [Rule 12(3)]. `is_open` blocks BR-09."""

    id: uuid.UUID
    case_id: uuid.UUID
    neighbour_case_id: uuid.UUID
    neighbour_village: str
    overlap: dict[str, Any]
    overlap_ha: Decimal
    detected_on: date
    joint_meeting_on: date | None
    joint_meeting_findings: str | None
    joint_meeting_media_id: uuid.UUID | None
    outcome: DisputeOutcome | None
    sdlc_referral_on: date | None
    sdlc_referral_ref: str | None
    is_open: bool


class JointMeetingIn(BaseModel):
    """G17: joint meeting of the Gram Sabhas / FRCs concerned."""

    held_on: date
    findings: Text
    outcome: DisputeOutcome
    record_media_id: uuid.UUID | None = None


class SdlcReferralIn(BaseModel):
    referred_on: date
    ref: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
