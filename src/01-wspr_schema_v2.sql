-- ==============================================================================
-- Name..........: @PROGRAM@ - WSPR Raw Schema v2
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: 17-Column Schema Synchronized with C/CUDA Memory Layout
-- ==============================================================================
--
-- SCHEMA VERSION: 2.0
-- SYNCHRONIZED WITH: ki7mt-ai-lab-cuda/src/cuda/wspr_structs.h
--
-- CRITICAL: This schema MUST match the WSPRSpot C struct exactly!
--   - Column ORDER must match struct field order
--   - FixedString(N) maps to char[N] in C for direct memory transfer
--   - DateTime maps to uint32_t (Unix seconds) in C
--
-- Memory Layout (128 bytes per row for GPU vectorization):
--   Offset   0: id             UInt64          (8 bytes)
--   Offset   8: timestamp      DateTime        (4 bytes, stored as UInt32)
--   Offset  12: [C padding]                    (4 bytes, not in DB)
--   Offset  16: reporter       FixedString(16) (16 bytes)
--   Offset  32: reporter_grid  FixedString(8)  (8 bytes)
--   Offset  40: snr            Int8            (1 byte)
--   Offset  41: [C padding]                    (7 bytes, not in DB)
--   Offset  48: frequency      UInt64          (8 bytes, Hz NOT MHz!)
--   Offset  56: callsign       FixedString(16) (16 bytes)
--   Offset  72: grid           FixedString(8)  (8 bytes)
--   Offset  80: power          Int8            (1 byte)
--   Offset  81: drift          Int8            (1 byte)
--   Offset  82: [C padding]                    (2 bytes, not in DB)
--   Offset  84: distance       UInt32          (4 bytes)
--   Offset  88: azimuth        UInt16          (2 bytes)
--   Offset  90: [C padding]                    (2 bytes, not in DB)
--   Offset  92: band           Int32           (4 bytes)
--   Offset  96: mode           FixedString(8)  (8 bytes)
--   Offset 104: version        FixedString(8)  (8 bytes)
--   Offset 112: code           UInt8           (1 byte)
--   Offset 113: column_count   UInt8           (1 byte)
--   Offset 114: [C padding]                    (14 bytes, not in DB)
--
-- NOTE: C struct padding fields (_pad1-_pad5) are NOT stored in ClickHouse.
--       The CUDA ingestion pipeline must strip padding before INSERT.
--
-- ==============================================================================

-- 1. Create database if not exists
CREATE DATABASE IF NOT EXISTS wspr;

-- 2. Drop existing table if schema migration required
-- UNCOMMENT ONLY FOR MIGRATION (will delete all data!)
-- DROP TABLE IF EXISTS wspr.spots_raw;

