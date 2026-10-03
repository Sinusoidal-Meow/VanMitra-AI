BEGIN;

-- Running upgrade 0005 -> 0006

CREATE TABLE frc (
    id UUID NOT NULL, 
    gram_sabha_id UUID NOT NULL, 
    constituted_on DATE NOT NULL, 
    resolution_ref VARCHAR(200), 
    sdlc_intimated_on DATE, 
    composition_proof JSONB NOT NULL, 
    is_current BOOLEAN NOT NULL, 
    created_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_frc PRIMARY KEY (id), 
    CONSTRAINT fk_frc_gram_sabha_id_gram_sabha FOREIGN KEY(gram_sabha_id) REFERENCES gram_sabha (id), 
    CONSTRAINT fk_frc_created_by_user_id_app_user FOREIGN KEY(created_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_frc_gram_sabha_id ON frc (gram_sabha_id);

CREATE TABLE frc_member (
    id UUID NOT NULL, 
    frc_id UUID NOT NULL, 
    gs_member_id UUID NOT NULL, 
    is_chair BOOLEAN NOT NULL, 
    is_secretary BOOLEAN NOT NULL, 
    CONSTRAINT pk_frc_member PRIMARY KEY (id), 
    CONSTRAINT uq_frc_member_member UNIQUE (frc_id, gs_member_id), 
    CONSTRAINT fk_frc_member_frc_id_frc FOREIGN KEY(frc_id) REFERENCES frc (id), 
    CONSTRAINT fk_frc_member_gs_member_id_gs_member FOREIGN KEY(gs_member_id) REFERENCES gs_member (id)
);

CREATE INDEX ix_frc_member_frc_id ON frc_member (frc_id);

CREATE TABLE case_claimant (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    gs_member_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_case_claimant PRIMARY KEY (id), 
    CONSTRAINT uq_case_claimant_member UNIQUE (case_id, gs_member_id), 
    CONSTRAINT fk_case_claimant_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_case_claimant_gs_member_id_gs_member FOREIGN KEY(gs_member_id) REFERENCES gs_member (id)
);

CREATE INDEX ix_case_claimant_case_id ON case_claimant (case_id);

CREATE TABLE recusal (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    gs_member_id UUID NOT NULL, 
    reason TEXT NOT NULL, 
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_recusal PRIMARY KEY (id), 
    CONSTRAINT uq_recusal_member UNIQUE (case_id, gs_member_id), 
    CONSTRAINT fk_recusal_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_recusal_gs_member_id_gs_member FOREIGN KEY(gs_member_id) REFERENCES gs_member (id)
);

CREATE INDEX ix_recusal_case_id ON recusal (case_id);

UPDATE alembic_version SET version_num='0006' WHERE alembic_version.version_num = '0005';

COMMIT;

