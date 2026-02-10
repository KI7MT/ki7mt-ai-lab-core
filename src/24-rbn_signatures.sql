-- ==============================================================================
-- Name..........: @PROGRAM@ - RBN Grid-Enriched Signatures for V17 Training
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Aggregated RBN signatures with REAL machine-measured SNR.
--
--                 RBN spots carry real SNR from skimmer hardware (not anchored
--                 like contest, not low-power like WSPR). This fills the MIDDLE
--                 of the dynamic range: CW median ~18 dB, RTTY median ~22 dB.
--
--                 Curriculum sequence:
--                   Floor:   WSPR signatures (-28 dB, measured)
--                   Ceiling: Contest signatures (+10 dB SSB, 0 dB RTTY, anchored)
--                   Middle:  RBN signatures (real SNR, ~10-30 dB range)
--
--                 Grid resolution from wspr.callsign_grid (Rosetta Stone):
--                   54.2% of HF spots resolve both endpoints (~1.16B spots)
--                   Resolution varies by band: 71% on 160m, 33% on 30m
--
--                 Schema matches wspr.signatures_v2_terrestrial and
--                 contest.signatures exactly for UNION ALL compatibility.
--
--                 Population: scripts/populate_rbn_signatures.sh
-- ==============================================================================

CREATE TABLE IF NOT EXISTS rbn.signatures (
    tx_grid_4    FixedString(4)  COMMENT '4-char TX Maidenhead grid (spotted station, dx_call)',
    rx_grid_4    FixedString(4)  COMMENT '4-char RX Maidenhead grid (skimmer, de_call)',
    band         Int32           COMMENT 'ADIF band ID (102-111)',
    hour         UInt8           COMMENT 'Hour of day UTC (0-23)',
    month        UInt8           COMMENT 'Month (1-12)',
    median_snr   Float32         COMMENT 'quantile(0.5)(snr) — REAL machine-measured SNR',
    spot_count   UInt32          COMMENT 'Spots in bucket (min 3)',
    snr_std      Float32         COMMENT 'stddevPop(snr) — REAL variance',
    reliability  Float32         COMMENT '1.0 — every RBN spot is a confirmed decode',
    avg_sfi      Float32         COMMENT 'Average Solar Flux Index for bucket',
    avg_kp       Float32         COMMENT 'Average Kp index for bucket',
    avg_distance UInt32          COMMENT 'Average great-circle distance km',
    avg_azimuth  UInt16          COMMENT 'Average azimuth degrees'
) ENGINE = MergeTree()
ORDER BY (band, hour, tx_grid_4, rx_grid_4)
COMMENT 'V17 RBN signatures — real machine-measured SNR from 2.18B CW/RTTY/PSK31 spots via callsign_grid';
