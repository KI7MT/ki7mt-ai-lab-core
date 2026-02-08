-- ==============================================================================
-- Name..........: @PROGRAM@ - SSN-Stratified Training Set
-- Version.......: @VERSION@
-- Description...: Materialized training table with balanced SSN quintiles
-- ==============================================================================
--
-- Phase 5.1: SSN-stratified training data for IONIS V2.
-- 10M rows (200K per band x quintile), balanced across 5 SSN bins.
--
-- Quintile boundaries (from WSPR-solar JOIN quantiles):
--   Q1: SSN <= 46      (solar minimum)
--   Q2: 46 < SSN <= 76
--   Q3: 76 < SSN <= 124
--   Q4: 124 < SSN <= 153
--   Q5: SSN > 153      (solar maximum)
--
-- Populated via 50 INSERT queries (10 bands x 5 quintiles x 200K each).
-- Rebuild by truncating and re-running the population script.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS wspr.training_stratified (
    snr Int8,
    distance UInt32,
    band Int32,
    hour UInt8,
    month UInt8,
    azimuth UInt16,
    tx_grid String,
    rx_grid String,
    ssn Float32,
    sfi Float32,
    kp Float32,
    ssn_quintile UInt8
) ENGINE = MergeTree()
ORDER BY (ssn_quintile, band, cityHash64(tx_grid, rx_grid))
COMMENT '@PROGRAM@ v@VERSION@ SSN-Stratified Training Set (10M rows, 2M per quintile)';
