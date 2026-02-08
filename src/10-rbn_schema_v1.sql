-- ============================================================================
-- ki7mt-ai-lab-core: RBN Raw Spots Schema v1
-- ============================================================================
-- Reverse Beacon Network bulk archive: ~2.2B CW/RTTY/PSK spots, 2009-present.
-- Daily ZIPs from https://data.reversebeacon.net/rbn_history/
--
-- Design notes:
--   - Separate 'rbn' database — clean separation from wspr/solar
--   - ADIF band IDs (Int32) via bands.GetBand(freq/1000) for cross-dataset joins
--   - Frequency in kHz (UInt32) — RBN native unit, no precision loss
--   - String for callsigns — RBN calls vary (KM3T-3, W3LPL, BH4RXP)
--   - 'spot_type' = CSV 'mode' column (CQ/BEACON/DX/NCDXF B) — renamed for clarity
--   - 'tx_mode' = actual modulation (CW/RTTY/PSK31) — absent in 2009-2010 files
--   - Int16 for SNR — RBN range -9 to 173 exceeds Int8 max of 127
--   - LowCardinality for spot_type/tx_mode — only ~5 distinct values
--   - Beacons/NCDXF kept — valuable propagation indicators
--   - No id column — RBN has no native ID; timestamp+band+dx_call is natural key
--   - Partitioned by month for efficient time-range queries
-- ============================================================================

-- 1. Create database
CREATE DATABASE IF NOT EXISTS rbn;

-- 2. Create raw spots table
CREATE TABLE IF NOT EXISTS rbn.bronze (
    timestamp   DateTime                COMMENT 'Spot timestamp UTC',
    de_call     String                  COMMENT 'RBN skimmer callsign',
    de_pfx      String                  COMMENT 'Skimmer DXCC prefix',
    de_cont     FixedString(2)          COMMENT 'Skimmer continent (NA, EU, AS, AF, SA, OC)',
    frequency   UInt32                  COMMENT 'Frequency in kHz (RBN native)',
    band        Int32                   COMMENT 'ADIF band ID via bands.GetBand()',
    dx_call     String                  COMMENT 'Spotted station callsign',
    dx_pfx      String                  COMMENT 'Spotted station DXCC prefix',
    dx_cont     FixedString(2)          COMMENT 'Spotted station continent',
    spot_type   LowCardinality(String)  COMMENT 'CQ, BEACON, DX, NCDXF B',
    snr         Int16                   COMMENT 'Signal strength dB (real measurement)',
    speed       UInt16                  COMMENT 'CW WPM or RTTY baud (0 if absent)',
    tx_mode     LowCardinality(String)  COMMENT 'CW, RTTY, PSK31 (empty if absent)'
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, band, dx_call)
SETTINGS index_granularity = 8192
COMMENT 'RBN bulk archive spots v1 — 2.2B spots, 2009-2026, CW/RTTY/PSK';
