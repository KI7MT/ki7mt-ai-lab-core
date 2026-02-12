-- ==============================================================================
-- Name..........: @PROGRAM@ - Model Validation Results
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Per-path model predictions vs ground truth for all
--                 validation sources (RBN, PSKR, Contest).
--
--                 Every scored path is one row. All validation analytics
--                 (recall, RMSE, bias, per-band heatmaps) are queries on
--                 this table.
--
--                 Mode viability flags are pre-computed at INSERT time
--                 using the waterfall thresholds:
--                   FT8  >= -20 dB
--                   CW   >= -10 dB
--                   RTTY >=  -5 dB
--                   SSB  >=  +5 dB
--
--                 mode_hit is the core recall metric: "did the model predict
--                 viable for the mode that was actually used?"
--
--                 Expected volume: ~107M rows per model version
--                   56.6M RBN + 49M PSKR + 1M Contest
--
--                 Populated by: tools/score_model.py (ki7mt-ai-lab-training)
--
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS validation;

-- --------------------------------------------------------------------------
-- Per-path predictions vs ground truth
-- --------------------------------------------------------------------------
-- PARTITION BY model_version — queries always filter by version; easy to
-- DROP PARTITION for old versions.
--
-- ORDER BY (source, band, hour, tx_grid_4, rx_grid_4) — matches common
-- query patterns: "RBN misses on 160m at night", "PSKR recall by band".
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS validation.model_results (
    -- Scoring run metadata
    run_id              UUID                    COMMENT 'Groups results from a single scoring run',
    run_timestamp       DateTime                COMMENT 'When the scoring was executed (UTC)',
    model_version       LowCardinality(String)  COMMENT 'Model identifier: v16, v20, v21...',
    source              LowCardinality(String)  COMMENT 'Ground truth source: rbn, pskr, contest',

    -- Path identification
    tx_grid_4           FixedString(4)          COMMENT '4-char TX Maidenhead grid',
    rx_grid_4           FixedString(4)          COMMENT '4-char RX Maidenhead grid',
    band                Int32                   COMMENT 'ADIF band ID (102=160m ... 111=10m)',
    hour                UInt8                   COMMENT 'Hour UTC (0-23)',
    month               UInt8                   COMMENT 'Month (1-12)',
    distance_km         UInt32                  COMMENT 'Great-circle distance km',
    azimuth             UInt16                  COMMENT 'Azimuth degrees',

    -- Ground truth
    actual_snr          Float32                 COMMENT 'Measured SNR from source (dB)',
    actual_mode         LowCardinality(String)  COMMENT 'Mode observed: CW, FT8, RTTY, SSB, WSPR...',

    -- Model prediction
    predicted_snr       Float32                 COMMENT 'Model predicted SNR (dB, WSPR-denormalized)',
    snr_error           Float32                 COMMENT 'predicted_snr - actual_snr (dB)',

    -- Mode viability verdicts (from predicted_snr vs thresholds)
    ft8_viable          UInt8                   COMMENT 'predicted_snr >= -20 dB',
    cw_viable           UInt8                   COMMENT 'predicted_snr >= -10 dB',
    rtty_viable         UInt8                   COMMENT 'predicted_snr >= -5 dB',
    ssb_viable          UInt8                   COMMENT 'predicted_snr >= +5 dB',

    -- Verdict for the actual mode used
    mode_hit            UInt8                   COMMENT '1 if model predicted viable for actual mode',

    -- Solar conditions at time of observation
    avg_sfi             Float32                 COMMENT 'Solar Flux Index for this path/bucket',
    avg_kp              Float32                 COMMENT 'Kp geomagnetic index for this path/bucket'
) ENGINE = MergeTree()
PARTITION BY model_version
ORDER BY (source, band, hour, tx_grid_4, rx_grid_4)
COMMENT '@PROGRAM@ v@VERSION@ Per-path model predictions vs ground truth — foundation for all validation analytics';
