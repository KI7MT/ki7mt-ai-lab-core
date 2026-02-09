-- ==============================================================================
-- Name..........: @PROGRAM@ - Step K Quality-of-Prediction Test
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Validation tables for the IONIS V13 vs VOACAP Pearson r /
--                 RMSE head-to-head quality test on 100K high-confidence WSPR
--                 signatures (10K per HF band, spot_count > 50).
--
--                 Step K measures prediction QUALITY (Pearson correlation with
--                 observed SNR) rather than binary recall. This is the
--                 scale-independent counterpart to the Step I recall test.
--
--                 Results (2026-02-09):
--                   IONIS V13 Pearson r:  +0.3675
--                   VOACAP Pearson r:     +0.0218
--                   IONIS wins 9/10 bands
--                   Low-band delta:       +0.5167 (IONIS +0.3204 vs VOACAP -0.1963)
--
--                 Population:
--                   quality_test_paths  — populate_quality_test_paths.sh
--                   quality_test_voacap — voacap_quality_test.py (ki7mt-ai-lab-training)
--
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS validation;

-- --------------------------------------------------------------------------
-- 100K high-confidence WSPR signatures (ground truth)
-- --------------------------------------------------------------------------
-- Stratified sample: 10K per HF band, requiring spot_count > 50.
-- median_snr is the ground truth for Pearson r / RMSE comparison.
-- SSN derived from avg_sfi via Covington formula: (SFI - 63.7) / 0.727.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS validation.quality_test_paths (
    path_id        UInt32     COMMENT 'Sequential path identifier (1-100K)',
    tx_grid_4      String     COMMENT 'Transmitter 4-char Maidenhead grid',
    rx_grid_4      String     COMMENT 'Receiver 4-char Maidenhead grid',
    tx_lat         Float32    COMMENT 'Transmitter latitude (grid center, decimal degrees)',
    tx_lon         Float32    COMMENT 'Transmitter longitude (grid center, decimal degrees)',
    rx_lat         Float32    COMMENT 'Receiver latitude (grid center, decimal degrees)',
    rx_lon         Float32    COMMENT 'Receiver longitude (grid center, decimal degrees)',
    band           Int32      COMMENT 'ADIF band ID (102-111)',
    freq_mhz       Float32    COMMENT 'Center frequency for VOACAP (MHz)',
    hour           UInt8      COMMENT 'UTC hour (0-23)',
    month          UInt8      COMMENT 'Month (1-12)',
    spot_count     UInt32     COMMENT 'Number of WSPR spots in this signature bucket',
    median_snr     Float32    COMMENT 'Ground truth: median SNR from observations (dB)',
    snr_std        Float32    COMMENT 'SNR standard deviation (dB)',
    reliability    Float32    COMMENT 'Fraction of spots with SNR > -20',
    avg_sfi        Float32    COMMENT 'Average Solar Flux Index for this bucket',
    avg_kp         Float32    COMMENT 'Average Kp index for this bucket',
    avg_distance   UInt32     COMMENT 'Average path distance (km)',
    ssn            Float32    COMMENT 'Derived SSN: max(0, (avg_sfi - 63.7) / 0.727)'
) ENGINE = MergeTree()
ORDER BY path_id
COMMENT '@PROGRAM@ v@VERSION@ Step K: 100K high-confidence WSPR signatures for quality-of-prediction test';

-- --------------------------------------------------------------------------
-- VOACAP predictions for the 100K paths
-- --------------------------------------------------------------------------
-- Populated by voacap_quality_test.py using Method 30 ray-tracing.
-- TX power: 0.0002 kW (200 mW, standard WSPR).
-- One prediction per path_id.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS validation.quality_test_voacap (
    path_id        UInt32     COMMENT 'Matches quality_test_paths.path_id',
    voacap_snr     Float32    COMMENT 'VOACAP Method 30 predicted SNR (dB)',
    voacap_rel     Float32    COMMENT 'VOACAP circuit reliability (0.0-1.0)',
    voacap_mufday  Float32    COMMENT 'VOACAP MUF for day fraction (0.0-1.0)'
) ENGINE = MergeTree()
ORDER BY path_id
COMMENT '@PROGRAM@ v@VERSION@ Step K: VOACAP Method 30 predictions for 100K quality test paths';

-- ==============================================================================
-- Population: quality_test_paths
-- ==============================================================================
-- 10K rows per HF band (102-111), stratified, high-confidence (spot_count > 50).
-- Grid centers computed via Maidenhead conversion: field*10 + square + 0.5 offsets.
--
-- BAND_MAP: 102→1.84, 103→3.57, 104→5.29, 105→7.04, 106→10.14,
--           107→14.10, 108→18.10, 109→21.10, 110→24.92, 111→28.13
--
-- INSERT INTO validation.quality_test_paths
-- SELECT
--     rowNumberInAllBlocks() + 1 AS path_id,
--     tx_grid_4, rx_grid_4,
--     -- Maidenhead to lat/lon (grid center)
--     (toUInt8(substring(tx_grid_4,2,1)) - 65) * 10 + toUInt8(substring(tx_grid_4,4,1)) - 48 + 0.5 - 90 AS tx_lat,
--     (toUInt8(substring(tx_grid_4,1,1)) - 65) * 20 + (toUInt8(substring(tx_grid_4,3,1)) - 48) * 2 + 1 - 180 AS tx_lon,
--     (toUInt8(substring(rx_grid_4,2,1)) - 65) * 10 + toUInt8(substring(rx_grid_4,4,1)) - 48 + 0.5 - 90 AS rx_lat,
--     (toUInt8(substring(rx_grid_4,1,1)) - 65) * 20 + (toUInt8(substring(rx_grid_4,3,1)) - 48) * 2 + 1 - 180 AS rx_lon,
--     band,
--     multiIf(band=102,1.84, band=103,3.57, band=104,5.29, band=105,7.04,
--             band=106,10.14, band=107,14.10, band=108,18.10, band=109,21.10,
--             band=110,24.92, band=111,28.13, 14.10) AS freq_mhz,
--     hour, month, spot_count, median_snr, snr_std, reliability,
--     avg_sfi, avg_kp, avg_distance,
--     greatest(0, (avg_sfi - 63.7) / 0.727) AS ssn
-- FROM (
--     SELECT *, row_number() OVER (PARTITION BY band ORDER BY rand()) AS rn
--     FROM wspr.signatures_v1
--     WHERE spot_count > 50
-- )
-- WHERE rn <= 10000
-- SETTINGS max_threads = 64, max_memory_usage = 40000000000;
