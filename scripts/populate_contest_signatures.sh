#!/bin/bash
# ==============================================================================
# populate_contest_signatures.sh — V16: Anchored Contest Signatures
# ==============================================================================
#
# Aggregates SSB and RTTY contest QSOs into signatures matching the WSPR
# signature schema. SNR is anchored (not measured):
#   SSB (PH): +10 dB  (proven voice-viable path)
#   RTTY (RY): 0 dB   (proven digital-viable path)
#
# Grid resolution via wspr.callsign_grid (Rosetta Stone, 3.64M callsigns).
# Distance and azimuth computed from 4-char grid centroids.
# Solar data joined from solar.bronze (2000-2026 coverage).
#
# Prerequisites:
#   - contest.signatures table exists (23-contest_signatures.sql)
#   - contest.bronze populated (195M QSOs)
#   - wspr.callsign_grid populated (>= 3M rows)
#   - solar.bronze populated (2000-2026)
#
# Usage:
#   bash populate_contest_signatures.sh
#   CH_HOST=10.60.1.1 bash populate_contest_signatures.sh
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
if [ "$SOLAR_MIN" \> "2001-01-01" ]; then
    echo "WARNING: Solar data starts at ${SOLAR_MIN} — contest data goes back to 2005"
    echo "Run solar-backfill -start 2000-01-01 first for full coverage."
fi

CONTEST_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM contest.bronze WHERE mode IN ('PH', 'RY')")

echo "============================================================"
echo "V16: Populating contest.signatures"
echo "============================================================"
echo "Host:           ${CH_HOST}"
echo "Callsign grid:  ${CG_COUNT} entries"
echo "Solar from:     ${SOLAR_MIN}"
echo "SSB/RTTY QSOs:  ${CONTEST_COUNT}"
echo "Anchor values:  PH (SSB) = +10 dB, RY (RTTY) = 0 dB"
echo "============================================================"
echo ""

# Create table if not exists
clickhouse-client --host "$CH_HOST" --query "CREATE DATABASE IF NOT EXISTS contest"
clickhouse-client --host "$CH_HOST" --multiquery < \
    "$(dirname "$0")/../src/23-contest_signatures.sql" 2>/dev/null || true

# Truncate for idempotent re-run
echo "Truncating contest.signatures..."
clickhouse-client --host "$CH_HOST" --query \
    "TRUNCATE TABLE IF EXISTS contest.signatures"
echo ""

# --------------------------------------------------------------------------
# Population: per-band sequential (matches WSPR signature pattern)
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
        INSERT INTO contest.signatures
        SELECT
            cg_tx.grid_4                        AS tx_grid_4,
            cg_rx.grid_4                        AS rx_grid_4,
            c.band,
            toHour(c.timestamp)                 AS hour,
            toMonth(c.timestamp)                AS month,

            -- Anchored SNR: +10 for SSB, 0 for RTTY
            CASE WHEN c.mode = 'PH' THEN 10.0
                 WHEN c.mode = 'RY' THEN 0.0
            END                                 AS median_snr,

            count()                             AS spot_count,
            0.0                                 AS snr_std,
            1.0                                 AS reliability,

            -- Solar conditions
            avg(sol.observed_flux)              AS avg_sfi,
            avg(sol.kp_index)                   AS avg_kp,

            -- Distance from 4-char grid centroids (km)
            toUInt32(avg(
                greatCircleDistance(
                    -- TX lon, lat
                    (reinterpretAsUInt8(upper(substring(toString(cg_tx.grid_4), 1, 1))) - 65) * 20
                        + (reinterpretAsUInt8(substring(toString(cg_tx.grid_4), 3, 1)) - 48) * 2 - 180 + 1.0,
                    (reinterpretAsUInt8(upper(substring(toString(cg_tx.grid_4), 2, 1))) - 65) * 10
                        + (reinterpretAsUInt8(substring(toString(cg_tx.grid_4), 4, 1)) - 48) - 90 + 0.5,
                    -- RX lon, lat
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

        FROM contest.bronze c
        INNER JOIN wspr.callsign_grid cg_tx ON c.call_1 = cg_tx.callsign
        INNER JOIN wspr.callsign_grid cg_rx ON c.call_2 = cg_rx.callsign
        LEFT JOIN solar.bronze sol
            ON toDate(c.timestamp) = sol.date
            AND intDiv(toHour(c.timestamp), 3) = intDiv(toHour(sol.time), 3)
        WHERE c.band = ${band}
          AND c.mode IN ('PH', 'RY')
          AND cg_tx.grid_4 != ''
          AND cg_rx.grid_4 != ''
          AND c.timestamp >= '2005-01-01'
          AND c.timestamp <  '2026-01-01'
        GROUP BY tx_grid_4, rx_grid_4, c.band, hour, month, c.mode
        HAVING spot_count >= 3
        SETTINGS
            max_threads = 64,
            max_memory_usage = 80000000000,
            join_use_nulls = 0
    "

    BAND_ROWS=$(clickhouse-client --host "$CH_HOST" --query "
        SELECT count() FROM contest.signatures WHERE band = ${band}
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
    "SELECT count() FROM contest.signatures")
SSB_SIGS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM contest.signatures WHERE median_snr = 10")
RTTY_SIGS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM contest.signatures WHERE median_snr = 0")

echo ""
echo "============================================================"
echo "Population Complete — V16 Contest Signatures"
echo "============================================================"
echo "Total signatures: ${TOTAL_SIGS}"
echo "  SSB (+10 dB):   ${SSB_SIGS}"
echo "  RTTY (0 dB):    ${RTTY_SIGS}"
echo "Wall time:        ${WALL}s"
echo "============================================================"
echo ""
echo "Ready for V16 training join on M3."
echo "============================================================"
