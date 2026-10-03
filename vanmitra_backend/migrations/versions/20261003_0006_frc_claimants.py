"""FRC constitution, case claimants and recusals (Stage 1).

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "frc",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "gram_sabha_id",
            sa.Uuid(),
            sa.ForeignKey("gram_sabha.id", name="fk_frc_gram_sabha_id_gram_sabha"),
            nullable=False,
        ),
        sa.Column("constituted_on", sa.Date(), nullable=False),
        sa.Column("resolution_ref", sa.String(200), nullable=True),
        sa.Column("sdlc_intimated_on", sa.Date(), nullable=True),
        sa.Column("composition_proof", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("is_current", sa.Boolean(), nullable=False),
        sa.Column(
            "created_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("app_user.id", name="fk_frc_created_by_user_id_app_user"),
            nullable=False,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_frc"),
    )
    op.create_index("ix_frc_gram_sabha_id", "frc", ["gram_sabha_id"])
    op.create_table(
        "frc_member",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "frc_id",
            sa.Uuid(),
            sa.ForeignKey("frc.id", name="fk_frc_member_frc_id_frc"),
            nullable=False,
        ),
        sa.Column(
            "gs_member_id",
            sa.Uuid(),
            sa.ForeignKey("gs_member.id", name="fk_frc_member_gs_member_id_gs_member"),
            nullable=False,
        ),
        sa.Column("is_chair", sa.Boolean(), nullable=False),
        sa.Column("is_secretary", sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_frc_member"),
        sa.UniqueConstraint("frc_id", "gs_member_id", name="uq_frc_member_member"),
    )
    op.create_index("ix_frc_member_frc_id", "frc_member", ["frc_id"])
    op.create_table(
        "case_claimant",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("claim_case.id", name="fk_case_claimant_case_id_claim_case"),
            nullable=False,
        ),
        sa.Column(
            "gs_member_id",
            sa.Uuid(),
            sa.ForeignKey("gs_member.id", name="fk_case_claimant_gs_member_id_gs_member"),
            nullable=False,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_case_claimant"),
        sa.UniqueConstraint("case_id", "gs_member_id", name="uq_case_claimant_member"),
    )
    op.create_index("ix_case_claimant_case_id", "case_claimant", ["case_id"])
    op.create_table(
        "recusal",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("claim_case.id", name="fk_recusal_case_id_claim_case"),
            nullable=False,
        ),
        sa.Column(
            "gs_member_id",
            sa.Uuid(),
            sa.ForeignKey("gs_member.id", name="fk_recusal_gs_member_id_gs_member"),
            nullable=False,
        ),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column(
            "recorded_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_recusal"),
        sa.UniqueConstraint("case_id", "gs_member_id", name="uq_recusal_member"),
    )
    op.create_index("ix_recusal_case_id", "recusal", ["case_id"])


def downgrade() -> None:
    op.drop_table("recusal")
    op.drop_table("case_claimant")
    op.drop_table("frc_member")
    op.drop_table("frc")
