#!/bin/bash
# ==============================================================================
# populate_signatures_v2_terrestrial.sh — Step F v2: Balloon-Filtered Signatures
# ==============================================================================
#
# Same aggregation as signatures_v1 but excludes spots contaminated by balloon
# or telemetry callsigns using wspr.balloon_callsigns_v2 (date-level detection).
#
# Two-layer filter (V2 corrected):
#   - type2_telemetry: callsign-level exclusion (synthetic WSPR Type 2 GPS
#     encodings — not real amateur operators)
#   - velocity_day: (callsign, date) exclusion (only specific flight dates
#     removed — ground-station days preserved)
#
# Standard filters (same as V1):
#   - HF bands only (102-111)
#   - Distance >= 500 km (ground-wave rejection)
#   - HAVING spot_count >= 5 (noise floor rejection)
#   - Median via quantile(0.5) (site entropy filter)
#
# V2 corrected results (vs V1):
#   V1 (all):            93,352,578 signatures
#   V2 (broken filter):  89,898,009 — removed 3.46M (3.70%), mostly false positives
#   V2 (corrected):      93,332,503 — removed 20,075 (0.021%), surgical precision
#
# Prerequisites:
#   - wspr.signatures_v2_terrestrial table exists (20-signatures_v2_terrestrial.sql)
#   - wspr.bronze populated (10.8B rows)
#   - solar.bronze populated (76K+ rows)
#   - wspr.balloon_callsigns_v2 populated (scripts/populate_balloon_callsigns.sh)
#   - wspr.callsign_grid populated (>= 3M rows — required for balloon detection)
#
# Expected result: ~93.3M signature rows (V1 minus 20K balloon contamination)
# Total time on 9975WX: ~3-4 min
#
# Usage:
#   bash populate_signatures_v2_terrestrial.sh
#   CH_HOST=10.60.1.1 bash populate_signatures_v2_terrestrial.sh
#
# ==============================================================================
set -e

CH_HOST="${CH_HOST:-192.168.1.90}"

TOTAL=0
START_TIME=$(date +%s)

# --------------------------------------------------------------------------
# Pre-flight checks
# --------------------------------------------------------------------------
BALLOON_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns_v2")
if [ "$BALLOON_COUNT" -lt 100 ]; then
    echo "ERROR: wspr.balloon_callsigns_v2 has only ${BALLOON_COUNT} rows (expected ~1,400)"
    echo "Run populate_balloon_callsigns.sh first."
    exit 1
fi

VD_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns_v2 WHERE flag_reason = 'velocity_day'")
T2_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns_v2 WHERE flag_reason = 'type2_telemetry'")

echo "============================================================"
echo "Step F v2: Populating wspr.signatures_v2_terrestrial"
echo "Target: ~93.3M rows (V1 minus surgical balloon exclusion)"
echo "Host: ${CH_HOST}"
echo "Balloon V2 exclusions: ${BALLOON_COUNT} entries"
echo "  velocity_day:    ${VD_COUNT} (callsign,date) pairs"
echo "  type2_telemetry: ${T2_COUNT} callsigns"
echo "============================================================"
echo ""

# Truncate for idempotent re-run
echo "Truncating wspr.signatures_v2_terrestrial..."
clickhouse-client --host "$CH_HOST" --query \
    "TRUNCATE TABLE IF EXISTS wspr.signatures_v2_terrestrial"

# Verify truncation
VERIFY=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.signatures_v2_terrestrial")
if [ "$VERIFY" -ne 0 ]; then
    echo "ERROR: Truncation failed — table still has ${VERIFY} rows"
    exit 1
fi
echo "Verified: table empty (0 rows)"
echo ""

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
        INSERT INTO wspr.signatures_v2_terrestrial
        SELECT
            substring(s.grid, 1, 4)          AS tx_grid_4,
            substring(s.reporter_grid, 1, 4) AS rx_grid_4,
            s.band,
            toHour(s.timestamp)              AS hour,
            toMonth(s.timestamp)             AS month,
            quantile(0.5)(s.snr)             AS median_snr,
            count()                          AS spot_count,
            stddevPop(s.snr)                 AS snr_std,
            countIf(s.snr > -20) / count()   AS reliability,
            avg(sol.observed_flux)           AS avg_sfi,
            avg(sol.kp_index)                AS avg_kp,
            avg(s.distance)                  AS avg_distance,
            avg(s.azimuth)                   AS avg_azimuth
        FROM wspr.bronze s
        LEFT JOIN solar.bronze sol
            ON toDate(s.timestamp) = sol.date
            AND intDiv(toHour(s.timestamp), 3) = intDiv(toHour(sol.time), 3)
        WHERE s.band = ${band}
          AND s.distance >= 500
          AND replaceAll(toString(s.callsign), '\0', '')
              NOT IN (SELECT callsign FROM wspr.balloon_callsigns_v2
                      WHERE flag_reason = 'type2_telemetry')
          AND replaceAll(toString(s.reporter), '\0', '')
              NOT IN (SELECT callsign FROM wspr.balloon_callsigns_v2
                      WHERE flag_reason = 'type2_telemetry')
          AND (replaceAll(toString(s.callsign), '\0', ''), toDate(s.timestamp))
              NOT IN (SELECT callsign, flag_date FROM wspr.balloon_callsigns_v2
                      WHERE flag_reason = 'velocity_day')
        GROUP BY tx_grid_4, rx_grid_4, s.band, hour, month
        HAVING spot_count >= 5
        SETTINGS
            max_threads = 64,
            max_memory_usage = 80000000000,
            max_bytes_before_external_group_by = 20000000000,
            join_use_nulls = 0
    "

    BAND_ROWS=$(clickhouse-client --host "$CH_HOST" --query "
        SELECT count() FROM wspr.signatures_v2_terrestrial WHERE band = ${band}
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

V2_TOTAL=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.signatures_v2_terrestrial")
V1_TOTAL=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.signatures_v1")
DELTA=$(( V1_TOTAL - V2_TOTAL ))
PCT=$(echo "scale=3; ${DELTA} * 100 / ${V1_TOTAL}" | bc)

echo ""
echo "============================================================"
echo "Population Complete — V2 Corrected"
echo "============================================================"
echo "V2 terrestrial: ${V2_TOTAL} signatures"
echo "V1 (all):       ${V1_TOTAL} signatures"
echo "Delta:          ${DELTA} signatures removed (${PCT}% — balloon contamination)"
echo "Wall time:      ${WALL}s"
echo "============================================================"
echo ""
echo "This table is ready for V14-TP-v2 training on M3."
echo "============================================================"
