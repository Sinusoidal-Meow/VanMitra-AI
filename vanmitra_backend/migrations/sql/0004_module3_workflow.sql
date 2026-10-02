BEGIN;

-- Running upgrade 0003 -> 0004

ALTER TYPE app_role RENAME TO app_role_old;

CREATE TYPE app_role AS ENUM ('villager', 'gram_sabha', 'sdo', 'collector', 'dfo', 'tribal_welfare_officer');

ALTER TABLE user_role ALTER COLUMN role TYPE app_role USING (CASE role::text WHEN 'gs_secretary' THEN 'gram_sabha' ELSE 'villager' END)::app_role;

DROP TYPE app_role_old;

ALTER TABLE user_role ALTER COLUMN village_id DROP NOT NULL;

ALTER TABLE user_role ADD COLUMN taluka VARCHAR(100);

ALTER TABLE user_role ADD COLUMN district VARCHAR(100);

ALTER TABLE user_role ADD CONSTRAINT ck_user_role_scope CHECK ((role IN ('villager', 'gram_sabha') AND village_id IS NOT NULL) OR (role = 'sdo' AND taluka IS NOT NULL AND district IS NOT NULL) OR (role IN ('collector', 'dfo', 'tribal_welfare_officer') AND district IS NOT NULL));

ALTER TYPE case_state RENAME TO case_state_old;

CREATE TYPE case_state AS ENUM ('draft', 'gs_review', 'sdo_review', 'district_review', 'title_issued', 'rejected');

ALTER TABLE claim_case ALTER COLUMN state TYPE case_state USING (CASE state::text WHEN 'gs_ready' THEN 'gs_review' WHEN 'gs_resolved' THEN 'gs_review' WHEN 'remanded_to_gs' THEN 'gs_review' WHEN 'submitted_sdlc' THEN 'sdo_review' WHEN 'sdlc_under_exam' THEN 'sdo_review' WHEN 'petition_filed' THEN 'sdo_review' WHEN 'sdlc_forwarded' THEN 'district_review' WHEN 'dlc_under_consideration' THEN 'district_review' WHEN 'title_approved' THEN 'title_issued' WHEN 'survey_pending' THEN 'title_issued' WHEN 'record_updated' THEN 'title_issued' WHEN 'cfr_active' THEN 'title_issued' WHEN 'modified_rejected' THEN 'rejected' ELSE 'draft' END)::case_state;

DROP TYPE case_state_old;

ALTER TABLE claim_case ADD COLUMN reached_stage SMALLINT DEFAULT 0 NOT NULL;

UPDATE claim_case SET reached_stage = CASE state::text WHEN 'gs_review' THEN 1 WHEN 'sdo_review' THEN 2 WHEN 'district_review' THEN 3 WHEN 'title_issued' THEN 4 ELSE 0 END;

CREATE TYPE workflow_action AS ENUM ('submit', 'approve', 'return', 'reject');

CREATE TYPE form_a_claim_code AS ENUM ('habitation', 'self_cultivation', 'disputed_land', 'patta_lease_grant', 'in_situ_rehabilitation', 'displaced_without_compensation', 'forest_village', 'other_traditional');

CREATE TABLE form_a (
    case_id UUID NOT NULL, 
    claimant_names VARCHAR(200)[] DEFAULT '{}' NOT NULL, 
    spouse_name VARCHAR(200), 
    father_mother_name VARCHAR(200), 
    address TEXT, 
    is_scheduled_tribe BOOLEAN, 
    is_otfd BOOLEAN, 
    spouse_is_scheduled_tribe BOOLEAN, 
    other_information TEXT, 
    updated_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_form_a PRIMARY KEY (case_id), 
    CONSTRAINT fk_form_a_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_form_a_updated_by_user_id_app_user FOREIGN KEY(updated_by_user_id) REFERENCES app_user (id)
);

CREATE TABLE form_a_family_member (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    seq INTEGER NOT NULL, 
    name VARCHAR(200) NOT NULL, 
    age SMALLINT, 
    relation VARCHAR(100), 
    CONSTRAINT pk_form_a_family_member PRIMARY KEY (id), 
    CONSTRAINT uq_form_a_family_member_seq UNIQUE (case_id, seq), 
    CONSTRAINT fk_form_a_family_member_case_id_form_a FOREIGN KEY(case_id) REFERENCES form_a (case_id)
);

CREATE INDEX ix_form_a_family_member_case_id ON form_a_family_member (case_id);

CREATE TABLE form_a_claim (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    claim_code form_a_claim_code NOT NULL, 
    extent_ha NUMERIC(10, 2), 
    details TEXT NOT NULL, 
    CONSTRAINT pk_form_a_claim PRIMARY KEY (id), 
    CONSTRAINT uq_form_a_claim_code UNIQUE (case_id, claim_code), 
    CONSTRAINT fk_form_a_claim_case_id_form_a FOREIGN KEY(case_id) REFERENCES form_a (case_id)
);

CREATE INDEX ix_form_a_claim_case_id ON form_a_claim (case_id);

CREATE TABLE workflow_event (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    action workflow_action NOT NULL, 
    from_state case_state NOT NULL, 
    to_state case_state NOT NULL, 
    actor_user_id UUID NOT NULL, 
    actor_role app_role NOT NULL, 
    actor_name VARCHAR(200) NOT NULL, 
    remarks TEXT, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_workflow_event PRIMARY KEY (id), 
    CONSTRAINT fk_workflow_event_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_workflow_event_actor_user_id_app_user FOREIGN KEY(actor_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_workflow_event_case_id ON workflow_event (case_id);

UPDATE alembic_version SET version_num='0004' WHERE alembic_version.version_num = '0003';

COMMIT;

