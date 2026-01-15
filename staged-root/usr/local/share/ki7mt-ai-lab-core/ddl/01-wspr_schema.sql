-- ==============================================================================
-- Name..........: ki7mt-ai-lab-core - WSPR Raw Schema
-- Version.......: 1.0.0
-- Copyright.....: Copyright (C) 2014-2026 Greg Beam, KI7MT
-- Description...: 15-Column Immutable Raw Layer for WSPRnet CSV Exports
-- ==============================================================================

--
CREATE DATABASE IF NOT EXISTS wspr;

--
CREATE TABLE IF NOT EXISTS wspr.spots_raw (
    id UInt64,
    timestamp DateTime,
    reporter String,
    reporter_grid String,
    snr Int8,
    frequency Float64,
    callsign String,
    grid String,
    power Int8,
    drift Int8,
    distance UInt32,
    azimuth UInt16,
    band Int8,
    version LowCardinality(String),
    code UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, band, callsign)
SETTINGS index_granularity = 8192
COMMENT 'ki7mt-ai-lab-core v1.0.0 Immutable Raw 15-Column Table';

-- Interface View for App Contract Validation
CREATE OR REPLACE VIEW wspr.v_contract_spots_raw AS
SELECT name, type, position
FROM system.columns
WHERE database = 'wspr' AND table = 'spots_raw'
ORDER BY position;
