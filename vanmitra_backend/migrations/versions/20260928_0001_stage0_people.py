"""Stage 0: village, gram_sabha, gs_member, app_user, user_role.

Revision ID: 0001
Revises:
Create Date: 2026-09-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# create_type=False: the types are created explicitly below, once each.
consolidation_status = postgresql.ENUM(
    "recognised",
    "listed",
    "consolidated",
    "finalised",
    name="consolidation_status",
    create_type=False,
)
gender = postgresql.ENUM("female", "male", "other", name="gender", create_type=False)
member_category = postgresql.ENUM("st", "otfd", "other", name="member_category", create_type=False)
app_role = postgresql.ENUM(
    "facilitator", "frc_member", "gs_secretary", name="app_role", create_type=False
)


def _timestamps() -> tuple[sa.Column, sa.Column]:
    return (
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )


def upgrade() -> None:
    # PostGIS is needed from Stage 3 (boundaries); enabling it now keeps later migrations simple.
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")

    bind = op.get_bind()
    for enum in (consolidation_status, gender, member_category, app_role):
        enum.create(bind, checkfirst=True)

    op.create_table(
        "village",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("lgd_code", sa.String(20), nullable=True),
        sa.Column("name_mr", sa.String(200), nullable=False),
        sa.Column("name_en", sa.String(200), nullable=False),
        sa.Column("gram_panchayat", sa.String(200), nullable=False),
        sa.Column("taluka", sa.String(100), nullable=False),
        sa.Column("district", sa.String(100), nullable=False),
        sa.Column("state", sa.String(100), nullable=False),
        sa.Column(
            "parent_village_id",
            sa.Uuid(),
            sa.ForeignKey("village.id", name="fk_village_parent_village_id_village"),
            nullable=True,
        ),
        sa.Column("consolidation_status", consolidation_status, nullable=False),
        *_timestamps(),
        sa.PrimaryKeyConstraint("id", name="pk_village"),
        sa.UniqueConstraint("lgd_code", name="uq_village_lgd_code"),
    )

    op.create_table(
        "gram_sabha",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "village_id",
            sa.Uuid(),
            sa.ForeignKey("village.id", name="fk_gram_sabha_village_id_village"),
            nullable=False,
        ),
        sa.Column("chain_head_hash", sa.String(64), nullable=True),
        *_timestamps(),
        sa.PrimaryKeyConstraint("id", name="pk_gram_sabha"),
        sa.UniqueConstraint("village_id", name="uq_gram_sabha_village_id"),
    )

    op.create_table(
        "gs_member",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "gram_sabha_id",
            sa.Uuid(),
            sa.ForeignKey("gram_sabha.id", name="fk_gs_member_gram_sabha_id_gram_sabha"),
            nullable=False,
        ),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("gender", gender, nullable=False),
        sa.Column("category", member_category, nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        *_timestamps(),
        sa.PrimaryKeyConstraint("id", name="pk_gs_member"),
    )
    op.create_index("ix_gs_member_gram_sabha_id", "gs_member", ["gram_sabha_id"])

    op.create_table(
        "app_user",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("phone", sa.String(15), nullable=False),
        sa.Column("pin_hash", sa.String(255), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column(
            "gs_member_id",
            sa.Uuid(),
            sa.ForeignKey("gs_member.id", name="fk_app_user_gs_member_id_gs_member"),
            nullable=True,
        ),
        sa.Column("is_admin", sa.Boolean(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("last_login_at", sa.DateTime(timezone=True), nullable=True),
        *_timestamps(),
        sa.PrimaryKeyConstraint("id", name="pk_app_user"),
        sa.UniqueConstraint("phone", name="uq_app_user_phone"),
    )

    op.create_table(
        "user_role",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "user_id",
            sa.Uuid(),
            sa.ForeignKey("app_user.id", name="fk_user_role_user_id_app_user"),
            nullable=False,
        ),
        sa.Column(
            "village_id",
            sa.Uuid(),
            sa.ForeignKey("village.id", name="fk_user_role_village_id_village"),
            nullable=False,
        ),
        sa.Column("role", app_role, nullable=False),
        sa.Column("valid_from", sa.Date(), server_default=sa.func.current_date(), nullable=False),
        sa.Column("valid_to", sa.Date(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_user_role"),
        sa.UniqueConstraint(
            "user_id", "village_id", "role", "valid_from", name="uq_user_role_grant"
        ),
        sa.CheckConstraint(
            "valid_to IS NULL OR valid_to >= valid_from", name=op.f("ck_user_role_valid_range")
        ),
    )
    op.create_index("ix_user_role_user_id", "user_role", ["user_id"])
    op.create_index("ix_user_role_village_id", "user_role", ["village_id"])


def downgrade() -> None:
    op.drop_table("user_role")
    op.drop_table("app_user")
    op.drop_table("gs_member")
    op.drop_table("gram_sabha")
    op.drop_table("village")
    bind = op.get_bind()
    for enum in (app_role, member_category, gender, consolidation_status):
        enum.drop(bind, checkfirst=True)
    # The postgis extension is left in place; it may be used by other schemas.