-- 3. Create the 17-column raw spots table (v2 schema)
CREATE TABLE IF NOT EXISTS wspr.spots_raw (
    -- ========================================================================
    -- Column 1: Spot Identifier (Offset 0 in C struct)
    -- ========================================================================
    id UInt64 COMMENT 'WSPRnet spot ID (maps to uint64_t id)',

    -- ========================================================================
    -- Column 2: Timestamp (Offset 8 in C struct)
    -- ========================================================================
    -- DateTime is stored as UInt32 internally (Unix seconds since 1970)
    -- C struct uses uint32_t timestamp for direct memory mapping
    timestamp DateTime COMMENT 'Spot timestamp UTC (maps to uint32_t timestamp)',

    -- ========================================================================
    -- Columns 3-4: Reporter Station (Offset 16, 32 in C struct)
    -- ========================================================================
    -- FixedString(N) stores exactly N bytes, no length prefix
    -- Maps directly to char[N] in C for zero-copy GPU transfer
    reporter FixedString(16) COMMENT 'Receiving station callsign (maps to char[16])',
    reporter_grid FixedString(8) COMMENT 'Receiver Maidenhead grid (maps to char[8])',

    -- ========================================================================
    -- Column 5: Signal Metrics (Offset 40 in C struct)
    -- ========================================================================
    snr Int8 COMMENT 'Signal-to-noise ratio dB, range -50 to +50 (maps to int8_t)',

    -- ========================================================================
    -- Column 6: Frequency (Offset 48 in C struct)
    -- ========================================================================
    -- CRITICAL: Stored in Hz (NOT MHz!) to avoid floating-point precision loss
    -- Example: 14.097100 MHz = 14097100 Hz
    -- C struct uses uint64_t for direct memory mapping
    frequency UInt64 COMMENT 'Frequency in Hz (maps to uint64_t, NOT double!)',

    -- ========================================================================
    -- Columns 7-8: Transmitter Station (Offset 56, 72 in C struct)
    -- ========================================================================
    callsign FixedString(16) COMMENT 'Transmitting station callsign (maps to char[16])',
    grid FixedString(8) COMMENT 'Transmitter Maidenhead grid (maps to char[8])',

    -- ========================================================================
    -- Columns 9-12: TX Parameters and Propagation (Offset 80-91 in C struct)
    -- ========================================================================
    power Int8 COMMENT 'TX power in dBm, range 0-60 (maps to int8_t)',
    drift Int8 COMMENT 'Frequency drift Hz/min (maps to int8_t)',
    distance UInt32 COMMENT 'Great circle distance in km (maps to uint32_t)',
    azimuth UInt16 COMMENT 'Bearing from TX to RX in degrees 0-359 (maps to uint16_t)',

    -- ========================================================================
    -- Column 13: Band (Offset 92 in C struct)
    -- ========================================================================
    -- CHANGED FROM v1: Int16 -> Int32 to match C struct and live database
    band Int32 COMMENT 'ADIF band ID (maps to int32_t)',

    -- ========================================================================
    -- Columns 14-15: Mode and Version (Offset 96, 104 in C struct)
    -- ========================================================================
    -- NEW IN v2: mode column added for schema completeness
    mode FixedString(8) COMMENT 'WSPR mode e.g. WSPR, WSPR-15 (maps to char[8])',
    version FixedString(8) COMMENT 'WSPR software version (maps to char[8])',

    -- ========================================================================
    -- Columns 16-17: Status Codes (Offset 112, 113 in C struct)
    -- ========================================================================
    code UInt8 COMMENT 'Status/decode code (maps to uint8_t)',
    -- NEW IN v2: column_count for CSV validation
    column_count UInt8 COMMENT 'Original CSV column count for validation (maps to uint8_t)'

) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, band, callsign)
SETTINGS index_granularity = 8192
COMMENT '@PROGRAM@ v@VERSION@ Schema v2 - 17 Columns - Synchronized with wspr_structs.h';


-- ==============================================================================
-- 4. Migration Support: ALTER TABLE for existing v1 installations
-- ==============================================================================
-- Run these statements ONLY if upgrading from v1 schema to v2 schema.
-- They are idempotent (safe to run multiple times).

-- Add mode column if missing (default to 'WSPR' for existing rows)
ALTER TABLE wspr.spots_raw
    ADD COLUMN IF NOT EXISTS mode FixedString(8) DEFAULT 'WSPR'
    COMMENT 'WSPR mode e.g. WSPR, WSPR-15 (maps to char[8])'
    AFTER band;

-- Add column_count if missing (default to 15 for legacy data)
ALTER TABLE wspr.spots_raw
    ADD COLUMN IF NOT EXISTS column_count UInt8 DEFAULT 15
    COMMENT 'Original CSV column count for validation (maps to uint8_t)'
    AFTER code;

-- Fix band type if it was Int16 (requires MODIFY COLUMN)
-- NOTE: This is a metadata-only change in ClickHouse, data is reinterpreted
ALTER TABLE wspr.spots_raw
    MODIFY COLUMN IF EXISTS band Int32
    COMMENT 'ADIF band ID (maps to int32_t)';

-- Convert String columns to FixedString if upgrading from v1
-- WARNING: These conversions may fail if existing data exceeds FixedString length!
-- Run SELECT max(length(reporter)) FROM wspr.spots_raw; first to verify

