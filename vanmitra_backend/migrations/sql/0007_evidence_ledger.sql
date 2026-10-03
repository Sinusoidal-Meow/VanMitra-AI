BEGIN;

-- Running upgrade 0006 -> 0007

CREATE TYPE evidence_kind AS ENUM ('document_scan', 'photo', 'gps_point', 'satellite', 'audio', 'elder_statement', 'text_note');

CREATE TYPE letter_template AS ENUM ('g2_intimation_adjoining', 'g2_intimation_sdlc', 'g5_maps_request', 'g6_records_request', 'g7_site_visit', 'g18_survey_request', 'other');

CREATE TABLE claim_call (
    id UUID NOT NULL, 
    gram_sabha_id UUID NOT NULL, 
    called_on DATE NOT NULL, 
    window_ends_on DATE NOT NULL, 
    place_of_filing VARCHAR(300) NOT NULL, 
    notice_displayed_on DATE, 
    cfr_determination_on DATE, 
    extended_to DATE, 
    extension_reason TEXT, 
    extension_resolution_ref VARCHAR(200), 
    is_current BOOLEAN NOT NULL, 
    created_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_claim_call PRIMARY KEY (id), 
    CONSTRAINT fk_claim_call_gram_sabha_id_gram_sabha FOREIGN KEY(gram_sabha_id) REFERENCES gram_sabha (id), 
    CONSTRAINT fk_claim_call_created_by_user_id_app_user FOREIGN KEY(created_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_claim_call_gram_sabha_id ON claim_call (gram_sabha_id);

ALTER TABLE claim_case ADD COLUMN ack_serial VARCHAR(60);

ALTER TABLE claim_case ADD COLUMN acknowledged_on DATE;

ALTER TABLE claim_case ADD COLUMN claim_call_id UUID;

ALTER TABLE claim_case ADD CONSTRAINT fk_claim_case_claim_call_id_claim_call FOREIGN KEY(claim_call_id) REFERENCES claim_call (id);

ALTER TABLE claim_case ADD COLUMN filed_within_window BOOLEAN;

ALTER TABLE claim_case ADD CONSTRAINT uq_claim_case_ack_serial UNIQUE (gram_sabha_id, ack_serial);

CREATE TABLE media (
    id UUID NOT NULL, 
    sha256 VARCHAR(64) NOT NULL, 
    mime VARCHAR(100) NOT NULL, 
    size_bytes INTEGER NOT NULL, 
    original_name VARCHAR(300), 
    storage_key VARCHAR(300) NOT NULL, 
    uploaded_by_user_id UUID NOT NULL, 
    captured_at TIMESTAMP WITH TIME ZONE, 
    gps_lat FLOAT, 
    gps_lon FLOAT, 
    gps_accuracy_m FLOAT, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_media PRIMARY KEY (id), 
    CONSTRAINT fk_media_uploaded_by_user_id_app_user FOREIGN KEY(uploaded_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_media_sha256 ON media (sha256);

CREATE TABLE evidence (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    rule_ref evidence_rule NOT NULL, 
    kind evidence_kind NOT NULL, 
    description TEXT NOT NULL, 
    media_id UUID, 
    source_office VARCHAR(200), 
    ref_no VARCHAR(100), 
    doc_date DATE, 
    gps_lat FLOAT, 
    gps_lon FLOAT, 
    gps_accuracy_m FLOAT, 
    is_substitutable BOOLEAN NOT NULL, 
    elder_member_id UUID, 
    transcript TEXT, 
    signed_scan_media_id UUID, 
    supersedes_id UUID, 
    correction_reason TEXT, 
    added_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_evidence PRIMARY KEY (id), 
    CONSTRAINT fk_evidence_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_evidence_media_id_media FOREIGN KEY(media_id) REFERENCES media (id), 
    CONSTRAINT fk_evidence_elder_member_id_gs_member FOREIGN KEY(elder_member_id) REFERENCES gs_member (id), 
    CONSTRAINT fk_evidence_signed_scan_media_id_media FOREIGN KEY(signed_scan_media_id) REFERENCES media (id), 
    CONSTRAINT fk_evidence_supersedes_id_evidence FOREIGN KEY(supersedes_id) REFERENCES evidence (id), 
    CONSTRAINT fk_evidence_added_by_user_id_app_user FOREIGN KEY(added_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_evidence_case_id ON evidence (case_id);

CREATE TABLE evidence_verification (
    id UUID NOT NULL, 
    evidence_id UUID NOT NULL, 
    verified_by_user_id UUID NOT NULL, 
    verified_by_name VARCHAR(200) NOT NULL, 
    remarks TEXT, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_evidence_verification PRIMARY KEY (id), 
    CONSTRAINT fk_evidence_verification_evidence_id_evidence FOREIGN KEY(evidence_id) REFERENCES evidence (id), 
    CONSTRAINT fk_evidence_verification_verified_by_user_id_app_user FOREIGN KEY(verified_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_evidence_verification_evidence_id ON evidence_verification (evidence_id);

CREATE TABLE ledger_entry (
    id UUID NOT NULL, 
    gram_sabha_id UUID NOT NULL, 
    seq INTEGER NOT NULL, 
    entity VARCHAR(50) NOT NULL, 
    entity_id UUID NOT NULL, 
    prev_hash VARCHAR(64) NOT NULL, 
    record_hash VARCHAR(64) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_ledger_entry PRIMARY KEY (id), 
    CONSTRAINT uq_ledger_entry_seq UNIQUE (gram_sabha_id, seq), 
    CONSTRAINT fk_ledger_entry_gram_sabha_id_gram_sabha FOREIGN KEY(gram_sabha_id) REFERENCES gram_sabha (id)
);

CREATE INDEX ix_ledger_entry_gram_sabha_id ON ledger_entry (gram_sabha_id);

CREATE TABLE correspondence (
    id UUID NOT NULL, 
    gram_sabha_id UUID NOT NULL, 
    case_id UUID, 
    template letter_template NOT NULL, 
    addressee VARCHAR(300) NOT NULL, 
    subject VARCHAR(300) NOT NULL, 
    body TEXT, 
    neighbour_village VARCHAR(200), 
    records_requested VARCHAR(300)[] DEFAULT '{}' NOT NULL, 
    dispatched_on DATE, 
    reminder_on DATE, 
    response_received_on DATE, 
    outcome TEXT, 
    created_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_correspondence PRIMARY KEY (id), 
    CONSTRAINT fk_correspondence_gram_sabha_id_gram_sabha FOREIGN KEY(gram_sabha_id) REFERENCES gram_sabha (id), 
    CONSTRAINT fk_correspondence_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_correspondence_created_by_user_id_app_user FOREIGN KEY(created_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_correspondence_gram_sabha_id ON correspondence (gram_sabha_id);

CREATE INDEX ix_correspondence_case_id ON correspondence (case_id);

CREATE FUNCTION forbid_change() RETURNS trigger AS $$
        BEGIN
            RAISE EXCEPTION '% is append-only: % refused', TG_TABLE_NAME, TG_OP
                USING ERRCODE = 'restrict_violation';
        END;
        $$ LANGUAGE plpgsql;

CREATE TRIGGER evidence_append_only BEFORE UPDATE OR DELETE ON evidence FOR EACH ROW EXECUTE FUNCTION forbid_change();

CREATE TRIGGER evidence_verification_append_only BEFORE UPDATE OR DELETE ON evidence_verification FOR EACH ROW EXECUTE FUNCTION forbid_change();

CREATE TRIGGER ledger_entry_append_only BEFORE UPDATE OR DELETE ON ledger_entry FOR EACH ROW EXECUTE FUNCTION forbid_change();

CREATE TRIGGER workflow_event_append_only BEFORE UPDATE OR DELETE ON workflow_event FOR EACH ROW EXECUTE FUNCTION forbid_change();

UPDATE alembic_version SET version_num='0007' WHERE alembic_version.version_num = '0006';

COMMIT;

