#!/bin/bash
# ==============================================================================
# populate_signatures_v2_terrestrial.sh — Step F v2: Balloon-Filtered Signatures
# ==============================================================================
#
# Same aggregation as populate_signatures.sh (V1) but excludes callsigns
# flagged in wspr.balloon_callsigns on BOTH TX and RX sides.
#
# Filters (same as V1):
#   - HF bands only (102-111)
#   - Distance >= 500 km (ground-wave rejection)
#   - HAVING spot_count >= 5 (noise floor rejection)
#   - Median via quantile(0.5) (site entropy filter)
#
# Additional filter (V2):
#   - TX callsign NOT IN wspr.balloon_callsigns
#   - RX reporter NOT IN wspr.balloon_callsigns
#
# Prerequisites:
#   - wspr.signatures_v2_terrestrial table exists (20-signatures_v2_terrestrial.sql)
#   - wspr.bronze populated (10.8B rows)
#   - solar.bronze populated (76K+ rows)
#   - wspr.balloon_callsigns populated (1.51M flagged callsigns)
#
# Expected result: ~91-92M signature rows (vs 93.4M in V1)
# Total time on 9975WX: ~3-4 min (similar to V1)
#
# Usage:
#   bash populate_signatures_v2_terrestrial.sh
#   CH_HOST=10.60.1.1 bash populate_signatures_v2_terrestrial.sh
#
# ==============================================================================
set -e

CH_HOST="${CH_HOST:-192.168.1.90}"
BANDS=(102 103 104 105 106 107 108 109 110 111)
BAND_NAMES=("160m" "80m" "60m" "40m" "30m" "20m" "17m" "15m" "12m" "10m")

TOTAL=0
START_TIME=$(date +%s)

# --------------------------------------------------------------------------
# Pre-flight checks
# --------------------------------------------------------------------------
BALLOON_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns")
if [ "$BALLOON_COUNT" -lt 1000 ]; then
    echo "ERROR: wspr.balloon_callsigns has only ${BALLOON_COUNT} rows (expected ~1.5M)"
    echo "Run populate_balloon_callsigns.sh first."
    exit 1
fi

echo "============================================================"
echo "Step F v2: Populating wspr.signatures_v2_terrestrial"
echo "Target: ~91-92M rows (V1 minus balloon contamination)"
echo "Host: ${CH_HOST}"
echo "Balloon exclusions: ${BALLOON_COUNT} callsigns"
echo "============================================================"
echo ""

# Truncate for idempotent re-run
clickhouse-client --host "$CH_HOST" --query \
    "TRUNCATE TABLE IF EXISTS wspr.signatures_v2_terrestrial"

for bi in "${!BANDS[@]}"; do
    band=${BANDS[$bi]}
    bname=${BAND_NAMES[$bi]}

    printf "[%2d/10] Band %d (%s) ... " "$((bi+1))" "$band" "$bname"

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
              NOT IN (SELECT callsign FROM wspr.balloon_callsigns)
          AND replaceAll(toString(s.reporter), '\0', '')
              NOT IN (SELECT callsign FROM wspr.balloon_callsigns)
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

echo ""
echo "============================================================"
echo "Population Complete"
echo "============================================================"
echo "V2 terrestrial: ${V2_TOTAL} signatures"
echo "V1 (all):       ${V1_TOTAL} signatures"
echo "Delta:          ${DELTA} signatures removed (balloon contamination)"
echo "Wall time:      ${WALL}s"
echo "============================================================"
