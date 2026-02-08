-- ============================================================================
-- ki7mt-ai-lab-core: Step F — Aggregated WSPR Signatures
-- ============================================================================
-- Reduces 10.8B individual WSPR spots into median-based physical buckets,
-- stripping site-level noise (local QRM, antenna inefficiency, ground fading).
--
-- Dimensions: tx_grid_4, rx_grid_4, band, hour, month
-- Metrics:    median SNR, spot count, SNR stddev, reliability, avg SFI/Kp
--
-- Population: Per-band INSERT from wspr.bronze JOIN solar.bronze
--   - Filters: band 102-111 (HF), distance >= 500 km (ground-wave rejection)
--   - HAVING spot_count >= 5 (noise floor rejection)
--   - Median via quantile(0.5) resists outliers ("Site Entropy" filter)
--
-- All 13 V11 model features are derivable from this table:
--   Trunk (11): distance, freq_log (from band), hour_sin/cos (from hour),
--     az_sin/cos (from avg_azimuth), lat_diff/midpoint_lat (from grid centroids),
--     season_sin/cos (from month), day_night_est (from hour + grid longitude)
--   Sidecars (2): sfi (avg_sfi/300), kp_penalty (1 - avg_kp/9)
-- ============================================================================

CREATE TABLE IF NOT EXISTS wspr.signatures_v1 (
    tx_grid_4    FixedString(4)  COMMENT '4-char TX Maidenhead grid (field level)',
    rx_grid_4    FixedString(4)  COMMENT '4-char RX Maidenhead grid (field level)',
    band         Int32           COMMENT 'ADIF band ID (102-111)',
    hour         UInt8           COMMENT 'Hour of day UTC (0-23)',
    month        UInt8           COMMENT 'Month (1-12)',
    median_snr   Float32         COMMENT 'quantile(0.5)(snr) - site entropy filter',
    spot_count   UInt32          COMMENT 'Spots in bucket (min 5)',
    snr_std      Float32         COMMENT 'SNR standard deviation dB',
    reliability  Float32         COMMENT 'Fraction of spots with SNR > -20 dB',
    avg_sfi      Float32         COMMENT 'Average Solar Flux Index for bucket',
    avg_kp       Float32         COMMENT 'Average Kp index for bucket',
    avg_distance UInt32          COMMENT 'Average great-circle distance km',
    avg_azimuth  UInt16          COMMENT 'Average azimuth degrees'
) ENGINE = MergeTree()
ORDER BY (band, hour, tx_grid_4, rx_grid_4)
COMMENT 'ki7mt-ai-lab Step F: Aggregated WSPR signatures - noise rejection via median bucketing';

-- ============================================================================
-- Population: Run per-band to stay within memory limits.
-- Total time on 9975WX (128-thread, 10.8B rows): ~3 min 10 sec
-- Result: 93.8M signature rows (115:1 compression from raw spots)
-- ============================================================================
-- INSERT INTO wspr.signatures_v1
-- SELECT
--     substring(s.grid, 1, 4)          AS tx_grid_4,
--     substring(s.reporter_grid, 1, 4) AS rx_grid_4,
--     s.band,
--     toHour(s.timestamp)              AS hour,
--     toMonth(s.timestamp)             AS month,
--     quantile(0.5)(s.snr)             AS median_snr,
--     count()                          AS spot_count,
--     stddevPop(s.snr)                 AS snr_std,
--     countIf(s.snr > -20) / count()   AS reliability,
--     avg(sol.observed_flux)           AS avg_sfi,
--     avg(sol.kp_index)                AS avg_kp,
--     avg(s.distance)                  AS avg_distance,
--     avg(s.azimuth)                   AS avg_azimuth
-- FROM wspr.bronze s
-- LEFT JOIN solar.bronze sol
--     ON toDate(s.timestamp) = sol.date
--     AND intDiv(toHour(s.timestamp), 3) = intDiv(toHour(sol.time), 3)
-- WHERE s.band = {BAND}           -- Run once per band: 102..111
--   AND s.distance >= 500
-- GROUP BY tx_grid_4, rx_grid_4, s.band, hour, month
-- HAVING spot_count >= 5
-- SETTINGS
--     max_threads = 64,
--     max_memory_usage = 80000000000,
--     max_bytes_before_external_group_by = 20000000000,
--     join_use_nulls = 0;
