BEGIN;

-- Running upgrade 0008 -> 0009

CREATE TABLE verification_proceeding (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    attempt_no INTEGER NOT NULL, 
    visit_on DATE NOT NULL, 
    intimation_id UUID, 
    observations TEXT NOT NULL, 
    presence JSONB NOT NULL, 
    forest_signed BOOLEAN NOT NULL, 
    forest_absence_recorded BOOLEAN NOT NULL, 
    revenue_signed BOOLEAN NOT NULL, 
    revenue_absence_recorded BOOLEAN NOT NULL, 
    signed_scan_media_id UUID, 
    recorded_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_verification_proceeding PRIMARY KEY (id), 
    CONSTRAINT uq_verification_attempt UNIQUE (case_id, attempt_no), 
    CONSTRAINT fk_verification_proceeding_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_verification_proceeding_intimation_id_correspondence FOREIGN KEY(intimation_id) REFERENCES correspondence (id), 
    CONSTRAINT fk_verification_proceeding_signed_scan_media_id_media FOREIGN KEY(signed_scan_media_id) REFERENCES media (id), 
    CONSTRAINT fk_verification_proceeding_recorded_by_user_id_app_user FOREIGN KEY(recorded_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_verification_proceeding_case_id ON verification_proceeding (case_id);

CREATE TABLE gs_meeting (
    id UUID NOT NULL, 
    gram_sabha_id UUID NOT NULL, 
    held_on DATE NOT NULL, 
    place VARCHAR(300) NOT NULL, 
    notice_on DATE, 
    agenda TEXT NOT NULL, 
    registered_count INTEGER NOT NULL, 
    created_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_gs_meeting PRIMARY KEY (id), 
    CONSTRAINT fk_gs_meeting_gram_sabha_id_gram_sabha FOREIGN KEY(gram_sabha_id) REFERENCES gram_sabha (id), 
    CONSTRAINT fk_gs_meeting_created_by_user_id_app_user FOREIGN KEY(created_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_gs_meeting_gram_sabha_id ON gs_meeting (gram_sabha_id);

CREATE TABLE attendance (
    id UUID NOT NULL, 
    meeting_id UUID NOT NULL, 
    gs_member_id UUID NOT NULL, 
    present BOOLEAN NOT NULL, 
    method VARCHAR(20) NOT NULL, 
    CONSTRAINT pk_attendance PRIMARY KEY (id), 
    CONSTRAINT uq_attendance_member UNIQUE (meeting_id, gs_member_id), 
    CONSTRAINT fk_attendance_meeting_id_gs_meeting FOREIGN KEY(meeting_id) REFERENCES gs_meeting (id), 
    CONSTRAINT fk_attendance_gs_member_id_gs_member FOREIGN KEY(gs_member_id) REFERENCES gs_member (id)
);

CREATE INDEX ix_attendance_meeting_id ON attendance (meeting_id);

CREATE TABLE resolution (
    id UUID NOT NULL, 
    gram_sabha_id UUID NOT NULL, 
    meeting_id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    number VARCHAR(40) NOT NULL, 
    decision_text TEXT NOT NULL, 
    votes_for INTEGER NOT NULL, 
    votes_against INTEGER NOT NULL, 
    boundary_id UUID, 
    quorum_proof JSONB NOT NULL, 
    signed_scan_media_id UUID, 
    supersedes_id UUID, 
    correction_reason TEXT, 
    created_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_resolution PRIMARY KEY (id), 
    CONSTRAINT uq_resolution_number UNIQUE (gram_sabha_id, number), 
    CONSTRAINT fk_resolution_gram_sabha_id_gram_sabha FOREIGN KEY(gram_sabha_id) REFERENCES gram_sabha (id), 
    CONSTRAINT fk_resolution_meeting_id_gs_meeting FOREIGN KEY(meeting_id) REFERENCES gs_meeting (id), 
    CONSTRAINT fk_resolution_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_resolution_boundary_id_cfr_boundary FOREIGN KEY(boundary_id) REFERENCES cfr_boundary (id), 
    CONSTRAINT fk_resolution_signed_scan_media_id_media FOREIGN KEY(signed_scan_media_id) REFERENCES media (id), 
    CONSTRAINT fk_resolution_supersedes_id_resolution FOREIGN KEY(supersedes_id) REFERENCES resolution (id), 
    CONSTRAINT fk_resolution_created_by_user_id_app_user FOREIGN KEY(created_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_resolution_gram_sabha_id ON resolution (gram_sabha_id);

CREATE INDEX ix_resolution_meeting_id ON resolution (meeting_id);

CREATE INDEX ix_resolution_case_id ON resolution (case_id);

CREATE TRIGGER verification_proceeding_append_only BEFORE UPDATE OR DELETE ON verification_proceeding FOR EACH ROW EXECUTE FUNCTION forbid_change();

CREATE TRIGGER resolution_append_only BEFORE UPDATE OR DELETE ON resolution FOR EACH ROW EXECUTE FUNCTION forbid_change();

UPDATE alembic_version SET version_num='0009' WHERE alembic_version.version_num = '0008';

COMMIT;

