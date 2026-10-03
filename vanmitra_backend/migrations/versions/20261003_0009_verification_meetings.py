"""Field verification, Gram Sabha meetings, attendance and resolutions (Stage 4).

Verification proceedings and resolutions are append-only (trigger from migration 0007).

Revision ID: 0009
Revises: 0008
Create Date: 2026-10-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009"
down_revision: str | None = "0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

APPEND_ONLY = ("verification_proceeding", "resolution")


def _fk(table: str, col: str, ref: str) -> sa.ForeignKey:
    return sa.ForeignKey(f"{ref}.id", name=f"fk_{table}_{col}_{ref}")


def _created_at() -> sa.Column[object]:
    return sa.Column(
        "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
    )


def upgrade() -> None:
    op.create_table(
        "verification_proceeding",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("case_id", sa.Uuid(), _fk("verification_proceeding", "case_id", "claim_case"),
                  nullable=False),
        sa.Column("attempt_no", sa.Integer(), nullable=False),
        sa.Column("visit_on", sa.Date(), nullable=False),
        sa.Column("intimation_id", sa.Uuid(),
                  _fk("verification_proceeding", "intimation_id", "correspondence"),
                  nullable=True),
        sa.Column("observations", sa.Text(), nullable=False),
        sa.Column("presence", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("forest_signed", sa.Boolean(), nullable=False),
        sa.Column("forest_absence_recorded", sa.Boolean(), nullable=False),
        sa.Column("revenue_signed", sa.Boolean(), nullable=False),
        sa.Column("revenue_absence_recorded", sa.Boolean(), nullable=False),
        sa.Column("signed_scan_media_id", sa.Uuid(),
                  _fk("verification_proceeding", "signed_scan_media_id", "media"), nullable=True),
        sa.Column("recorded_by_user_id", sa.Uuid(),
                  _fk("verification_proceeding", "recorded_by_user_id", "app_user"),
                  nullable=False),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_verification_proceeding"),
        sa.UniqueConstraint("case_id", "attempt_no", name="uq_verification_attempt"),
    )  # fmt: skip
    op.create_index("ix_verification_proceeding_case_id", "verification_proceeding", ["case_id"])

    op.create_table(
        "gs_meeting",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("gram_sabha_id", sa.Uuid(), _fk("gs_meeting", "gram_sabha_id", "gram_sabha"),
                  nullable=False),
        sa.Column("held_on", sa.Date(), nullable=False),
        sa.Column("place", sa.String(300), nullable=False),
        sa.Column("notice_on", sa.Date(), nullable=True),
        sa.Column("agenda", sa.Text(), nullable=False),
        sa.Column("registered_count", sa.Integer(), nullable=False),
        sa.Column("created_by_user_id", sa.Uuid(),
                  _fk("gs_meeting", "created_by_user_id", "app_user"), nullable=False),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_gs_meeting"),
    )  # fmt: skip
    op.create_index("ix_gs_meeting_gram_sabha_id", "gs_meeting", ["gram_sabha_id"])

    op.create_table(
        "attendance",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("meeting_id", sa.Uuid(), _fk("attendance", "meeting_id", "gs_meeting"),
                  nullable=False),
        sa.Column("gs_member_id", sa.Uuid(), _fk("attendance", "gs_member_id", "gs_member"),
                  nullable=False),
        sa.Column("present", sa.Boolean(), nullable=False),
        sa.Column("method", sa.String(20), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_attendance"),
        sa.UniqueConstraint("meeting_id", "gs_member_id", name="uq_attendance_member"),
    )  # fmt: skip
    op.create_index("ix_attendance_meeting_id", "attendance", ["meeting_id"])

    op.create_table(
        "resolution",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("gram_sabha_id", sa.Uuid(), _fk("resolution", "gram_sabha_id", "gram_sabha"),
                  nullable=False),
        sa.Column("meeting_id", sa.Uuid(), _fk("resolution", "meeting_id", "gs_meeting"),
                  nullable=False),
        sa.Column("case_id", sa.Uuid(), _fk("resolution", "case_id", "claim_case"), nullable=False),
        sa.Column("number", sa.String(40), nullable=False),
        sa.Column("decision_text", sa.Text(), nullable=False),
        sa.Column("votes_for", sa.Integer(), nullable=False),
        sa.Column("votes_against", sa.Integer(), nullable=False),
        sa.Column("boundary_id", sa.Uuid(), _fk("resolution", "boundary_id", "cfr_boundary"),
                  nullable=True),
        sa.Column("quorum_proof", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("signed_scan_media_id", sa.Uuid(),
                  _fk("resolution", "signed_scan_media_id", "media"), nullable=True),
        sa.Column("supersedes_id", sa.Uuid(), _fk("resolution", "supersedes_id", "resolution"),
                  nullable=True),
        sa.Column("correction_reason", sa.Text(), nullable=True),
        sa.Column("created_by_user_id", sa.Uuid(),
                  _fk("resolution", "created_by_user_id", "app_user"), nullable=False),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_resolution"),
        sa.UniqueConstraint("gram_sabha_id", "number", name="uq_resolution_number"),
    )  # fmt: skip
    op.create_index("ix_resolution_gram_sabha_id", "resolution", ["gram_sabha_id"])
    op.create_index("ix_resolution_meeting_id", "resolution", ["meeting_id"])
    op.create_index("ix_resolution_case_id", "resolution", ["case_id"])

    for table in APPEND_ONLY:
        op.execute(
            f"CREATE TRIGGER {table}_append_only BEFORE UPDATE OR DELETE ON {table} "
            "FOR EACH ROW EXECUTE FUNCTION forbid_change()"
        )


def downgrade() -> None:
    op.drop_table("resolution")
    op.drop_table("attendance")
    op.drop_table("gs_meeting")
    op.drop_table("verification_proceeding")
