-- ==============================================================================
-- Name..........: @PROGRAM@ - Step F v2: Terrestrial-Only WSPR Signatures
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Same aggregation logic as wspr.signatures_v1 but excluding
--                 balloon, telemetry, and reserved-prefix callsigns flagged in
--                 wspr.balloon_callsigns.
--
--                 Both TX and RX callsigns are filtered — a spot with a balloon
--                 on either end is excluded, since the balloon's radio horizon
--                 at 60,000 ft produces physics distinct from ground stations.
--
--                 Dimensions: tx_grid_4, rx_grid_4, band, hour, month
--                 Metrics:    median SNR, spot count, SNR stddev, reliability,
--                             avg SFI/Kp, avg distance/azimuth
--
--                 V1 retained for A/B comparison (V13 was trained on V1).
--                 V14-TP (Terrestrial Physics) trains on this table.
--
--                 Population: scripts/populate_signatures_v2_terrestrial.sh
-- ==============================================================================

CREATE TABLE IF NOT EXISTS wspr.signatures_v2_terrestrial (
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
COMMENT 'Step F v2: Terrestrial-only WSPR signatures — balloon/telemetry callsigns excluded via wspr.balloon_callsigns';
