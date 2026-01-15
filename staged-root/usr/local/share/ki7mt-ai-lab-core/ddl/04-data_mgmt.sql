-- ==============================================================================
-- Name..........: ki7mt-ai-lab-core - Management Schema
-- Description...: DB-Centric Configuration for Lab Workers
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS data_mgmt;

CREATE TABLE IF NOT EXISTS data_mgmt.config (
    key String,
    value String,
    updated_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY key
COMMENT 'ki7mt-ai-lab-core v1.0.0 Configuration Table';
