-- ==============================================================================
-- Name..........: @PROGRAM@ - Contest Signatures for V16 Training
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Aggregated contest log signatures with anchored SNR values.
--
--                 Contest logs carry "Proof of Intent" — a completed QSO proves
--                 the path was viable for a high-threshold mode. Since contest
--                 signal reports are meaningless (always 599), we anchor SNR:
--                   SSB (PH): +10 dB  (proven voice-viable path)
--                   RTTY (RY): 0 dB   (proven digital-viable path)
--
--                 Schema matches wspr.signatures_v2_terrestrial exactly so the
--                 training pipeline can UNION ALL both sources directly.
--
--                 Grid resolution from wspr.callsign_grid (Rosetta Stone):
--                   ~56% of SSB/RTTY QSOs resolve both endpoints
--                   RTTY: 74.7% coverage, SSB: 47.4% coverage
--
--                 Distance and azimuth computed from 4-char grid centroids
--                 using ClickHouse greatCircleDistance() built-in.
--
--                 Population: scripts/populate_contest_signatures.sh
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS contest;

CREATE TABLE IF NOT EXISTS contest.signatures (
    tx_grid_4    FixedString(4)  COMMENT '4-char TX Maidenhead grid (field level)',
    rx_grid_4    FixedString(4)  COMMENT '4-char RX Maidenhead grid (field level)',
    band         Int32           COMMENT 'ADIF band ID (102-111)',
    hour         UInt8           COMMENT 'Hour of day UTC (0-23)',
    month        UInt8           COMMENT 'Month (1-12)',
    median_snr   Float32         COMMENT 'Anchored SNR: +10 (SSB) or 0 (RTTY)',
    spot_count   UInt32          COMMENT 'QSO count in bucket',
    snr_std      Float32         COMMENT '0 — no variance for anchored values',
    reliability  Float32         COMMENT '1.0 — proven QSO paths',
    avg_sfi      Float32         COMMENT 'Average Solar Flux Index for bucket',
    avg_kp       Float32         COMMENT 'Average Kp index for bucket',
    avg_distance UInt32          COMMENT 'Average great-circle distance km',
    avg_azimuth  UInt16          COMMENT 'Average azimuth degrees'
) ENGINE = MergeTree()
ORDER BY (band, hour, tx_grid_4, rx_grid_4)
COMMENT 'V16 contest signatures — anchored SNR from 195M SSB/RTTY QSOs via callsign_grid';
