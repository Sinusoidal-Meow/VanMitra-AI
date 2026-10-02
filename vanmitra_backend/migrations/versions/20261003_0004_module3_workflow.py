"""Module 3: three-level roles with jurisdiction, review workflow, Form A, workflow history.

- app_role: facilitator / frc_member / gs_secretary → villager, gram_sabha, sdo,
  collector, dfo, tribal_welfare_officer (facilitator, frc_member → villager;
  gs_secretary → gram_sabha).
- user_role: village_id optional; taluka, district added; scope check per role.
- case_state: 18 spec states → draft, gs_review, sdo_review, district_review,
  title_issued, rejected (mapped by how far each old state had got).
- claim_case.reached_stage; form_a, form_a_family_member, form_a_claim, workflow_event.

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

NEW_ROLES = ("villager", "gram_sabha", "sdo", "collector", "dfo", "tribal_welfare_officer")
OLD_ROLES = ("facilitator", "frc_member", "gs_secretary")
NEW_STATES = ("draft", "gs_review", "sdo_review", "district_review", "title_issued", "rejected")
OLD_STATES = (
    "draft", "evidence_collection", "mapping_in_progress", "dispute_joint_hearing",
    "frc_verification", "gs_ready", "gs_resolved", "submitted_sdlc", "sdlc_under_exam",
    "sdlc_forwarded", "dlc_under_consideration", "remanded_to_gs", "modified_rejected",
    "petition_filed", "title_approved", "survey_pending", "record_updated", "cfr_active",
)  # fmt: skip

app_role = postgresql.ENUM(*NEW_ROLES, name="app_role", create_type=False)
case_state = postgresql.ENUM(*NEW_STATES, name="case_state", create_type=False)
workflow_action = postgresql.ENUM(
    "submit", "approve", "return", "reject", name="workflow_action", create_type=False
)
form_a_claim_code = postgresql.ENUM(
    "habitation", "self_cultivation", "disputed_land", "patta_lease_grant",
    "in_situ_rehabilitation", "displaced_without_compensation", "forest_village",
    "other_traditional",
    name="form_a_claim_code", create_type=False,
)  # fmt: skip


def _q(values: Sequence[str]) -> str:
    return ", ".join(f"'{v}'" for v in values)


def upgrade() -> None:
    # ── roles ─────────────────────────────────────────────────────────────────
    op.execute("ALTER TYPE app_role RENAME TO app_role_old")
    op.execute(f"CREATE TYPE app_role AS ENUM ({_q(NEW_ROLES)})")
    op.execute(
        "ALTER TABLE user_role ALTER COLUMN role TYPE app_role USING (CASE role::text "
        "WHEN 'gs_secretary' THEN 'gram_sabha' ELSE 'villager' END)::app_role"
    )
    op.execute("DROP TYPE app_role_old")

    # ── jurisdiction on role grants ───────────────────────────────────────────
    op.alter_column("user_role", "village_id", existing_type=sa.Uuid(), nullable=True)
    op.add_column("user_role", sa.Column("taluka", sa.String(100), nullable=True))
    op.add_column("user_role", sa.Column("district", sa.String(100), nullable=True))
    op.create_check_constraint(
        op.f("ck_user_role_scope"),
        "user_role",
        "(role IN ('villager', 'gram_sabha') AND village_id IS NOT NULL)"
        " OR (role = 'sdo' AND taluka IS NOT NULL AND district IS NOT NULL)"
        " OR (role IN ('collector', 'dfo', 'tribal_welfare_officer') AND district IS NOT NULL)",
    )

    # ── case states ───────────────────────────────────────────────────────────
    op.execute("ALTER TYPE case_state RENAME TO case_state_old")
    op.execute(f"CREATE TYPE case_state AS ENUM ({_q(NEW_STATES)})")
    op.execute(
        "ALTER TABLE claim_case ALTER COLUMN state TYPE case_state USING (CASE state::text "
        "WHEN 'gs_ready' THEN 'gs_review' WHEN 'gs_resolved' THEN 'gs_review' "
        "WHEN 'remanded_to_gs' THEN 'gs_review' "
        "WHEN 'submitted_sdlc' THEN 'sdo_review' WHEN 'sdlc_under_exam' THEN 'sdo_review' "
        "WHEN 'petition_filed' THEN 'sdo_review' "
        "WHEN 'sdlc_forwarded' THEN 'district_review' "
        "WHEN 'dlc_under_consideration' THEN 'district_review' "
        "WHEN 'title_approved' THEN 'title_issued' WHEN 'survey_pending' THEN 'title_issued' "
        "WHEN 'record_updated' THEN 'title_issued' WHEN 'cfr_active' THEN 'title_issued' "
        "WHEN 'modified_rejected' THEN 'rejected' ELSE 'draft' END)::case_state"
    )
    op.execute("DROP TYPE case_state_old")

    op.add_column(
        "claim_case",
        sa.Column("reached_stage", sa.SmallInteger(), server_default=sa.text("0"), nullable=False),
    )
    op.execute(
        "UPDATE claim_case SET reached_stage = CASE state::text WHEN 'gs_review' THEN 1 "
        "WHEN 'sdo_review' THEN 2 WHEN 'district_review' THEN 3 WHEN 'title_issued' THEN 4 "
        "ELSE 0 END"
    )

    # ── new enums ─────────────────────────────────────────────────────────────
    bind = op.get_bind()
    workflow_action.create(bind, checkfirst=True)
    form_a_claim_code.create(bind, checkfirst=True)

    # ── Form A ────────────────────────────────────────────────────────────────
    op.create_table(
        "form_a",
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("claim_case.id", name="fk_form_a_case_id_claim_case"),
            nullable=False,
        ),
        sa.Column(
            "claimant_names",
            postgresql.ARRAY(sa.String(200)),
            server_default=sa.text("'{}'"),
            nullable=False,
        ),
        sa.Column("spouse_name", sa.String(200), nullable=True),
        sa.Column("father_mother_name", sa.String(200), nullable=True),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column("is_scheduled_tribe", sa.Boolean(), nullable=True),
        sa.Column("is_otfd", sa.Boolean(), nullable=True),
        sa.Column("spouse_is_scheduled_tribe", sa.Boolean(), nullable=True),
        sa.Column("other_information", sa.Text(), nullable=True),
        sa.Column(
            "updated_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("app_user.id", name="fk_form_a_updated_by_user_id_app_user"),
            nullable=False,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("case_id", name="pk_form_a"),
    )
    op.create_table(
        "form_a_family_member",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("form_a.case_id", name="fk_form_a_family_member_case_id_form_a"),
            nullable=False,
        ),
        sa.Column("seq", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("age", sa.SmallInteger(), nullable=True),
        sa.Column("relation", sa.String(100), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_form_a_family_member"),
        sa.UniqueConstraint("case_id", "seq", name="uq_form_a_family_member_seq"),
    )
    op.create_index("ix_form_a_family_member_case_id", "form_a_family_member", ["case_id"])
    op.create_table(
        "form_a_claim",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("form_a.case_id", name="fk_form_a_claim_case_id_form_a"),
            nullable=False,
        ),
        sa.Column("claim_code", form_a_claim_code, nullable=False),
        sa.Column("extent_ha", sa.Numeric(10, 2), nullable=True),
        sa.Column("details", sa.Text(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_form_a_claim"),
        sa.UniqueConstraint("case_id", "claim_code", name="uq_form_a_claim_code"),
    )
    op.create_index("ix_form_a_claim_case_id", "form_a_claim", ["case_id"])

    # ── workflow history ──────────────────────────────────────────────────────
    op.create_table(
        "workflow_event",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "case_id",
            sa.Uuid(),
            sa.ForeignKey("claim_case.id", name="fk_workflow_event_case_id_claim_case"),
            nullable=False,
        ),
        sa.Column("action", workflow_action, nullable=False),
        sa.Column("from_state", case_state, nullable=False),
        sa.Column("to_state", case_state, nullable=False),
        sa.Column(
            "actor_user_id",
            sa.Uuid(),
            sa.ForeignKey("app_user.id", name="fk_workflow_event_actor_user_id_app_user"),
            nullable=False,
        ),
        sa.Column("actor_role", app_role, nullable=False),
        sa.Column("actor_name", sa.String(200), nullable=False),
        sa.Column("remarks", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_workflow_event"),
    )
    op.create_index("ix_workflow_event_case_id", "workflow_event", ["case_id"])


def downgrade() -> None:
    op.drop_table("workflow_event")
    op.drop_table("form_a_claim")
    op.drop_table("form_a_family_member")
    op.drop_table("form_a")
    bind = op.get_bind()
    form_a_claim_code.drop(bind, checkfirst=True)
    workflow_action.drop(bind, checkfirst=True)
    # Form A cases cannot exist before 0004.
    op.execute(
        "DELETE FROM claim_evidence_entry WHERE case_id IN (SELECT id FROM claim_case WHERE claim_type = 'ifr')"
    )
    op.execute("DELETE FROM claim_case WHERE claim_type = 'ifr'")
    op.drop_column("claim_case", "reached_stage")

    op.execute("ALTER TYPE case_state RENAME TO case_state_new")
    op.execute(f"CREATE TYPE case_state AS ENUM ({_q(OLD_STATES)})")
    op.execute(
        "ALTER TABLE claim_case ALTER COLUMN state TYPE case_state USING (CASE state::text "
        "WHEN 'gs_review' THEN 'gs_ready' WHEN 'sdo_review' THEN 'sdlc_under_exam' "
        "WHEN 'district_review' THEN 'dlc_under_consideration' "
        "WHEN 'title_issued' THEN 'title_approved' WHEN 'rejected' THEN 'modified_rejected' "
        "ELSE 'draft' END)::case_state"
    )
    op.execute("DROP TYPE case_state_new")

    # Officials have no pre-0004 equivalent and no village: remove their grants.
    op.execute("DELETE FROM user_role WHERE village_id IS NULL")
    op.drop_constraint(op.f("ck_user_role_scope"), "user_role", type_="check")
    op.drop_column("user_role", "district")
    op.drop_column("user_role", "taluka")
    op.alter_column("user_role", "village_id", existing_type=sa.Uuid(), nullable=False)

    op.execute("ALTER TYPE app_role RENAME TO app_role_new")
    op.execute(f"CREATE TYPE app_role AS ENUM ({_q(OLD_ROLES)})")
    op.execute(
        "ALTER TABLE user_role ALTER COLUMN role TYPE app_role USING (CASE role::text "
        "WHEN 'gram_sabha' THEN 'gs_secretary' ELSE 'frc_member' END)::app_role"
    )
    op.execute("DROP TYPE app_role_new")
