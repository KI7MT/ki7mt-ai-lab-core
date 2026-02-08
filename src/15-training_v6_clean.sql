-- ==============================================================================
-- Name..........: @PROGRAM@ - Phase 6 Clean Kp Constraint Training Set
-- Version.......: @VERSION@
-- Description...: gold_continuous + kp_penalty constraint column
-- ==============================================================================
--
-- Phase 6: Adds sign-constrained kp_penalty = 1.0 - kp/9.0 to give the model
-- an explicit absorption-direction view of Kp. Phase 5.2 showed Kp inversion
-- (+6.1 dB from Kp 0->9) because raw kp correlates with high SFI in the data.
--
-- 10M rows from wspr.gold_continuous. All IFW weights preserved exactly.
-- Population: single INSERT ... SELECT *, 1.0 - (kp / 9.0) AS kp_penalty.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS wspr.gold_v6 (
    snr               Int8,
    distance          UInt32,
    band              Int32,
    hour              UInt8,
    month             UInt8,
    azimuth           UInt16,
    tx_grid           String,
    rx_grid           String,
    ssn               Float32,
    sfi               Float32,
    kp                Float32,
    midpoint_lat      Float32,
    sampling_weight   Float32,
    sfi_dist_interact Float32,
    kp_penalty        Float32   COMMENT '1.0 - kp/9.0 (Kp=0->1.0, Kp=9->0.0)'
) ENGINE = MergeTree()
ORDER BY (band, cityHash64(tx_grid, rx_grid))
COMMENT '@PROGRAM@ v@VERSION@ Phase 6: gold_continuous + kp_penalty constraint (10M rows)';
