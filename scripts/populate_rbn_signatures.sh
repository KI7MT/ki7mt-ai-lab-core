#!/bin/bash
# ==============================================================================
# populate_rbn_signatures.sh — V17: RBN Grid-Enriched Signatures
# ==============================================================================
#
# Aggregates CW, RTTY, and PSK31 RBN spots into signatures with REAL
# machine-measured SNR. Fills the middle of the dynamic range between
# WSPR floor (-28 dB) and contest ceiling (+10 dB).
#
# Grid resolution via wspr.callsign_grid (Rosetta Stone, 3.64M callsigns).
#   dx_call → TX (spotted station transmitting)
#   de_call → RX (skimmer receiving)
#
# Distance and azimuth computed from 4-char grid centroids.
# Solar data joined from solar.bronze (2000-2026 coverage).
#
# Note: tx_mode = '' (30M spots, 2009-2010) is included — RBN was CW-only
# in that era, so empty mode IS CW.
#
# SNR filter: -20 to 80 dB. RBN has outliers up to 233 (skimmer AGC
# artifacts). Cap at 80 keeps real signals, removes noise.
#
# Prerequisites:
#   - rbn.signatures table exists (24-rbn_signatures.sql)
#   - rbn.bronze populated (2.18B spots)
#   - wspr.callsign_grid populated (>= 3M rows)
#   - solar.bronze populated (2000-2026)
#
# Usage:
#   bash populate_rbn_signatures.sh
#   CH_HOST=10.60.1.1 bash populate_rbn_signatures.sh
#
# ==============================================================================
set -e

CH_HOST="${CH_HOST:-192.168.1.90}"

START_TIME=$(date +%s)

# --------------------------------------------------------------------------
# Pre-flight checks
# --------------------------------------------------------------------------
CG_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.callsign_grid")
if [ "$CG_COUNT" -lt 3000000 ]; then
    echo "ERROR: wspr.callsign_grid has only ${CG_COUNT} rows (expected >= 3M)"
    exit 1
fi

SOLAR_MIN=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT min(date) FROM solar.bronze WHERE observed_flux > 0")
if [ "$SOLAR_MIN" \> "2010-01-01" ]; then
    echo "WARNING: Solar data starts at ${SOLAR_MIN} — RBN data goes back to 2009"
    echo "Run solar-backfill -start 2000-01-01 first for full coverage."
fi

RBN_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM rbn.bronze WHERE tx_mode IN ('CW', 'RTTY', 'PSK31', '')")

echo "============================================================"
echo "V17: Populating rbn.signatures"
echo "============================================================"
echo "Host:           ${CH_HOST}"
echo "Callsign grid:  ${CG_COUNT} entries"
echo "Solar from:     ${SOLAR_MIN}"
echo "CW/RTTY/PSK31:  ${RBN_COUNT} spots"
echo "SNR filter:     -20 to 80 dB"
echo "Min bucket:     3 spots"
echo "============================================================"
echo ""

# Create table if not exists
clickhouse-client --host "$CH_HOST" --multiquery < \
    "$(dirname "$0")/../src/24-rbn_signatures.sql" 2>/dev/null || true

# Truncate for idempotent re-run
echo "Truncating rbn.signatures..."
clickhouse-client --host "$CH_HOST" --query \
    "TRUNCATE TABLE IF EXISTS rbn.signatures"
echo ""

# --------------------------------------------------------------------------
# Population: per-band sequential (matches WSPR/contest signature pattern)
# --------------------------------------------------------------------------
TOTAL=0

