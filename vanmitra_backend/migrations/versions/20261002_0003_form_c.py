"""Form C draft: form_c, form_c_landmark, form_c_bordering_village.

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-02
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

boundary_side = postgresql.ENUM(
    "east", "west", "north", "south", "within", name="boundary_side", create_type=False
)
landmark_kind = postgresql.ENUM(
    "river", "stream", "spring", "pond", "sacred_place", "sacred_grove", "burial_ground",
    "well", "road", "compartment_pillar", "hill", "other",
    name="landmark_kind", create_type=False,
)  # fmt: skip

ENUMS = (boundary_side, landmark_kind)


def upgrade() -> None:
    bind = op.get_bind()
    for enum in ENUMS:
        enum.create(bind, checkfirst=True)

    op.create_table(
        "form_c",
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("claim_case.id", name="fk_form_c_case_id_claim_case"),
            nullable=False,
        ),
        sa.Column("resolution_statement", sa.Text(), nullable=False),
        sa.Column("area_description", sa.Text(), nullable=True),
        sa.Column("approx_area_ha", sa.Numeric(12, 2), nullable=True),
        sa.Column(
            "pastoral_seasonal_use", sa.Boolean(), server_default=sa.text("false"), nullable=False
        ),
        sa.Column("seasonal_use_details", sa.Text(), nullable=True),
        sa.Column(
            "khasra_compartment_numbers",
            postgresql.ARRAY(sa.String(50)),
            server_default=sa.text("'{}'"),
            nullable=False,
        ),
        sa.Column(
            "updated_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("app_user.id", name="fk_form_c_updated_by_user_id_app_user"),
            nullable=False,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("case_id", name="pk_form_c"),
    )

    op.create_table(
        "form_c_landmark",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("form_c.case_id", name="fk_form_c_landmark_case_id_form_c"),
            nullable=False,
        ),
        sa.Column("seq", sa.Integer(), nullable=False),
        sa.Column("side", boundary_side, nullable=False),
        sa.Column("kind", landmark_kind, nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_form_c_landmark"),
        sa.UniqueConstraint("case_id", "seq", name="uq_form_c_landmark_seq"),
    )
    op.create_index("ix_form_c_landmark_case_id", "form_c_landmark", ["case_id"])

    op.create_table(
        "form_c_bordering_village",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("form_c.case_id", name="fk_form_c_bordering_village_case_id_form_c"),
            nullable=False,
        ),
        sa.Column("seq", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column(
            "shares_resources", sa.Boolean(), server_default=sa.text("false"), nullable=False
        ),
        sa.Column("sharing_details", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_form_c_bordering_village"),
        sa.UniqueConstraint("case_id", "seq", name="uq_form_c_bordering_village_seq"),
    )
    op.create_index("ix_form_c_bordering_village_case_id", "form_c_bordering_village", ["case_id"])


def downgrade() -> None:
    op.drop_table("form_c_bordering_village")
    op.drop_table("form_c_landmark")
    op.drop_table("form_c")
    bind = op.get_bind()
    for enum in reversed(ENUMS):
        enum.drop(bind, checkfirst=True)
