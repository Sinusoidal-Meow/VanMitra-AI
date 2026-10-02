BEGIN;

-- Running upgrade 0004 -> 0005

ALTER TABLE form_b_right ADD COLUMN survey_compartment_numbers VARCHAR(50)[] DEFAULT '{}' NOT NULL;

ALTER TABLE form_b_right ADD COLUMN total_area_ha NUMERIC(12, 2);

ALTER TABLE form_b_right ADD COLUMN common_use_area_ha NUMERIC(12, 2);

ALTER TABLE form_b_right ADD COLUMN boundary_east VARCHAR(200);

ALTER TABLE form_b_right ADD COLUMN boundary_west VARCHAR(200);

ALTER TABLE form_b_right ADD COLUMN boundary_north VARCHAR(200);

ALTER TABLE form_b_right ADD COLUMN boundary_south VARCHAR(200);

ALTER TABLE form_b_right ADD COLUMN annual_quantity TEXT;

UPDATE alembic_version SET version_num='0005' WHERE alembic_version.version_num = '0004';

COMMIT;

