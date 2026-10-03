BEGIN;

-- Running upgrade 0009 -> 0010

CREATE TABLE title_followup (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    certified_copy_media_id UUID, 
    certified_copy_on DATE, 
    survey_letter_id UUID, 
    survey_done_on DATE, 
    record_entry_on DATE, 
    record_entry_ref VARCHAR(200), 
    record_entry_media_id UUID, 
    closed_on DATE, 
    updated_by_user_id UUID NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_title_followup PRIMARY KEY (id), 
    CONSTRAINT uq_title_followup_case_id UNIQUE (case_id), 
    CONSTRAINT fk_title_followup_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_title_followup_certified_copy_media_id_media FOREIGN KEY(certified_copy_media_id) REFERENCES media (id), 
    CONSTRAINT fk_title_followup_survey_letter_id_correspondence FOREIGN KEY(survey_letter_id) REFERENCES correspondence (id), 
    CONSTRAINT fk_title_followup_record_entry_media_id_media FOREIGN KEY(record_entry_media_id) REFERENCES media (id), 
    CONSTRAINT fk_title_followup_updated_by_user_id_app_user FOREIGN KEY(updated_by_user_id) REFERENCES app_user (id)
);

UPDATE alembic_version SET version_num='0010' WHERE alembic_version.version_num = '0009';

COMMIT;

