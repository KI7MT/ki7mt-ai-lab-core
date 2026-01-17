-- ==============================================================================
-- Name..........: @PROGRAM@ - Lab Version Tracking
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Tracks deployed component versions for live status checks
-- ==============================================================================
--
-- This table is used by `version-manager live` to compare:
--   - Spec file version (intended)
--   - RPM installed version (system)
--   - Database stamped version (this table)
--
-- Usage:
--   INSERT INTO data_mgmt.lab_versions (component, version)
--   VALUES ('ki7mt-ai-lab-core', '1.1.6');
--
-- Query latest:
--   SELECT component, version, installed_at
--   FROM data_mgmt.lab_versions
--   ORDER BY installed_at DESC
--   LIMIT 10;
-- ==============================================================================

-- Ensure data_mgmt database exists (created in 04-data_mgmt.sql)
CREATE DATABASE IF NOT EXISTS data_mgmt;

-- Version tracking table
CREATE TABLE IF NOT EXISTS data_mgmt.lab_versions (
    component String,
    version String,
    installed_at DateTime DEFAULT now(),
    installed_by String DEFAULT currentUser(),
    notes String DEFAULT ''
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(installed_at)
ORDER BY (component, installed_at)
COMMENT '@PROGRAM@ v@VERSION@ Component Version Tracking';

-- View for latest version per component
CREATE OR REPLACE VIEW data_mgmt.v_lab_versions_latest AS
SELECT
    component,
    argMax(version, installed_at) AS version,
    max(installed_at) AS installed_at,
    argMax(installed_by, installed_at) AS installed_by
FROM data_mgmt.lab_versions
GROUP BY component
ORDER BY component;
