#!/bin/bash
# ==============================================================================
# populate_signatures.sh — Step F: Aggregated WSPR Signatures
# ==============================================================================
#
# Populates wspr.signatures_v1 with median-based physical buckets from
# 10.8B WSPR spots + solar indices. Runs per-band to stay within memory.
#
# Dimensions: tx_grid_4, rx_grid_4, band, hour, month
# Metrics:    median SNR, spot count, SNR stddev, reliability, avg SFI/Kp
#
# Filters:
#   - HF bands only (102-111)
#   - Distance >= 500 km (ground-wave rejection)
#   - HAVING spot_count >= 5 (noise floor rejection)
#   - Median via quantile(0.5) resists outliers ("Site Entropy" filter)
#
# Prerequisites:
#   - wspr.signatures_v1 table exists (12-signatures_v1.sql)
#   - wspr.bronze populated (10.8B rows)
#   - solar.bronze populated (76K+ rows)
#
# Expected result: ~93.8M signature rows (115:1 compression from raw spots)
# Total time on 9975WX (128-thread, 10.8B rows): ~3 min 10 sec
#
# Usage:
#   bash populate_signatures.sh                   # default: 192.168.1.90
#   CH_HOST=10.60.1.1 bash populate_signatures.sh # Thunderbolt
#
# ==============================================================================
set -e

CH_HOST="${CH_HOST:-192.168.1.90}"
BANDS=(102 103 104 105 106 107 108 109 110 111)
BAND_NAMES=("160m" "80m" "60m" "40m" "30m" "20m" "17m" "15m" "12m" "10m")

TOTAL=0
START_TIME=$(date +%s)

echo "============================================================"
echo "Step F: Populating wspr.signatures_v1"
echo "Target: ~93.8M rows (10 HF bands, median-bucketed)"
echo "Host: ${CH_HOST}"
echo "============================================================"
echo ""

for bi in "${!BANDS[@]}"; do
    band=${BANDS[$bi]}
    bname=${BAND_NAMES[$bi]}

    printf "[%2d/10] Band %d (%s) ... " "$((bi+1))" "$band" "$bname"

    T0=$(date +%s%N)

    INSERTED=$(clickhouse-client --host "$CH_HOST" --query "
        INSERT INTO wspr.signatures_v1
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
        GROUP BY tx_grid_4, rx_grid_4, s.band, hour, month
        HAVING spot_count >= 5
        SETTINGS
            max_threads = 64,
            max_memory_usage = 80000000000,
            max_bytes_before_external_group_by = 20000000000,
            join_use_nulls = 0
    " 2>&1)

    BAND_ROWS=$(clickhouse-client --host "$CH_HOST" --query "
        SELECT count() FROM wspr.signatures_v1 WHERE band = ${band}
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

ACTUAL=$(clickhouse-client --host "$CH_HOST" --query "SELECT count() FROM wspr.signatures_v1")

echo ""
echo "============================================================"
echo "Population Complete"
echo "============================================================"
echo "Total rows: ${ACTUAL}"
echo "Wall time: ${WALL}s"
echo "============================================================"
