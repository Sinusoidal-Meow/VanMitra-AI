"""Form B per-right details used in Maharashtra: survey nos., area, four boundaries, quantity.

Revision ID: 0005
Revises: 0004
Create Date: 2026-10-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

COLUMNS = (
    "survey_compartment_numbers",
    "total_area_ha",
    "common_use_area_ha",
    "boundary_east",
    "boundary_west",
    "boundary_north",
    "boundary_south",
    "annual_quantity",
)


def upgrade() -> None:
    op.add_column(
        "form_b_right",
        sa.Column(
            "survey_compartment_numbers",
            postgresql.ARRAY(sa.String(50)),
            server_default=sa.text("'{}'"),
            nullable=False,
        ),
    )
    op.add_column("form_b_right", sa.Column("total_area_ha", sa.Numeric(12, 2), nullable=True))
    op.add_column("form_b_right", sa.Column("common_use_area_ha", sa.Numeric(12, 2), nullable=True))
    for side in ("east", "west", "north", "south"):
        op.add_column("form_b_right", sa.Column(f"boundary_{side}", sa.String(200), nullable=True))
    op.add_column("form_b_right", sa.Column("annual_quantity", sa.Text(), nullable=True))


def downgrade() -> None:
    for name in reversed(COLUMNS):
        op.drop_column("form_b_right", name)
