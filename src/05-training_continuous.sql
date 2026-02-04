-- ==============================================================================
-- Name..........: @PROGRAM@ - Continuously-Weighted Training Set
-- Version.......: @VERSION@
-- Description...: IFW-sampled training table (no discrete SSN boundaries)
-- ==============================================================================
--
-- Phase 5.2: Replaces wspr.training_stratified (Phase 5.1 discrete quintiles).
-- Inverse Frequency Weighting (IFW) eliminates stair-step boundary artifacts
-- at SSN quintile edges by using Efraimidis-Spirakis weighted sampling
-- against a 2D (SSN, midpoint_lat) density histogram.
--
-- 10M rows (1M per band), balanced across the continuous SSN-latitude space.
-- Population: 10 INSERT queries (1 per band) with density-weighted ordering.
-- Rebuild by truncating and re-running the population script.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS wspr.training_continuous (
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
    midpoint_lat      Float32       COMMENT 'Pre-computed (tx_lat + rx_lat) / 2',
    sampling_weight   Float32       COMMENT 'IFW weight = 1/sqrt(density(ssn,lat))',
    sfi_dist_interact Float32       COMMENT 'SFI * log10(distance) raw interaction'
) ENGINE = MergeTree()
ORDER BY (band, cityHash64(tx_grid, rx_grid))
COMMENT '@PROGRAM@ v@VERSION@ Continuous-weighted Training Set (10M rows, IFW sampling)';
