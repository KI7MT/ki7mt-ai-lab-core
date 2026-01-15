-- ==============================================================================
-- Name..........: @PROGRAM@ - WSPR Raw Schema
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: 15-Column Immutable Raw Layer for WSPRnet CSV Exports
-- ==============================================================================
--
-- Standard 15-Column WSPR Schema (wsprnet.org archive format):
--   0: id          - Spot ID (unique per record)
--   1: timestamp   - Unix epoch or YYYYMMDD HHMM
--   2: reporter    - Receiving station callsign
--   3: reporter_grid - Receiver Maidenhead grid (4-6 chars)
--   4: snr         - Signal-to-noise ratio (dB)
--   5: frequency   - Frequency in Hz (e.g., 14097100)
--   6: callsign    - Transmitting station callsign
--   7: grid        - Transmitter Maidenhead grid (4-6 chars)
--   8: power       - TX power (dBm, 0-60)
--   9: drift       - Frequency drift (Hz/min)
--  10: distance    - Great circle distance (km)
--  11: azimuth     - Bearing from TX to RX (degrees 0-359)
--  12: band        - Band ID (maps to frequency range)
--  13: version     - WSPR software version
--  14: code        - Status/decode code
--
-- Type Optimizations for NVMe RAID-0:
--   - LowCardinality(String) for callsigns/grids (high repetition, ~500K unique)
--   - Date for date-only queries, DateTime for full precision
--   - UInt64 for frequency (Hz) - avoids floating-point precision loss at 10B rows
--   - Int8/UInt8 for small-range integers (reduces storage footprint)
-- ==============================================================================

-- 1. Create database
CREATE DATABASE IF NOT EXISTS wspr;

-- 2. Create the 15-column raw spots table
CREATE TABLE IF NOT EXISTS wspr.spots_raw (
    -- Spot identifier
    id UInt64,

    -- Timestamp (full precision for time-series analysis)
    timestamp DateTime,

    -- Reporter/Receiver station (LowCardinality for ~500K unique callsigns)
    reporter LowCardinality(String),
    reporter_grid LowCardinality(String),

    -- Signal metrics
    snr Int8,                          -- Range: -50 to +50 dB (Int8 sufficient)
    frequency UInt64,                  -- Hz precision (e.g., 14097100)

    -- Transmitter station (LowCardinality for repetition)
    callsign LowCardinality(String),
    grid LowCardinality(String),

    -- TX parameters
    power Int8,                        -- Range: 0-60 dBm (Int8 sufficient)
    drift Int8,                        -- Hz/min (Int8 sufficient)

    -- Propagation metrics
    distance UInt32,                   -- km (UInt32 supports global distances)
    azimuth UInt16,                    -- degrees 0-359

    -- Metadata
    band Int16,                        -- Band ID (Int16 for ADIF compatibility)
    version LowCardinality(String),    -- Software version (high repetition)
    code UInt8                         -- Status code (0-255)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, band, callsign)
SETTINGS index_granularity = 8192
COMMENT '@PROGRAM@ v@VERSION@ Immutable Raw 15-Column Table';

-- 3. Contract validation view (ensures schema consistency for downstream tools)
CREATE OR REPLACE VIEW wspr.v_contract_spots_raw AS
SELECT name, type, position
FROM system.columns
WHERE database = 'wspr' AND table = 'spots_raw'
ORDER BY position;

-- 4. Daily summary materialized view (optional, for quick date-range queries)
-- Uncomment if needed for dashboard/reporting use cases
-- CREATE MATERIALIZED VIEW IF NOT EXISTS wspr.mv_spots_daily
-- ENGINE = SummingMergeTree()
-- PARTITION BY toYYYYMM(day)
-- ORDER BY (day, band)
-- AS SELECT
--     toDate(timestamp) AS day,
--     band,
--     count() AS spot_count,
--     uniqExact(callsign) AS unique_tx,
--     uniqExact(reporter) AS unique_rx
-- FROM wspr.spots_raw
-- GROUP BY day, band;