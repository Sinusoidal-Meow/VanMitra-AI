"""Call for claims, acknowledgement, media, evidence ledger, hash chain, letters (Stage 2).

Evidence, verifications, ledger links and workflow events are append-only: a trigger
refuses UPDATE and DELETE on them (rule C8).

Revision ID: 0007
Revises: 0006
Create Date: 2026-10-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0007"
down_revision: str | None = "0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

evidence_kind = postgresql.ENUM(
    "document_scan", "photo", "gps_point", "satellite", "audio", "elder_statement", "text_note",
    name="evidence_kind", create_type=False,
)  # fmt: skip
letter_template = postgresql.ENUM(
    "g2_intimation_adjoining", "g2_intimation_sdlc", "g5_maps_request", "g6_records_request",
    "g7_site_visit", "g18_survey_request", "other",
    name="letter_template", create_type=False,
)  # fmt: skip
evidence_rule = postgresql.ENUM(name="evidence_rule", create_type=False)

ENUMS = (evidence_kind, letter_template)
APPEND_ONLY = ("evidence", "evidence_verification", "ledger_entry", "workflow_event")


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
        "claim_call",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("gram_sabha_id", sa.Uuid(), _fk("claim_call", "gram_sabha_id", "gram_sabha"),
                  nullable=False),
        sa.Column("called_on", sa.Date(), nullable=False),
        sa.Column("window_ends_on", sa.Date(), nullable=False),
        sa.Column("place_of_filing", sa.String(300), nullable=False),
        sa.Column("notice_displayed_on", sa.Date(), nullable=True),
        sa.Column("cfr_determination_on", sa.Date(), nullable=True),
        sa.Column("extended_to", sa.Date(), nullable=True),
        sa.Column("extension_reason", sa.Text(), nullable=True),
        sa.Column("extension_resolution_ref", sa.String(200), nullable=True),
        sa.Column("is_current", sa.Boolean(), nullable=False),
        sa.Column("created_by_user_id", sa.Uuid(),
                  _fk("claim_call", "created_by_user_id", "app_user"), nullable=False),
        _created_at(),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_claim_call"),
    )  # fmt: skip
    op.create_index("ix_claim_call_gram_sabha_id", "claim_call", ["gram_sabha_id"])

    op.add_column("claim_case", sa.Column("ack_serial", sa.String(60), nullable=True))
    op.add_column("claim_case", sa.Column("acknowledged_on", sa.Date(), nullable=True))
    op.add_column(
        "claim_case",
        sa.Column("claim_call_id", sa.Uuid(), _fk("claim_case", "claim_call_id", "claim_call"),
                  nullable=True),
    )  # fmt: skip
    op.add_column("claim_case", sa.Column("filed_within_window", sa.Boolean(), nullable=True))
    op.create_unique_constraint(
        "uq_claim_case_ack_serial", "claim_case", ["gram_sabha_id", "ack_serial"]
    )

    op.create_table(
        "media",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("sha256", sa.String(64), nullable=False),
        sa.Column("mime", sa.String(100), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("original_name", sa.String(300), nullable=True),
        sa.Column("storage_key", sa.String(300), nullable=False),
        sa.Column("uploaded_by_user_id", sa.Uuid(),
                  _fk("media", "uploaded_by_user_id", "app_user"), nullable=False),
        sa.Column("captured_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("gps_lat", sa.Float(), nullable=True),
        sa.Column("gps_lon", sa.Float(), nullable=True),
        sa.Column("gps_accuracy_m", sa.Float(), nullable=True),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_media"),
    )  # fmt: skip
    op.create_index("ix_media_sha256", "media", ["sha256"])

    op.create_table(
        "evidence",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("case_id", sa.Uuid(), _fk("evidence", "case_id", "claim_case"), nullable=False),
        sa.Column("rule_ref", evidence_rule, nullable=False),
        sa.Column("kind", evidence_kind, nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("media_id", sa.Uuid(), _fk("evidence", "media_id", "media"), nullable=True),
        sa.Column("source_office", sa.String(200), nullable=True),
        sa.Column("ref_no", sa.String(100), nullable=True),
        sa.Column("doc_date", sa.Date(), nullable=True),
        sa.Column("gps_lat", sa.Float(), nullable=True),
        sa.Column("gps_lon", sa.Float(), nullable=True),
        sa.Column("gps_accuracy_m", sa.Float(), nullable=True),
        sa.Column("is_substitutable", sa.Boolean(), nullable=False),
        sa.Column("elder_member_id", sa.Uuid(), _fk("evidence", "elder_member_id", "gs_member"),
                  nullable=True),
        sa.Column("transcript", sa.Text(), nullable=True),
        sa.Column("signed_scan_media_id", sa.Uuid(),
                  _fk("evidence", "signed_scan_media_id", "media"), nullable=True),
        sa.Column("supersedes_id", sa.Uuid(), _fk("evidence", "supersedes_id", "evidence"),
                  nullable=True),
        sa.Column("correction_reason", sa.Text(), nullable=True),
        sa.Column("added_by_user_id", sa.Uuid(), _fk("evidence", "added_by_user_id", "app_user"),
                  nullable=False),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_evidence"),
    )  # fmt: skip
    op.create_index("ix_evidence_case_id", "evidence", ["case_id"])

    op.create_table(
        "evidence_verification",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("evidence_id", sa.Uuid(),
                  _fk("evidence_verification", "evidence_id", "evidence"), nullable=False),
        sa.Column("verified_by_user_id", sa.Uuid(),
                  _fk("evidence_verification", "verified_by_user_id", "app_user"),
                  nullable=False),
        sa.Column("verified_by_name", sa.String(200), nullable=False),
        sa.Column("remarks", sa.Text(), nullable=True),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_evidence_verification"),
    )  # fmt: skip
    op.create_index(
        "ix_evidence_verification_evidence_id", "evidence_verification", ["evidence_id"]
    )

    op.create_table(
        "ledger_entry",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("gram_sabha_id", sa.Uuid(), _fk("ledger_entry", "gram_sabha_id", "gram_sabha"),
                  nullable=False),
        sa.Column("seq", sa.Integer(), nullable=False),
        sa.Column("entity", sa.String(50), nullable=False),
        sa.Column("entity_id", sa.Uuid(), nullable=False),
        sa.Column("prev_hash", sa.String(64), nullable=False),
        sa.Column("record_hash", sa.String(64), nullable=False),
        _created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_ledger_entry"),
        sa.UniqueConstraint("gram_sabha_id", "seq", name="uq_ledger_entry_seq"),
    )  # fmt: skip
    op.create_index("ix_ledger_entry_gram_sabha_id", "ledger_entry", ["gram_sabha_id"])

    op.create_table(
        "correspondence",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("gram_sabha_id", sa.Uuid(),
                  _fk("correspondence", "gram_sabha_id", "gram_sabha"), nullable=False),
        sa.Column("case_id", sa.Uuid(), _fk("correspondence", "case_id", "claim_case"),
                  nullable=True),
        sa.Column("template", letter_template, nullable=False),
        sa.Column("addressee", sa.String(300), nullable=False),
        sa.Column("subject", sa.String(300), nullable=False),
        sa.Column("body", sa.Text(), nullable=True),
        sa.Column("neighbour_village", sa.String(200), nullable=True),
        sa.Column("records_requested", postgresql.ARRAY(sa.String(300)),
                  server_default=sa.text("'{}'"), nullable=False),
        sa.Column("dispatched_on", sa.Date(), nullable=True),
        sa.Column("reminder_on", sa.Date(), nullable=True),
        sa.Column("response_received_on", sa.Date(), nullable=True),
        sa.Column("outcome", sa.Text(), nullable=True),
        sa.Column("created_by_user_id", sa.Uuid(),
                  _fk("correspondence", "created_by_user_id", "app_user"), nullable=False),
        _created_at(),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_correspondence"),
    )  # fmt: skip
    op.create_index("ix_correspondence_gram_sabha_id", "correspondence", ["gram_sabha_id"])
    op.create_index("ix_correspondence_case_id", "correspondence", ["case_id"])

    op.execute(
        """
        CREATE FUNCTION forbid_change() RETURNS trigger AS $$
        BEGIN
            RAISE EXCEPTION '% is append-only: % refused', TG_TABLE_NAME, TG_OP
                USING ERRCODE = 'restrict_violation';
        END;
        $$ LANGUAGE plpgsql
        """
    )
    for table in APPEND_ONLY:
        op.execute(
            f"CREATE TRIGGER {table}_append_only BEFORE UPDATE OR DELETE ON {table} "
            "FOR EACH ROW EXECUTE FUNCTION forbid_change()"
        )


def downgrade() -> None:
    for table in APPEND_ONLY:
        op.execute(f"DROP TRIGGER IF EXISTS {table}_append_only ON {table}")
    op.execute("DROP FUNCTION IF EXISTS forbid_change()")
    op.drop_table("correspondence")
    op.drop_table("ledger_entry")
    op.drop_table("evidence_verification")
    op.drop_table("evidence")
    op.drop_table("media")
    op.drop_constraint("uq_claim_case_ack_serial", "claim_case", type_="unique")
    op.drop_column("claim_case", "filed_within_window")
    op.drop_column("claim_case", "claim_call_id")
    op.drop_column("claim_case", "acknowledged_on")
    op.drop_column("claim_case", "ack_serial")
    op.drop_table("claim_call")
    bind = op.get_bind()
    for enum in reversed(ENUMS):
        enum.drop(bind, checkfirst=False)
