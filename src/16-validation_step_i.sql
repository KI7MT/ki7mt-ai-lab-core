-- ==============================================================================
-- Name..........: @PROGRAM@ - Step I Validation Tables
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Validation database for IONIS vs VOACAP head-to-head
--                 comparison on 1M contest QSO paths.
--
--                 step_i_paths  — 1M paths with IONIS predictions (loaded from
--                                 validate_v12.py --export CSV)
--                 step_i_voacap — VOACAP predictions for the same paths
--                                 (populated by voacap_batch_runner.py)
--
--                 The comparison JOIN is:
--                   SELECT p.*, v.voacap_band_open,
--                          (p.band_open = v.voacap_band_open) AS match
--                   FROM validation.step_i_paths p
--                   JOIN validation.step_i_voacap v
--                     USING (tx_lat, tx_lon, rx_lat, rx_lon,
--                            freq_mhz, year, month, hour_utc)
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS validation;

-- --------------------------------------------------------------------------
-- IONIS predictions (source: validate_v12.py --export)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS validation.step_i_paths (
    tx_lat       Float32    COMMENT 'Transmitter latitude (decimal degrees)',
    tx_lon       Float32    COMMENT 'Transmitter longitude (decimal degrees)',
    rx_lat       Float32    COMMENT 'Receiver latitude (decimal degrees)',
    rx_lon       Float32    COMMENT 'Receiver longitude (decimal degrees)',
    freq_mhz     Float32    COMMENT 'Frequency in MHz (1.8–28.0)',
    year         UInt16     COMMENT 'QSO year',
    month        UInt8      COMMENT 'QSO month (1-12)',
    hour_utc     UInt8      COMMENT 'QSO hour UTC (0-23)',
    ssn          Float32    COMMENT 'Smoothed sunspot number',
    mode         LowCardinality(String) COMMENT 'Contest mode: CW, PH, RY, DG',
    ionis_snr    Float32    COMMENT 'IONIS V12 predicted SNR (dB)',
    threshold    Float32    COMMENT 'Mode-dependent band-open threshold (dB)',
    band_open    UInt8      COMMENT '1 if ionis_snr >= threshold, 0 otherwise'
) ENGINE = MergeTree()
ORDER BY (year, month, mode)
COMMENT '@PROGRAM@ v@VERSION@ Step I: 1M contest paths with IONIS predictions';

-- --------------------------------------------------------------------------
-- VOACAP predictions (source: voacap_batch_runner.py)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS validation.step_i_voacap (
    tx_lat          Float32    COMMENT 'Transmitter latitude (decimal degrees)',
    tx_lon          Float32    COMMENT 'Transmitter longitude (decimal degrees)',
    rx_lat          Float32    COMMENT 'Receiver latitude (decimal degrees)',
    rx_lon          Float32    COMMENT 'Receiver longitude (decimal degrees)',
    freq_mhz        Float32    COMMENT 'Frequency in MHz (1.8–28.0)',
    year            UInt16     COMMENT 'QSO year',
    month           UInt8      COMMENT 'QSO month (1-12)',
    hour_utc        UInt8      COMMENT 'QSO hour UTC (0-23)',
    ssn             Float32    COMMENT 'Smoothed sunspot number',
    mode            LowCardinality(String) COMMENT 'Contest mode: CW, PH, RY, DG',
    voacap_snr      Float32    COMMENT 'VOACAP Method 30 SNR (dB)',
    voacap_rel      Float32    COMMENT 'VOACAP circuit reliability (0.0–1.0)',
    voacap_mufday   Float32    COMMENT 'VOACAP MUFday fraction (0.0–1.0)',
    threshold       Float32    COMMENT 'Mode-dependent band-open threshold (dB)',
    voacap_band_open UInt8     COMMENT '1 if voacap_snr >= threshold, 0 otherwise'
) ENGINE = MergeTree()
ORDER BY (year, month, mode)
COMMENT '@PROGRAM@ v@VERSION@ Step I: VOACAP predictions for 1M contest paths';
