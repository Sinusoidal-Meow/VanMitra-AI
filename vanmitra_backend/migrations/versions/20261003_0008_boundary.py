"""CFR boundary versions, segments, landmarks, use zones, boundary walks, disputes (Stage 3).

Revision ID: 0008
Revises: 0007
Create Date: 2026-10-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from geoalchemy2 import Geometry
from sqlalchemy.dialects import postgresql

revision: str = "0008"
down_revision: str | None = "0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

boundary_status = postgresql.ENUM(
    "draft", "gs_approved", "titled", name="boundary_status", create_type=False
)
use_zone_type = postgresql.ENUM(
    "grazing", "mfp", "water", "fishing", "fuelwood", "sacred", "shifting_cultivation",
    "habitat", "other",
    name="use_zone_type", create_type=False,
)  # fmt: skip
dispute_outcome = postgresql.ENUM(
    "agreed_shared", "agreed_adjusted", "not_resolved", name="dispute_outcome", create_type=False
)
landmark_kind = postgresql.ENUM(name="landmark_kind", create_type=False)

ENUMS = (boundary_status, use_zone_type, dispute_outcome)


def _geom(kind: str) -> Geometry:
    return Geometry(geometry_type=kind, srid=4326, spatial_index=False)


def _fk(table: str, col: str, ref: str) -> sa.ForeignKey:
    return sa.ForeignKey(f"{ref}.id", name=f"fk_{table}_{col}_{ref}")


def _created_at() -> sa.Column[object]:
    return sa.Column(
        "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
    )


def upgrade() -> None:
    bind = op.get_bind()
    for enum in ENUMS:
        enum.create(bind, checkfirst=False)

    op.create_table(
        "cfr_boundary",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("case_id", sa.Uuid(), _fk("cfr_boundary", "case_id", "claim_case"),
                  nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("geom", _geom("POLYGON"), nullable=False),
        sa.Column("source", sa.String(50), nullable=False),
        sa.Column("status", boundary_status, nullable=False),
        sa.Column("area_ha", sa.Numeric(12, 4), nullable=False),
        sa.Column("accuracy_stats", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("is_current", sa.Boolean(), nullable=False),
        sa.Column("sealed_hash", sa.String(64), nullable=True),
        sa.Column("approved_on", sa.Date(), nullable=True),
        sa.Column("created_by_user_id", sa.Uuid(),
                  _fk("cfr_boundary", "created_by_user_id", "app_user"), nullable=False),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_cfr_boundary"),
        sa.UniqueConstraint("case_id", "version", name="uq_cfr_boundary_version"),
    )  # fmt: skip
    op.create_index("ix_cfr_boundary_case_id", "cfr_boundary", ["case_id"])
    op.create_index("ix_cfr_boundary_geom", "cfr_boundary", ["geom"], postgresql_using="gist")

    op.create_table(
        "boundary_segment",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("boundary_id", sa.Uuid(),
                  _fk("boundary_segment", "boundary_id", "cfr_boundary"), nullable=False),
        sa.Column("seq", sa.Integer(), nullable=False),
        sa.Column("geom", _geom("LINESTRING"), nullable=False),
        sa.Column("length_m", sa.Float(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_boundary_segment"),
        sa.UniqueConstraint("boundary_id", "seq", name="uq_boundary_segment_seq"),
    )  # fmt: skip
    op.create_index("ix_boundary_segment_boundary_id", "boundary_segment", ["boundary_id"])

    op.create_table(
        "boundary_landmark",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("boundary_id", sa.Uuid(),
                  _fk("boundary_landmark", "boundary_id", "cfr_boundary"), nullable=False),
        sa.Column("segment_seq", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("kind", landmark_kind, nullable=False),
        sa.Column("point", _geom("POINT"), nullable=False),
        sa.Column("photo_media_id", sa.Uuid(), _fk("boundary_landmark", "photo_media_id", "media"),
                  nullable=True),
        sa.Column("evidence_id", sa.Uuid(), _fk("boundary_landmark", "evidence_id", "evidence"),
                  nullable=True),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_boundary_landmark"),
    )  # fmt: skip
    op.create_index("ix_boundary_landmark_boundary_id", "boundary_landmark", ["boundary_id"])

    op.create_table(
        "use_zone",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("boundary_id", sa.Uuid(), _fk("use_zone", "boundary_id", "cfr_boundary"),
                  nullable=False),
        sa.Column("use_type", use_zone_type, nullable=False),
        sa.Column("name", sa.String(200), nullable=True),
        sa.Column("geom", _geom("POLYGON"), nullable=False),
        sa.Column("area_ha", sa.Numeric(12, 4), nullable=False),
        sa.Column("season", sa.String(100), nullable=True),
        sa.Column("user_hamlets", postgresql.ARRAY(sa.String(200)),
                  server_default=sa.text("'{}'"), nullable=False),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_use_zone"),
    )  # fmt: skip
    op.create_index("ix_use_zone_boundary_id", "use_zone", ["boundary_id"])

    op.create_table(
        "boundary_walk",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("case_id", sa.Uuid(), _fk("boundary_walk", "case_id", "claim_case"),
                  nullable=False),
        sa.Column("walked_on", sa.Date(), nullable=False),
        sa.Column("participants", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("trace", _geom("LINESTRING"), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_by_user_id", sa.Uuid(),
                  _fk("boundary_walk", "created_by_user_id", "app_user"), nullable=False),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_boundary_walk"),
    )  # fmt: skip
    op.create_index("ix_boundary_walk_case_id", "boundary_walk", ["case_id"])

    op.create_table(
        "dispute",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("case_id", sa.Uuid(), _fk("dispute", "case_id", "claim_case"), nullable=False),
        sa.Column("neighbour_case_id", sa.Uuid(),
                  _fk("dispute", "neighbour_case_id", "claim_case"), nullable=False),
        sa.Column("neighbour_gram_sabha_id", sa.Uuid(),
                  _fk("dispute", "neighbour_gram_sabha_id", "gram_sabha"), nullable=False),
        sa.Column("overlap_geom", _geom("GEOMETRY"), nullable=False),
        sa.Column("overlap_ha", sa.Numeric(12, 4), nullable=False),
        sa.Column("detected_on", sa.Date(), nullable=False),
        sa.Column("joint_meeting_on", sa.Date(), nullable=True),
        sa.Column("joint_meeting_findings", sa.Text(), nullable=True),
        sa.Column("joint_meeting_media_id", sa.Uuid(),
                  _fk("dispute", "joint_meeting_media_id", "media"), nullable=True),
        sa.Column("outcome", dispute_outcome, nullable=True),
        sa.Column("sdlc_referral_on", sa.Date(), nullable=True),
        sa.Column("sdlc_referral_ref", sa.String(200), nullable=True),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_dispute"),
        sa.UniqueConstraint("case_id", "neighbour_case_id", name="uq_dispute_pair"),
    )  # fmt: skip
    op.create_index("ix_dispute_case_id", "dispute", ["case_id"])
    op.create_index("ix_dispute_neighbour_case_id", "dispute", ["neighbour_case_id"])
    op.create_index("ix_dispute_overlap_geom", "dispute", ["overlap_geom"], postgresql_using="gist")


def downgrade() -> None:
    op.drop_table("dispute")
    op.drop_table("boundary_walk")
    op.drop_table("use_zone")
    op.drop_table("boundary_landmark")
    op.drop_table("boundary_segment")
    op.drop_table("cfr_boundary")
    bind = op.get_bind()
    for enum in reversed(ENUMS):
        enum.drop(bind, checkfirst=False)
