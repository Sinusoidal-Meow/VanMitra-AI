BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL, 
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> 0001

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TYPE consolidation_status AS ENUM ('recognised', 'listed', 'consolidated', 'finalised');

CREATE TYPE gender AS ENUM ('female', 'male', 'other');

CREATE TYPE member_category AS ENUM ('st', 'otfd', 'other');

CREATE TYPE app_role AS ENUM ('facilitator', 'frc_member', 'gs_secretary');

CREATE TABLE village (
    id UUID NOT NULL, 
    lgd_code VARCHAR(20), 
    name_mr VARCHAR(200) NOT NULL, 
    name_en VARCHAR(200) NOT NULL, 
    gram_panchayat VARCHAR(200) NOT NULL, 
    taluka VARCHAR(100) NOT NULL, 
    district VARCHAR(100) NOT NULL, 
    state VARCHAR(100) NOT NULL, 
    parent_village_id UUID, 
    consolidation_status consolidation_status NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_village PRIMARY KEY (id), 
    CONSTRAINT uq_village_lgd_code UNIQUE (lgd_code), 
    CONSTRAINT fk_village_parent_village_id_village FOREIGN KEY(parent_village_id) REFERENCES village (id)
);

CREATE TABLE gram_sabha (
    id UUID NOT NULL, 
    village_id UUID NOT NULL, 
    chain_head_hash VARCHAR(64), 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_gram_sabha PRIMARY KEY (id), 
    CONSTRAINT uq_gram_sabha_village_id UNIQUE (village_id), 
    CONSTRAINT fk_gram_sabha_village_id_village FOREIGN KEY(village_id) REFERENCES village (id)
);

CREATE TABLE gs_member (
    id UUID NOT NULL, 
    gram_sabha_id UUID NOT NULL, 
    name VARCHAR(200) NOT NULL, 
    gender gender NOT NULL, 
    category member_category NOT NULL, 
    active BOOLEAN NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_gs_member PRIMARY KEY (id), 
    CONSTRAINT fk_gs_member_gram_sabha_id_gram_sabha FOREIGN KEY(gram_sabha_id) REFERENCES gram_sabha (id)
);

CREATE INDEX ix_gs_member_gram_sabha_id ON gs_member (gram_sabha_id);

CREATE TABLE app_user (
    id UUID NOT NULL, 
    phone VARCHAR(15) NOT NULL, 
    pin_hash VARCHAR(255) NOT NULL, 
    name VARCHAR(200) NOT NULL, 
    gs_member_id UUID, 
    is_admin BOOLEAN NOT NULL, 
    is_active BOOLEAN NOT NULL, 
    last_login_at TIMESTAMP WITH TIME ZONE, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_app_user PRIMARY KEY (id), 
    CONSTRAINT uq_app_user_phone UNIQUE (phone), 
    CONSTRAINT fk_app_user_gs_member_id_gs_member FOREIGN KEY(gs_member_id) REFERENCES gs_member (id)
);

CREATE TABLE user_role (
    id UUID NOT NULL, 
    user_id UUID NOT NULL, 
    village_id UUID NOT NULL, 
    role app_role NOT NULL, 
    valid_from DATE DEFAULT CURRENT_DATE NOT NULL, 
    valid_to DATE, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_user_role PRIMARY KEY (id), 
    CONSTRAINT uq_user_role_grant UNIQUE (user_id, village_id, role, valid_from), 
    CONSTRAINT ck_user_role_valid_range CHECK (valid_to IS NULL OR valid_to >= valid_from), 
    CONSTRAINT fk_user_role_user_id_app_user FOREIGN KEY(user_id) REFERENCES app_user (id), 
    CONSTRAINT fk_user_role_village_id_village FOREIGN KEY(village_id) REFERENCES village (id)
);

CREATE INDEX ix_user_role_user_id ON user_role (user_id);

CREATE INDEX ix_user_role_village_id ON user_role (village_id);

INSERT INTO alembic_version (version_num) VALUES ('0001') RETURNING alembic_version.version_num;

COMMIT;