-- ALTER TABLE wspr.spots_raw MODIFY COLUMN reporter FixedString(16);
-- ALTER TABLE wspr.spots_raw MODIFY COLUMN reporter_grid FixedString(8);
-- ALTER TABLE wspr.spots_raw MODIFY COLUMN callsign FixedString(16);
-- ALTER TABLE wspr.spots_raw MODIFY COLUMN grid FixedString(8);
-- ALTER TABLE wspr.spots_raw MODIFY COLUMN version FixedString(8);


-- ==============================================================================
-- 5. Schema Contract View (verifies column order and types)
-- ==============================================================================
CREATE OR REPLACE VIEW wspr.v_schema_contract AS
SELECT
    position,
    name,
    type,
    comment
FROM system.columns
WHERE database = 'wspr' AND table = 'spots_raw'
ORDER BY position;


-- ==============================================================================
-- 6. Schema Validation Function
-- ==============================================================================
-- Returns 1 if schema matches expected v2 layout, 0 otherwise
CREATE OR REPLACE FUNCTION wspr.fn_validate_schema_v2() AS () ->
(
    SELECT if(
        -- Check all 17 columns exist with correct types
        countIf(name = 'id' AND type = 'UInt64') = 1 AND
        countIf(name = 'timestamp' AND type = 'DateTime') = 1 AND
        countIf(name = 'reporter' AND type = 'FixedString(16)') = 1 AND
        countIf(name = 'reporter_grid' AND type = 'FixedString(8)') = 1 AND
        countIf(name = 'snr' AND type = 'Int8') = 1 AND
        countIf(name = 'frequency' AND type = 'UInt64') = 1 AND
        countIf(name = 'callsign' AND type = 'FixedString(16)') = 1 AND
        countIf(name = 'grid' AND type = 'FixedString(8)') = 1 AND
        countIf(name = 'power' AND type = 'Int8') = 1 AND
        countIf(name = 'drift' AND type = 'Int8') = 1 AND
        countIf(name = 'distance' AND type = 'UInt32') = 1 AND
        countIf(name = 'azimuth' AND type = 'UInt16') = 1 AND
        countIf(name = 'band' AND type = 'Int32') = 1 AND
        countIf(name = 'mode' AND type = 'FixedString(8)') = 1 AND
        countIf(name = 'version' AND type = 'FixedString(8)') = 1 AND
        countIf(name = 'code' AND type = 'UInt8') = 1 AND
        countIf(name = 'column_count' AND type = 'UInt8') = 1,
        1, 0
    )
    FROM system.columns
    WHERE database = 'wspr' AND table = 'spots_raw'
);


-- ==============================================================================
-- 7. C Struct Size Constant (for runtime verification)
-- ==============================================================================
-- This constant should match sizeof(WSPRSpot) in wspr_structs.h
-- Used by ingestion pipeline to verify memory layout compatibility
CREATE OR REPLACE FUNCTION wspr.fn_expected_struct_size() AS () -> 128;


-- ==============================================================================
-- 8. Data Integrity View (for monitoring)
-- ==============================================================================
CREATE OR REPLACE VIEW wspr.v_data_integrity AS
SELECT
    count() AS total_rows,
    countIf(frequency = 0) AS zero_frequency,
    countIf(timestamp = toDateTime(0)) AS zero_timestamp,
    countIf(callsign = '') AS empty_callsign,
    countIf(reporter = '') AS empty_reporter,
    countIf(column_count != 17) AS non_v2_rows,
    min(timestamp) AS earliest_spot,
    max(timestamp) AS latest_spot
FROM wspr.spots_raw;


-- ==============================================================================
-- 9. Daily Summary Materialized View (optional)
-- ==============================================================================
-- Uncomment to enable automatic daily aggregation for dashboards
-- CREATE MATERIALIZED VIEW IF NOT EXISTS wspr.mv_spots_daily
-- ENGINE = SummingMergeTree()
-- PARTITION BY toYYYYMM(day)
-- ORDER BY (day, band, mode)
-- AS SELECT
--     toDate(timestamp) AS day,
--     band,
--     mode,
--     count() AS spot_count,
--     uniqExact(callsign) AS unique_tx,
--     uniqExact(reporter) AS unique_rx,
--     avg(snr) AS avg_snr,
--     max(distance) AS max_distance
-- FROM wspr.spots_raw
-- GROUP BY day, band, mode;
