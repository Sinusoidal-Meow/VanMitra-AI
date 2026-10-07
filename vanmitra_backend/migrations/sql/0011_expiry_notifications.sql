BEGIN;

-- Running upgrade 0010 -> 0011

ALTER TYPE case_state ADD VALUE IF NOT EXISTS 'expired';

ALTER TYPE workflow_action ADD VALUE IF NOT EXISTS 'expire';

ALTER TABLE workflow_event ALTER COLUMN actor_user_id DROP NOT NULL;

ALTER TABLE workflow_event ALTER COLUMN actor_role DROP NOT NULL;

CREATE TABLE notification (
    id UUID NOT NULL, 
    user_id UUID NOT NULL, 
    case_id UUID, 
    kind VARCHAR(40) NOT NULL, 
    title_en VARCHAR(200) NOT NULL, 
    body_en TEXT NOT NULL, 
    title_mr VARCHAR(200) NOT NULL, 
    body_mr TEXT NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    read_at TIMESTAMP WITH TIME ZONE, 
    CONSTRAINT pk_notification PRIMARY KEY (id), 
    CONSTRAINT fk_notification_user_id_app_user FOREIGN KEY(user_id) REFERENCES app_user (id), 
    CONSTRAINT fk_notification_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id)
);

CREATE INDEX ix_notification_user_id ON notification (user_id);

CREATE INDEX ix_notification_case_id ON notification (case_id);

UPDATE alembic_version SET version_num='0011' WHERE alembic_version.version_num = '0010';

COMMIT;

