-- ==============================================================================
-- Name..........: @PROGRAM@ - Management Schema
-- Description...: DB-Centric Configuration for Lab Workers
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS data_mgmt;

CREATE TABLE IF NOT EXISTS data_mgmt.config (
    key String,
    value String,
    updated_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY key
COMMENT '@PROGRAM@ v@VERSION@ Configuration Table';