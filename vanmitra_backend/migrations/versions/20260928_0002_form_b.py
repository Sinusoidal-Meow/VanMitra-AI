"""Claim cases and the Form B draft: claim_case, form_b, form_b_right, claim_evidence_entry.

Revision ID: 0002
Revises: 0001
Create Date: 2026-09-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

claim_type = postgresql.ENUM("ifr", "cr", "cfr", name="claim_type", create_type=False)
case_state = postgresql.ENUM(
    "draft", "evidence_collection", "mapping_in_progress", "dispute_joint_hearing",
    "frc_verification", "gs_ready", "gs_resolved", "submitted_sdlc", "sdlc_under_exam",
    "sdlc_forwarded", "dlc_under_consideration", "remanded_to_gs", "modified_rejected",
    "petition_filed", "title_approved", "survey_pending", "record_updated", "cfr_active",
    name="case_state", create_type=False,
)  # fmt: skip
form_b_right_code = postgresql.ENUM(
    "nistar", "minor_forest_produce", "water_bodies", "grazing", "nomadic_pastoral_access",
    "habitat", "biodiversity_knowledge", "other_traditional",
    name="form_b_right_code", create_type=False,
)  # fmt: skip
evidence_rule = postgresql.ENUM(
    "13(1)(a)", "13(1)(b)", "13(1)(c)", "13(1)(d)", "13(1)(e)", "13(1)(f)", "13(1)(g)",
    "13(1)(h)", "13(1)(i)", "13(2)(a)", "13(2)(b)", "13(2)(c)", "13(2)(d)", "13(2)(e)",
    name="evidence_rule", create_type=False,
)  # fmt: skip

ENUMS = (claim_type, case_state, form_b_right_code, evidence_rule)


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
    bind = op.get_bind()
    for enum in ENUMS:
        enum.create(bind, checkfirst=True)

    op.create_table(
        "claim_case",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "gram_sabha_id",
            sa.Uuid(),
            sa.ForeignKey("gram_sabha.id", name="fk_claim_case_gram_sabha_id_gram_sabha"),
            nullable=False,
        ),
        sa.Column("claim_type", claim_type, nullable=False),
        sa.Column("state", case_state, nullable=False),
        sa.Column(
            "created_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("app_user.id", name="fk_claim_case_created_by_user_id_app_user"),
            nullable=False,
        ),
        *_timestamps(),
        sa.PrimaryKeyConstraint("id", name="pk_claim_case"),
    )
    op.create_index("ix_claim_case_gram_sabha_id", "claim_case", ["gram_sabha_id"])

    op.create_table(
        "form_b",
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("claim_case.id", name="fk_form_b_case_id_claim_case"),
            nullable=False,
        ),
        sa.Column(
            "claimant_names",
            postgresql.ARRAY(sa.String(200)),
            server_default=sa.text("'{}'"),
            nullable=False,
        ),
        sa.Column("is_fdst_community", sa.Boolean(), nullable=True),
        sa.Column("is_otfd_community", sa.Boolean(), nullable=True),
        sa.Column("other_information", sa.Text(), nullable=True),
        sa.Column(
            "updated_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("app_user.id", name="fk_form_b_updated_by_user_id_app_user"),
            nullable=False,
        ),
        *_timestamps(),
        sa.PrimaryKeyConstraint("case_id", name="pk_form_b"),
    )

    op.create_table(
        "form_b_right",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("form_b.case_id", name="fk_form_b_right_case_id_form_b"),
            nullable=False,
        ),
        sa.Column("right_code", form_b_right_code, nullable=False),
        sa.Column("details", sa.Text(), nullable=False),
        sa.Column(
            "items",
            postgresql.ARRAY(sa.String(200)),
            server_default=sa.text("'{}'"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_form_b_right"),
        sa.UniqueConstraint("case_id", "right_code", name="uq_form_b_right_code"),
    )
    op.create_index("ix_form_b_right_case_id", "form_b_right", ["case_id"])

    op.create_table(
        "claim_evidence_entry",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("claim_case.id", name="fk_claim_evidence_entry_case_id_claim_case"),
            nullable=False,
        ),
        sa.Column("seq", sa.Integer(), nullable=False),
        sa.Column("rule_ref", evidence_rule, nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_claim_evidence_entry"),
        sa.UniqueConstraint("case_id", "seq", name="uq_claim_evidence_entry_seq"),
    )
    op.create_index("ix_claim_evidence_entry_case_id", "claim_evidence_entry", ["case_id"])


def downgrade() -> None:
    op.drop_table("claim_evidence_entry")
    op.drop_table("form_b_right")
    op.drop_table("form_b")
    op.drop_table("claim_case")
    bind = op.get_bind()
    for enum in reversed(ENUMS):
        enum.drop(bind, checkfirst=True)
