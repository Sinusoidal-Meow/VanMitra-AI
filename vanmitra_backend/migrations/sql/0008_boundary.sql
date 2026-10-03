BEGIN;

-- Running upgrade 0007 -> 0008

CREATE TYPE boundary_status AS ENUM ('draft', 'gs_approved', 'titled');

CREATE TYPE use_zone_type AS ENUM ('grazing', 'mfp', 'water', 'fishing', 'fuelwood', 'sacred', 'shifting_cultivation', 'habitat', 'other');

CREATE TYPE dispute_outcome AS ENUM ('agreed_shared', 'agreed_adjusted', 'not_resolved');

CREATE TABLE cfr_boundary (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    version INTEGER NOT NULL, 
    geom geometry(POLYGON,4326) NOT NULL, 
    source VARCHAR(50) NOT NULL, 
    status boundary_status NOT NULL, 
    area_ha NUMERIC(12, 4) NOT NULL, 
    accuracy_stats JSONB NOT NULL, 
    is_current BOOLEAN NOT NULL, 
    sealed_hash VARCHAR(64), 
    approved_on DATE, 
    created_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_cfr_boundary PRIMARY KEY (id), 
    CONSTRAINT uq_cfr_boundary_version UNIQUE (case_id, version), 
    CONSTRAINT fk_cfr_boundary_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_cfr_boundary_created_by_user_id_app_user FOREIGN KEY(created_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_cfr_boundary_case_id ON cfr_boundary (case_id);

CREATE INDEX ix_cfr_boundary_geom ON cfr_boundary USING gist (geom);

CREATE TABLE boundary_segment (
    id UUID NOT NULL, 
    boundary_id UUID NOT NULL, 
    seq INTEGER NOT NULL, 
    geom geometry(LINESTRING,4326) NOT NULL, 
    length_m FLOAT NOT NULL, 
    CONSTRAINT pk_boundary_segment PRIMARY KEY (id), 
    CONSTRAINT uq_boundary_segment_seq UNIQUE (boundary_id, seq), 
    CONSTRAINT fk_boundary_segment_boundary_id_cfr_boundary FOREIGN KEY(boundary_id) REFERENCES cfr_boundary (id)
);

CREATE INDEX ix_boundary_segment_boundary_id ON boundary_segment (boundary_id);

CREATE TABLE boundary_landmark (
    id UUID NOT NULL, 
    boundary_id UUID NOT NULL, 
    segment_seq INTEGER NOT NULL, 
    name VARCHAR(200) NOT NULL, 
    kind landmark_kind NOT NULL, 
    point geometry(POINT,4326) NOT NULL, 
    photo_media_id UUID, 
    evidence_id UUID, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_boundary_landmark PRIMARY KEY (id), 
    CONSTRAINT fk_boundary_landmark_boundary_id_cfr_boundary FOREIGN KEY(boundary_id) REFERENCES cfr_boundary (id), 
    CONSTRAINT fk_boundary_landmark_photo_media_id_media FOREIGN KEY(photo_media_id) REFERENCES media (id), 
    CONSTRAINT fk_boundary_landmark_evidence_id_evidence FOREIGN KEY(evidence_id) REFERENCES evidence (id)
);

CREATE INDEX ix_boundary_landmark_boundary_id ON boundary_landmark (boundary_id);

CREATE TABLE use_zone (
    id UUID NOT NULL, 
    boundary_id UUID NOT NULL, 
    use_type use_zone_type NOT NULL, 
    name VARCHAR(200), 
    geom geometry(POLYGON,4326) NOT NULL, 
    area_ha NUMERIC(12, 4) NOT NULL, 
    season VARCHAR(100), 
    user_hamlets VARCHAR(200)[] DEFAULT '{}' NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_use_zone PRIMARY KEY (id), 
    CONSTRAINT fk_use_zone_boundary_id_cfr_boundary FOREIGN KEY(boundary_id) REFERENCES cfr_boundary (id)
);

CREATE INDEX ix_use_zone_boundary_id ON use_zone (boundary_id);

CREATE TABLE boundary_walk (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    walked_on DATE NOT NULL, 
    participants JSONB NOT NULL, 
    trace geometry(LINESTRING,4326), 
    notes TEXT, 
    created_by_user_id UUID NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_boundary_walk PRIMARY KEY (id), 
    CONSTRAINT fk_boundary_walk_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_boundary_walk_created_by_user_id_app_user FOREIGN KEY(created_by_user_id) REFERENCES app_user (id)
);

CREATE INDEX ix_boundary_walk_case_id ON boundary_walk (case_id);

CREATE TABLE dispute (
    id UUID NOT NULL, 
    case_id UUID NOT NULL, 
    neighbour_case_id UUID NOT NULL, 
    neighbour_gram_sabha_id UUID NOT NULL, 
    overlap_geom geometry(GEOMETRY,4326) NOT NULL, 
    overlap_ha NUMERIC(12, 4) NOT NULL, 
    detected_on DATE NOT NULL, 
    joint_meeting_on DATE, 
    joint_meeting_findings TEXT, 
    joint_meeting_media_id UUID, 
    outcome dispute_outcome, 
    sdlc_referral_on DATE, 
    sdlc_referral_ref VARCHAR(200), 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    CONSTRAINT pk_dispute PRIMARY KEY (id), 
    CONSTRAINT uq_dispute_pair UNIQUE (case_id, neighbour_case_id), 
    CONSTRAINT fk_dispute_case_id_claim_case FOREIGN KEY(case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_dispute_neighbour_case_id_claim_case FOREIGN KEY(neighbour_case_id) REFERENCES claim_case (id), 
    CONSTRAINT fk_dispute_neighbour_gram_sabha_id_gram_sabha FOREIGN KEY(neighbour_gram_sabha_id) REFERENCES gram_sabha (id), 
    CONSTRAINT fk_dispute_joint_meeting_media_id_media FOREIGN KEY(joint_meeting_media_id) REFERENCES media (id)
);

CREATE INDEX ix_dispute_case_id ON dispute (case_id);

CREATE INDEX ix_dispute_neighbour_case_id ON dispute (neighbour_case_id);

CREATE INDEX ix_dispute_overlap_geom ON dispute USING gist (overlap_geom);

UPDATE alembic_version SET version_num='0008' WHERE alembic_version.version_num = '0007';

COMMIT;

