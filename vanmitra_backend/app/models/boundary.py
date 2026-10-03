"""
The community forest resource on the ground (BACKEND_PLAN §3, Stage 3): versioned
boundary polygons with their segments, landmarks per segment, customary use zones,
the boundary walk with the elders, and disputes where neighbours' claims overlap.

Geometry is stored in EPSG:4326; areas are computed in UTM 43N (EPSG:32643). The
polygon is never clipped to forest or legal boundaries [Rule 12(1)(g) Expl.].
"""

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Any

from geoalchemy2 import Geometry, WKBElement, WKTElement
from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, IdMixin
from .enums import BoundaryStatus, DisputeOutcome, LandmarkKind, UseZoneType
from .people import pg_enum

SRID = 4326
AREA_SRID = 32643  # UTM zone 43N (Palghar)

# Read back from the database as WKB; written by the app as WKT.
Shape = WKBElement | WKTElement


def geom(kind: str) -> Geometry:
    # Spatial indexes are declared explicitly in __table_args__ so migrations match.
    return Geometry(geometry_type=kind, srid=SRID, spatial_index=False)


class CfrBoundary(IdMixin, Base):
    """
    One version of the claimed boundary. Saving a new map makes a new version; the
    Gram Sabha-approved version is frozen and sealed (hash of its geometry).
    """

    __tablename__ = "cfr_boundary"
    __table_args__ = (
        UniqueConstraint("case_id", "version", name="uq_cfr_boundary_version"),
        Index("ix_cfr_boundary_geom", "geom", postgresql_using="gist"),
    )

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    version: Mapped[int] = mapped_column(Integer)
    geom: Mapped[Shape] = mapped_column(geom("POLYGON"))
    # gps_walk | sketch_digitised | imported, as told by the mapper.
    source: Mapped[str] = mapped_column(String(50))
    status: Mapped[BoundaryStatus] = mapped_column(
        pg_enum(BoundaryStatus, "boundary_status"), default=BoundaryStatus.DRAFT
    )
    area_ha: Mapped[Decimal] = mapped_column(Numeric(12, 4))
    # {"points": n, "with_accuracy": n, "worst_m": x, "over_limit": n, "limit_m": 15}
    accuracy_stats: Mapped[dict[str, Any]] = mapped_column(JSONB)
    is_current: Mapped[bool] = mapped_column(Boolean, default=True)
    sealed_hash: Mapped[str | None] = mapped_column(String(64))
    approved_on: Mapped[date | None] = mapped_column(Date)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    segments: Mapped[list["BoundarySegment"]] = relationship(
        cascade="all, delete-orphan", order_by="BoundarySegment.seq"
    )
    landmarks: Mapped[list["BoundaryLandmark"]] = relationship(
        cascade="all, delete-orphan", order_by="BoundaryLandmark.created_at"
    )
    use_zones: Mapped[list["UseZone"]] = relationship(
        cascade="all, delete-orphan", order_by="UseZone.created_at"
    )


class BoundarySegment(IdMixin, Base):
    """A stretch of the boundary between two named break points (needs ≥1 landmark, BR-08)."""

    __tablename__ = "boundary_segment"
    __table_args__ = (UniqueConstraint("boundary_id", "seq", name="uq_boundary_segment_seq"),)

    boundary_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("cfr_boundary.id"), index=True)
    seq: Mapped[int] = mapped_column(Integer)
    geom: Mapped[Shape] = mapped_column(geom("LINESTRING"))
    length_m: Mapped[float] = mapped_column(Float)


class BoundaryLandmark(IdMixin, Base):
    """A landmark that fixes a segment on the ground [Rule 12(1)(g)]."""

    __tablename__ = "boundary_landmark"

    boundary_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("cfr_boundary.id"), index=True)
    segment_seq: Mapped[int] = mapped_column(Integer)
    name: Mapped[str] = mapped_column(String(200))
    kind: Mapped[LandmarkKind] = mapped_column(pg_enum(LandmarkKind, "landmark_kind"))
    point: Mapped[Shape] = mapped_column(geom("POINT"))
    photo_media_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("media.id"))
    evidence_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("evidence.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class UseZone(IdMixin, Base):
    """An area of customary use inside the claim [Rule 13(2)(b)]."""

    __tablename__ = "use_zone"

    boundary_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("cfr_boundary.id"), index=True)
    use_type: Mapped[UseZoneType] = mapped_column(pg_enum(UseZoneType, "use_zone_type"))
    name: Mapped[str | None] = mapped_column(String(200))
    geom: Mapped[Shape] = mapped_column(geom("POLYGON"))
    area_ha: Mapped[Decimal] = mapped_column(Numeric(12, 4))
    season: Mapped[str | None] = mapped_column(String(100))
    user_hamlets: Mapped[list[str]] = mapped_column(ARRAY(String(200)), server_default=text("'{}'"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class BoundaryWalk(IdMixin, Base):
    """The walk of the customary boundary with the elders: source of G9 [Rule 12(1)(f)]."""

    __tablename__ = "boundary_walk"

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    walked_on: Mapped[date] = mapped_column(Date)
    # [{"name": ..., "gs_member_id": ..., "role": "elder" | "frc" | "member" | "other"}]
    participants: Mapped[list[dict[str, Any]]] = mapped_column(JSONB)
    trace: Mapped[Shape | None] = mapped_column(geom("LINESTRING"))
    notes: Mapped[str | None] = mapped_column(Text)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("app_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Dispute(IdMixin, Base):
    """
    An overlap between this claim and a neighbouring village's claim [Rule 12(3)].
    Open until the joint meeting settles it or it is referred to the SDLC (BR-09).
    """

    __tablename__ = "dispute"
    __table_args__ = (
        UniqueConstraint("case_id", "neighbour_case_id", name="uq_dispute_pair"),
        Index("ix_dispute_overlap_geom", "overlap_geom", postgresql_using="gist"),
    )

    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    neighbour_case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("claim_case.id"), index=True)
    neighbour_gram_sabha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("gram_sabha.id"))
    overlap_geom: Mapped[Shape] = mapped_column(geom("GEOMETRY"))
    overlap_ha: Mapped[Decimal] = mapped_column(Numeric(12, 4))
    detected_on: Mapped[date] = mapped_column(Date)
    # G17: joint meeting of the Gram Sabhas / FRCs concerned
    joint_meeting_on: Mapped[date | None] = mapped_column(Date)
    joint_meeting_findings: Mapped[str | None] = mapped_column(Text)
    joint_meeting_media_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("media.id"))
    outcome: Mapped[DisputeOutcome | None] = mapped_column(
        pg_enum(DisputeOutcome, "dispute_outcome")
    )
    sdlc_referral_on: Mapped[date | None] = mapped_column(Date)
    sdlc_referral_ref: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    @property
    def is_open(self) -> bool:
        """Open while the claims still overlap and neither BR-09 exit is on record."""
        if self.sdlc_referral_on is not None or self.overlap_ha <= 0:
            return False
        return self.outcome is None or self.outcome is DisputeOutcome.NOT_RESOLVED
