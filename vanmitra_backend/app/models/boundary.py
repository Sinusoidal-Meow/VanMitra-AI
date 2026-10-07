"""
The community forest resource on the ground (BACKEND_PLAN §3, Stage 3): versioned
boundary polygons with their segments, landmarks per segment and customary use zones
(stored inside the boundary version), the boundary walk with the elders, and disputes
where neighbours' claims overlap.

Shapes are GeoJSON in EPSG:4326 ([lon, lat]); areas and lengths are computed in UTM 43N
(EPSG:32643, see app/geo.py). The polygon is never clipped to forest or legal boundaries
[Rule 12(1)(g) Expl.].
"""

import uuid
from datetime import date, datetime
from typing import Any

from pydantic import Field

from .base import Dec4, Doc, Part, new_id, now_ms
from .enums import BoundaryStatus, DisputeOutcome, LandmarkKind, UseZoneType

GeoJSON = dict[str, Any]


class BoundarySegment(Part):
    """A stretch of the boundary between two named break points (needs ≥1 landmark, BR-08)."""

    id: uuid.UUID = Field(default_factory=new_id)
    seq: int
    geom: GeoJSON  # LineString
    length_m: float


class BoundaryLandmark(Part):
    """A landmark that fixes a segment on the ground [Rule 12(1)(g)]."""

    id: uuid.UUID = Field(default_factory=new_id)
    segment_seq: int
    name: str
    kind: LandmarkKind
    point: GeoJSON  # Point
    photo_media_id: uuid.UUID | None = None
    evidence_id: uuid.UUID | None = None
    created_at: datetime = Field(default_factory=now_ms)


class UseZone(Part):
    """An area of customary use inside the claim [Rule 13(2)(b)]."""

    id: uuid.UUID = Field(default_factory=new_id)
    use_type: UseZoneType
    name: str | None = None
    geom: GeoJSON  # Polygon
    area_ha: Dec4
    season: str | None = None
    user_hamlets: list[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=now_ms)


class CfrBoundary(Doc):
    """
    One version of the claimed boundary (version unique per case). Saving a new map
    makes a new version; the Gram Sabha-approved version is frozen and sealed.
    """

    COLLECTION = "cfr_boundary"

    case_id: uuid.UUID
    version: int
    geom: GeoJSON  # Polygon, indexed for overlap search
    # gps_walk | sketch_digitised | imported, as told by the mapper.
    source: str
    status: BoundaryStatus = BoundaryStatus.DRAFT
    area_ha: Dec4
    # {"points": n, "with_accuracy": n, "worst_m": x, "over_limit": n, "limit_m": 15}
    accuracy_stats: dict[str, Any]
    is_current: bool = True
    sealed_hash: str | None = None
    approved_on: date | None = None
    created_by_user_id: uuid.UUID
    created_at: datetime = Field(default_factory=now_ms)
    segments: list[BoundarySegment] = Field(default_factory=list)
    landmarks: list[BoundaryLandmark] = Field(default_factory=list)
    use_zones: list[UseZone] = Field(default_factory=list)


class BoundaryWalk(Doc):
    """The walk of the customary boundary with the elders: source of G9 [Rule 12(1)(f)]."""

    COLLECTION = "boundary_walk"

    case_id: uuid.UUID
    walked_on: date
    # [{"name": ..., "gs_member_id": ..., "role": "elder" | "frc" | "member" | "other"}]
    participants: list[dict[str, Any]]
    trace: GeoJSON | None = None  # LineString
    trace_length_m: float | None = None
    notes: str | None = None
    created_by_user_id: uuid.UUID
    created_at: datetime = Field(default_factory=now_ms)


class Dispute(Doc):
    """
    An overlap between this claim and a neighbouring village's claim [Rule 12(3)], one
    per pair of claims. Open until the joint meeting settles it or it is referred to the
    SDLC (BR-09).
    """

    COLLECTION = "dispute"

    case_id: uuid.UUID
    neighbour_case_id: uuid.UUID
    neighbour_gram_sabha_id: uuid.UUID
    overlap_geom: GeoJSON | None = None  # None once the claims no longer overlap
    overlap_ha: Dec4
    detected_on: date
    # G17: joint meeting of the Gram Sabhas / FRCs concerned
    joint_meeting_on: date | None = None
    joint_meeting_findings: str | None = None
    joint_meeting_media_id: uuid.UUID | None = None
    outcome: DisputeOutcome | None = None
    sdlc_referral_on: date | None = None
    sdlc_referral_ref: str | None = None
    created_at: datetime = Field(default_factory=now_ms)

    @property
    def is_open(self) -> bool:
        """Open while the claims still overlap and neither BR-09 exit is on record."""
        if self.sdlc_referral_on is not None or self.overlap_ha <= 0:
            return False
        return self.outcome is None or self.outcome is DisputeOutcome.NOT_RESOLVED
