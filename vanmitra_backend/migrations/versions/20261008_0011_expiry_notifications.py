"""Expired claims and in-app notifications.

- case_state gains 'expired' and workflow_action gains 'expire' (done by the system when
  a claim sent back to the villager is not resubmitted within 60 days).
- workflow_event.actor_user_id and actor_role may be empty: no person performs the expiry.
- notification: messages for one user each, in English and Marathi.

Downgrade drops the notification table only. PostgreSQL cannot remove enum values, and
the actor columns stay optional so that recorded expiries remain valid.

Revision ID: 0011
Revises: 0010
Create Date: 2026-10-08
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0011"
down_revision: str | None = "0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TYPE case_state ADD VALUE IF NOT EXISTS 'expired'")
    op.execute("ALTER TYPE workflow_action ADD VALUE IF NOT EXISTS 'expire'")
    op.alter_column("workflow_event", "actor_user_id", existing_type=sa.Uuid(), nullable=True)
    op.execute("ALTER TABLE workflow_event ALTER COLUMN actor_role DROP NOT NULL")

    op.create_table(
        "notification",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(),
                  sa.ForeignKey("app_user.id", name="fk_notification_user_id_app_user"),
                  nullable=False),
        sa.Column("case_id", sa.Uuid(),
                  sa.ForeignKey("claim_case.id", name="fk_notification_case_id_claim_case"),
                  nullable=True),
        sa.Column("kind", sa.String(40), nullable=False),
        sa.Column("title_en", sa.String(200), nullable=False),
        sa.Column("body_en", sa.Text(), nullable=False),
        sa.Column("title_mr", sa.String(200), nullable=False),
        sa.Column("body_mr", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_notification"),
    )  # fmt: skip
    op.create_index("ix_notification_user_id", "notification", ["user_id"])
    op.create_index("ix_notification_case_id", "notification", ["case_id"])


def downgrade() -> None:
    op.drop_table("notification")
