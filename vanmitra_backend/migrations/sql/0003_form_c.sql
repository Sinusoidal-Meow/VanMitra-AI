BEGIN;

-- Running upgrade 0002 -> 0003

CREATE TYPE boundary_side AS ENUM ('east', 'west', 'north', 'south', 'within');

CREATE TYPE landmark_kind AS ENUM ('river', 'stream', 'spring', 'pond', 'sacred_place', 'sacred_grove', 'burial_ground', 'well', 'road', 'compartment_pillar', 'hill', 'other');

CREATE TABLE form_c (
    case_id UUID NOT NULL, 
    resolution_statement TEXT NOT NULL, 
    area_description TEXT, 
    approx_area_ha NUMERIC(12, 2), 
    pastoral_seasonal_use BOOLEAN DEFAULT false NOT NULL, 
    seasonal_use_details TEXT, 
    khasra_compartment_numbers VARCHAR(50)[] DEFAULT '{}' NOT NULL, 
    updated_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_form_c PRIMARY KEY (case_id), 
    CONSTRAINT fk_form_c_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_form_c_updated_by_user_id_app_user FOREIGN KEY(updated_by_user_id) REFERENCES app_user (id)
);

CREATE TABLE form_c_landmark (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    seq INTEGER NOT NULL, 
    side boundary_side NOT NULL, 
    kind landmark_kind NOT NULL, 
    name VARCHAR(200) NOT NULL, 
    description TEXT, 
    CONSTRAINT pk_form_c_landmark PRIMARY KEY (id), 
    CONSTRAINT uq_form_c_landmark_seq UNIQUE (case_id, seq), 
    CONSTRAINT fk_form_c_landmark_case_id_form_c FOREIGN KEY(case_id) REFERENCES form_c (case_id)
);

CREATE INDEX ix_form_c_landmark_case_id ON form_c_landmark (case_id);

CREATE TABLE form_c_bordering_village (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    seq INTEGER NOT NULL, 
    name VARCHAR(200) NOT NULL, 
    shares_resources BOOLEAN DEFAULT false NOT NULL, 
    sharing_details TEXT, 
    CONSTRAINT pk_form_c_bordering_village PRIMARY KEY (id), 
    CONSTRAINT uq_form_c_bordering_village_seq UNIQUE (case_id, seq), 
    CONSTRAINT fk_form_c_bordering_village_case_id_form_c FOREIGN KEY(case_id) REFERENCES form_c (case_id)
);

CREATE INDEX ix_form_c_bordering_village_case_id ON form_c_bordering_village (case_id);

UPDATE alembic_version SET version_num='0003' WHERE alembic_version.version_num = '0002';

COMMIT;

