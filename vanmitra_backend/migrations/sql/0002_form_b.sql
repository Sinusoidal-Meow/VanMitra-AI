BEGIN;

-- Running upgrade 0001 -> 0002

CREATE TYPE claim_type AS ENUM ('ifr', 'cr', 'cfr');

CREATE TYPE case_state AS ENUM ('draft', 'evidence_collection', 'mapping_in_progress', 'dispute_joint_hearing', 'frc_verification', 'gs_ready', 'gs_resolved', 'submitted_sdlc', 'sdlc_under_exam', 'sdlc_forwarded', 'dlc_under_consideration', 'remanded_to_gs', 'modified_rejected', 'petition_filed', 'title_approved', 'survey_pending', 'record_updated', 'cfr_active');

CREATE TYPE form_b_right_code AS ENUM ('nistar', 'minor_forest_produce', 'water_bodies', 'grazing', 'nomadic_pastoral_access', 'habitat', 'biodiversity_knowledge', 'other_traditional');

CREATE TYPE evidence_rule AS ENUM ('13(1)(a)', '13(1)(b)', '13(1)(c)', '13(1)(d)', '13(1)(e)', '13(1)(f)', '13(1)(g)', '13(1)(h)', '13(1)(i)', '13(2)(a)', '13(2)(b)', '13(2)(c)', '13(2)(d)', '13(2)(e)');

CREATE TABLE claim_case (
    id UUID NOT NULL, 
    gram_sabha_id UUID NOT NULL, 
    claim_type claim_type NOT NULL, 
    state case_state NOT NULL, 
    created_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_claim_case PRIMARY KEY (id), 
    CONSTRAINT fk_claim_case_gram_sabha_id_gram_sabha FOREIGN KEY(gram_sabha_id) REFERENCES gram_sabha (id), 
    CONSTRAINT fk_claim_case_created_by_user_id_app_user FOREIGN KEY(created_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_claim_case_gram_sabha_id ON claim_case (gram_sabha_id);

CREATE TABLE form_b (
    case_id UUID NOT NULL, 
    claimant_names VARCHAR(200)[] DEFAULT '{}' NOT NULL, 
    is_fdst_community BOOLEAN, 
    is_otfd_community BOOLEAN, 
    other_information TEXT, 
    updated_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_form_b PRIMARY KEY (case_id), 
    CONSTRAINT fk_form_b_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_form_b_updated_by_user_id_app_user FOREIGN KEY(updated_by_user_id) REFERENCES app_user (id)
);

CREATE TABLE form_b_right (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    right_code form_b_right_code NOT NULL, 
    details TEXT NOT NULL, 
    items VARCHAR(200)[] DEFAULT '{}' NOT NULL, 
    CONSTRAINT pk_form_b_right PRIMARY KEY (id), 
    CONSTRAINT uq_form_b_right_code UNIQUE (case_id, right_code), 
    CONSTRAINT fk_form_b_right_case_id_form_b FOREIGN KEY(case_id) REFERENCES form_b (case_id)
);

CREATE INDEX ix_form_b_right_case_id ON form_b_right (case_id);

CREATE TABLE claim_evidence_entry (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    seq INTEGER NOT NULL, 
    rule_ref evidence_rule NOT NULL, 
    description TEXT NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_claim_evidence_entry PRIMARY KEY (id), 
    CONSTRAINT uq_claim_evidence_entry_seq UNIQUE (case_id, seq), 
    CONSTRAINT fk_claim_evidence_entry_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id)
);

CREATE INDEX ix_claim_evidence_entry_case_id ON claim_evidence_entry (case_id);

UPDATE alembic_version SET version_num='0002' WHERE alembic_version.version_num = '0001';

COMMIT;