for band in 102 103 104 105 106 107 108 109 110 111; do
    case $band in
        102) bname="160m" ;; 103) bname="80m"  ;; 104) bname="60m"  ;;
        105) bname="40m"  ;; 106) bname="30m"  ;; 107) bname="20m"  ;;
        108) bname="17m"  ;; 109) bname="15m"  ;; 110) bname="12m"  ;;
        111) bname="10m"  ;;
    esac

    band_idx=$(( band - 101 ))
    printf "[%2d/10] Band %d (%s) ... " "$band_idx" "$band" "$bname"

    T0=$(date +%s%N)

    clickhouse-client --host "$CH_HOST" --query "
        INSERT INTO rbn.signatures
        SELECT
            cg_tx.grid_4                        AS tx_grid_4,
            cg_rx.grid_4                        AS rx_grid_4,
            r.band,
            toHour(r.timestamp)                 AS hour,
            toMonth(r.timestamp)                AS month,

            -- REAL machine-measured SNR
            quantile(0.5)(r.snr)                AS median_snr,

            count()                             AS spot_count,
            stddevPop(r.snr)                    AS snr_std,
            1.0                                 AS reliability,

            -- Solar conditions
            avg(sol.observed_flux)              AS avg_sfi,
            avg(sol.kp_index)                   AS avg_kp,

            -- Distance from 4-char grid centroids (km)
            toUInt32(avg(
                greatCircleDistance(
                    -- TX lon, lat (dx_call = spotted station)
                    (reinterpretAsUInt8(upper(substring(toString(cg_tx.grid_4), 1, 1))) - 65) * 20
                        + (reinterpretAsUInt8(substring(toString(cg_tx.grid_4), 3, 1)) - 48) * 2 - 180 + 1.0,
                    (reinterpretAsUInt8(upper(substring(toString(cg_tx.grid_4), 2, 1))) - 65) * 10
                        + (reinterpretAsUInt8(substring(toString(cg_tx.grid_4), 4, 1)) - 48) - 90 + 0.5,
                    -- RX lon, lat (de_call = skimmer)
                    (reinterpretAsUInt8(upper(substring(toString(cg_rx.grid_4), 1, 1))) - 65) * 20
                        + (reinterpretAsUInt8(substring(toString(cg_rx.grid_4), 3, 1)) - 48) * 2 - 180 + 1.0,
                    (reinterpretAsUInt8(upper(substring(toString(cg_rx.grid_4), 2, 1))) - 65) * 10
                        + (reinterpretAsUInt8(substring(toString(cg_rx.grid_4), 4, 1)) - 48) - 90 + 0.5
                ) / 1000
            ))                                  AS avg_distance,

            -- Azimuth from TX to RX (degrees)
            toUInt16(avg(
                (degrees(atan2(
                    sin(radians(
                        ((reinterpretAsUInt8(upper(substring(toString(cg_rx.grid_4), 1, 1))) - 65) * 20
                            + (reinterpretAsUInt8(substring(toString(cg_rx.grid_4), 3, 1)) - 48) * 2 - 180 + 1.0)
                        - ((reinterpretAsUInt8(upper(substring(toString(cg_tx.grid_4), 1, 1))) - 65) * 20
                            + (reinterpretAsUInt8(substring(toString(cg_tx.grid_4), 3, 1)) - 48) * 2 - 180 + 1.0)
                    )) * cos(radians(
                        (reinterpretAsUInt8(upper(substring(toString(cg_rx.grid_4), 2, 1))) - 65) * 10
                            + (reinterpretAsUInt8(substring(toString(cg_rx.grid_4), 4, 1)) - 48) - 90 + 0.5
                    )),
                    cos(radians(
                        (reinterpretAsUInt8(upper(substring(toString(cg_tx.grid_4), 2, 1))) - 65) * 10
                            + (reinterpretAsUInt8(substring(toString(cg_tx.grid_4), 4, 1)) - 48) - 90 + 0.5
                    )) * sin(radians(
                        (reinterpretAsUInt8(upper(substring(toString(cg_rx.grid_4), 2, 1))) - 65) * 10
                            + (reinterpretAsUInt8(substring(toString(cg_rx.grid_4), 4, 1)) - 48) - 90 + 0.5
                    )) - sin(radians(
                        (reinterpretAsUInt8(upper(substring(toString(cg_tx.grid_4), 2, 1))) - 65) * 10
                            + (reinterpretAsUInt8(substring(toString(cg_tx.grid_4), 4, 1)) - 48) - 90 + 0.5
                    )) * cos(radians(
                        (reinterpretAsUInt8(upper(substring(toString(cg_rx.grid_4), 2, 1))) - 65) * 10
                            + (reinterpretAsUInt8(substring(toString(cg_rx.grid_4), 4, 1)) - 48) - 90 + 0.5
                    )) * cos(radians(
                        ((reinterpretAsUInt8(upper(substring(toString(cg_rx.grid_4), 1, 1))) - 65) * 20
                            + (reinterpretAsUInt8(substring(toString(cg_rx.grid_4), 3, 1)) - 48) * 2 - 180 + 1.0)
                        - ((reinterpretAsUInt8(upper(substring(toString(cg_tx.grid_4), 1, 1))) - 65) * 20
                            + (reinterpretAsUInt8(substring(toString(cg_tx.grid_4), 3, 1)) - 48) * 2 - 180 + 1.0)
                    ))
                )) + 360) % 360
            ))                                  AS avg_azimuth

        FROM rbn.bronze r
        INNER JOIN wspr.callsign_grid cg_tx ON r.dx_call = cg_tx.callsign
        INNER JOIN wspr.callsign_grid cg_rx ON r.de_call = cg_rx.callsign
        LEFT JOIN solar.bronze sol
            ON toDate(r.timestamp) = sol.date
            AND intDiv(toHour(r.timestamp), 3) = intDiv(toHour(sol.time), 3)
        WHERE r.band = ${band}
          AND r.tx_mode IN ('CW', 'RTTY', 'PSK31', '')
          AND r.snr BETWEEN -20 AND 80
          AND cg_tx.grid_4 != ''
          AND cg_rx.grid_4 != ''
          AND r.timestamp >= '2009-01-01'
          AND r.timestamp <  '2026-01-01'
        GROUP BY tx_grid_4, rx_grid_4, r.band, hour, month
        HAVING spot_count >= 3
        SETTINGS
            max_threads = 64,
            max_memory_usage = 80000000000,
            max_bytes_before_external_group_by = 20000000000,
            join_use_nulls = 0
    "

    BAND_ROWS=$(clickhouse-client --host "$CH_HOST" --query "
        SELECT count() FROM rbn.signatures WHERE band = ${band}
    ")

    T1=$(date +%s%N)
    ELAPSED=$(( (T1 - T0) / 1000000 ))
    TOTAL=$(( TOTAL + BAND_ROWS ))
    printf "done (%d.%ds) | %s rows | cumulative: %s\n" \
        "$((ELAPSED/1000))" "$((ELAPSED%1000/100))" \
        "$(printf '%d' "$BAND_ROWS")" "$(printf '%d' $TOTAL)"
done

END_TIME=$(date +%s)
WALL=$(( END_TIME - START_TIME ))

TOTAL_SIGS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM rbn.signatures")

echo ""
echo "============================================================"
echo "Population Complete — V17 RBN Signatures"
echo "============================================================"
echo "Total signatures: ${TOTAL_SIGS}"
echo "Wall time:        ${WALL}s"
echo "============================================================"
echo ""

# SNR distribution check
echo "SNR distribution (p10 / p50 / p90):"
clickhouse-client --host "$CH_HOST" --query "
    SELECT
        round(quantile(0.1)(median_snr), 1) AS p10,
        round(quantile(0.5)(median_snr), 1) AS p50,
        round(quantile(0.9)(median_snr), 1) AS p90
    FROM rbn.signatures
"
echo ""

# Per-band summary
echo "Per-band breakdown:"
clickhouse-client --host "$CH_HOST" --query "
    SELECT
        band,
        count()                             AS signatures,
        round(avg(median_snr), 1)           AS avg_snr,
        round(avg(spot_count), 0)           AS avg_spots,
        round(avg(avg_distance), 0)         AS avg_dist_km
    FROM rbn.signatures
    GROUP BY band
    ORDER BY band
    FORMAT PrettyCompact
"
echo ""

# Self-spot check
SELF_SPOTS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM rbn.signatures WHERE tx_grid_4 = rx_grid_4")
echo "Same-grid signatures: ${SELF_SPOTS}"
echo ""

# Solar coverage
SOLAR_PCT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT round(countIf(avg_sfi > 0) * 100.0 / count(), 1) FROM rbn.signatures")
echo "Solar coverage:       ${SOLAR_PCT}%"
echo ""

echo "============================================================"
echo "Ready for V17 training join on M3:"
echo "  WSPR floor + Contest ceiling + RBN middle"
echo "============================================================"
