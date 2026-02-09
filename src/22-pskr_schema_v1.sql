-- ============================================================================
-- ki7mt-ai-lab-core: PSK Reporter Raw Spots Schema v1
-- ============================================================================
-- PSK Reporter MQTT reception reports: FT8/FT4/WSPR/JS8/CW spots from
-- 27K+ active monitors worldwide. Collected via pskr-collector (MQTT
-- subscriber → gzip JSONL files → this table via future pskr-ingest).
--
-- Design notes:
--   - Separate 'pskr' database — clean separation from wspr/rbn/contest
--   - ADIF band IDs (Int32) via bands.GetBand(freq/1e6) for cross-dataset joins
--   - Frequency in Hz (UInt64) — PSK Reporter native unit, no precision loss
--   - Both grids come from the MQTT payload (unlike RBN which needs enrichment)
--   - String for grids — PSK Reporter sends 4 or 6 char, variable length
--   - LowCardinality(String) for mode — small cardinality (FT8, FT4, WSPR, etc.)
--   - ORDER BY matches signature query pattern (band → time → grids)
--   - Monthly partitioning consistent with wspr/rbn/contest
--   - SNR is machine-decoded (FT8/FT4/WSPR) — same quality as WSPR SNR
-- ============================================================================

-- 1. Create database
CREATE DATABASE IF NOT EXISTS pskr;

-- 2. Create raw spots table
CREATE TABLE IF NOT EXISTS pskr.bronze (
    timestamp      DateTime                COMMENT 'Spot timestamp UTC',
    sender_call    String                  COMMENT 'Transmitting callsign',
    sender_grid    String                  COMMENT 'Sender Maidenhead grid (4-6 char)',
    receiver_call  String                  COMMENT 'Receiving/monitoring callsign',
    receiver_grid  String                  COMMENT 'Receiver Maidenhead grid (4-6 char)',
    frequency      UInt64                  COMMENT 'Frequency in Hz (PSK Reporter native)',
    band           Int32                   COMMENT 'ADIF band ID via bands.GetBand()',
    mode           LowCardinality(String)  COMMENT 'FT8, FT4, WSPR, JS8, CW, etc.',
    snr            Int16                   COMMENT 'Signal-to-noise ratio dB (machine-decoded)'
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (band, timestamp, sender_grid, receiver_grid)
SETTINGS index_granularity = 8192
COMMENT 'PSK Reporter reception reports v1 — real-time MQTT collection via pskr-collector';
