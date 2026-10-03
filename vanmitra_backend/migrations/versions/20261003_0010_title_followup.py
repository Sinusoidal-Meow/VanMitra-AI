"""Title follow-up: certified copy, survey, record-of-rights entry, closing (Stage 5).

Revision ID: 0010
Revises: 0009
Create Date: 2026-10-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0010"
down_revision: str | None = "0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _fk(col: str, ref: str) -> sa.ForeignKey:
    return sa.ForeignKey(f"{ref}.id", name=f"fk_title_followup_{col}_{ref}")


def upgrade() -> None:
    op.create_table(
        "title_followup",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("case_id", sa.Uuid(), _fk("case_id", "claim_case"), nullable=False),
        sa.Column("certified_copy_media_id", sa.Uuid(), _fk("certified_copy_media_id", "media"),
                  nullable=True),
        sa.Column("certified_copy_on", sa.Date(), nullable=True),
        sa.Column("survey_letter_id", sa.Uuid(), _fk("survey_letter_id", "correspondence"),
                  nullable=True),
        sa.Column("survey_done_on", sa.Date(), nullable=True),
        sa.Column("record_entry_on", sa.Date(), nullable=True),
        sa.Column("record_entry_ref", sa.String(200), nullable=True),
        sa.Column("record_entry_media_id", sa.Uuid(), _fk("record_entry_media_id", "media"),
                  nullable=True),
        sa.Column("closed_on", sa.Date(), nullable=True),
        sa.Column("updated_by_user_id", sa.Uuid(), _fk("updated_by_user_id", "app_user"),
                  nullable=False),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_title_followup"),
        sa.UniqueConstraint("case_id", name="uq_title_followup_case_id"),
    )  # fmt: skip


def downgrade() -> None:
    op.drop_table("title_followup")
