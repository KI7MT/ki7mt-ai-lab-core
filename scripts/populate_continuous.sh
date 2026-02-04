#!/bin/bash
# ==============================================================================
# populate_continuous.sh — Phase 5.2 IFW-Weighted Training Table
# ==============================================================================
#
# Populates wspr.training_continuous with 10M rows using Efraimidis-Spirakis
# weighted reservoir sampling against a 2D (SSN, midpoint_lat) density
# histogram. Eliminates stair-step artifacts from discrete SSN quintile bins.
#
# Prerequisites:
#   - wspr.training_continuous table exists (05-training_continuous.sql)
#   - wspr.spots_raw populated (10.8B rows)
#   - solar.indices_raw populated (76K+ rows)
#
# Reproducibility:
#   All sampling uses cityHash64 (deterministic). Given the same source data
#   in spots_raw and indices_raw, this script produces identical output.
#   The density histogram is built from a deterministic 10M-row sample of
#   band 107 (20m), ordered by cityHash64(toString(timestamp)).
#
# Usage:
#   bash populate_continuous.sh                   # default: 192.168.1.90
#   CH_HOST=10.60.1.1 bash populate_continuous.sh # Thunderbolt
#
# ==============================================================================
set -e

CH_HOST="${CH_HOST:-192.168.1.90}"
BANDS=(102 103 104 105 106 107 108 109 110 111)
BAND_NAMES=("160m" "80m" "60m" "40m" "30m" "20m" "17m" "15m" "12m" "10m")

# Date range for training data (must match training script)
DATE_START="2020-01-01"
DATE_END="2026-02-04"

# Density histogram parameters
DENSITY_SAMPLE_BAND=107       # 20m — most data, representative SSN distribution
DENSITY_SAMPLE_LIMIT=10000000 # 10M rows for density estimation
DENSITY_SSN_BIN_WIDTH=20      # SSN bin width for density cells
DENSITY_LAT_BIN_WIDTH=10      # Latitude bin width (degrees) for density cells
DENSITY_FLOOR=50              # Minimum cell count (caps max oversampling ~126x)

ROWS_PER_BAND=1000000         # 1M per band = 10M total

TOTAL=0
START_TIME=$(date +%s)

echo "============================================================"
echo "Phase 5.2: Populating wspr.training_continuous"
echo "Target: 10M rows (10 bands x ${ROWS_PER_BAND}, IFW-weighted)"
echo "Host: ${CH_HOST}"
echo "Date range: ${DATE_START} to ${DATE_END}"
echo "============================================================"
echo ""

# ── Phase A: Build density histogram ──────────────────────────────
echo "Step 1/3: Building IFW density histogram..."
echo "  Sampling ${DENSITY_SAMPLE_LIMIT} rows from band ${DENSITY_SAMPLE_BAND}..."

clickhouse-client --host "$CH_HOST" --query "DROP TABLE IF EXISTS wspr._ifw_sample"
clickhouse-client --host "$CH_HOST" --query "DROP TABLE IF EXISTS wspr._ifw_density"

clickhouse-client --host "$CH_HOST" --query "
CREATE TABLE wspr._ifw_sample ENGINE = Memory AS
SELECT
    intDiv(toUInt32(sol.ssn), ${DENSITY_SSN_BIN_WIDTH}) AS ssn_bin,
    intDiv(toInt32(
        ((reinterpretAsUInt8(substring(toString(s.grid), 2, 1)) - 65) * 10
          + (reinterpretAsUInt8(substring(toString(s.grid), 4, 1)) - 48)
          + (reinterpretAsUInt8(substring(toString(s.reporter_grid), 2, 1)) - 65) * 10
          + (reinterpretAsUInt8(substring(toString(s.reporter_grid), 4, 1)) - 48)
        ) / 2.0 - 90 + 0.5
    ), ${DENSITY_LAT_BIN_WIDTH}) AS lat_bin
FROM wspr.spots_raw s
INNER JOIN (
    SELECT date, intDiv(toHour(time), 3) AS bucket,
           max(ssn) AS ssn
    FROM solar.indices_raw FINAL
    GROUP BY date, bucket
) sol ON toDate(s.timestamp) = sol.date
     AND intDiv(toHour(s.timestamp), 3) = sol.bucket
WHERE s.band = ${DENSITY_SAMPLE_BAND}
  AND s.timestamp >= '${DATE_START}' AND s.timestamp < '${DATE_END}'
  AND s.snr BETWEEN -35 AND 25
  AND s.distance BETWEEN 500 AND 18000
  AND length(toString(s.grid)) >= 4
  AND length(toString(s.reporter_grid)) >= 4
ORDER BY cityHash64(toString(s.timestamp))
LIMIT ${DENSITY_SAMPLE_LIMIT}
SETTINGS max_execution_time=300, max_memory_usage=40000000000
"

clickhouse-client --host "$CH_HOST" --query "
CREATE TABLE wspr._ifw_density ENGINE = Memory AS
SELECT
    ssn_bin,
    lat_bin,
    count() AS cell_count
FROM wspr._ifw_sample
GROUP BY ssn_bin, lat_bin
"

clickhouse-client --host "$CH_HOST" --query "DROP TABLE wspr._ifw_sample"

CELLS=$(clickhouse-client --host "$CH_HOST" --query "SELECT count() FROM wspr._ifw_density")
MIN_D=$(clickhouse-client --host "$CH_HOST" --query "SELECT min(cell_count) FROM wspr._ifw_density")
MAX_D=$(clickhouse-client --host "$CH_HOST" --query "SELECT max(cell_count) FROM wspr._ifw_density")
echo "  Density histogram: ${CELLS} cells (min=${MIN_D}, max=${MAX_D})"
echo ""

# ── Phase B: Weighted INSERT queries ─────────────────────────────
echo "Step 2/3: Weighted sampling (10 bands x ${ROWS_PER_BAND} rows)..."
echo "============================================================"

for bi in "${!BANDS[@]}"; do
    band=${BANDS[$bi]}
    bname=${BAND_NAMES[$bi]}

    printf "[%2d/10] Band %d (%s) ... " "$((bi+1))" "$band" "$bname"

    T0=$(date +%s%N)

    clickhouse-client --host "$CH_HOST" --query "
        INSERT INTO wspr.training_continuous
        SELECT
            s.snr,
            s.distance,
            s.band,
            toHour(s.timestamp) AS hour,
            toMonth(s.timestamp) AS month,
            s.azimuth,
            toString(s.grid) AS tx_grid,
            toString(s.reporter_grid) AS rx_grid,
            sol.ssn,
            sol.sfi,
            sol.kp,
            ((reinterpretAsUInt8(substring(toString(s.grid), 2, 1)) - 65) * 10
              + (reinterpretAsUInt8(substring(toString(s.grid), 4, 1)) - 48) - 90 + 0.5
              + (reinterpretAsUInt8(substring(toString(s.reporter_grid), 2, 1)) - 65) * 10
              + (reinterpretAsUInt8(substring(toString(s.reporter_grid), 4, 1)) - 48) - 90 + 0.5
            ) / 2.0 AS midpoint_lat,
            1.0 / sqrt(toFloat64(greatest(d.cell_count, ${DENSITY_FLOOR}))) AS sampling_weight,
            sol.sfi * log10(toFloat64(greatest(s.distance, 1))) AS sfi_dist_interact
        FROM wspr.spots_raw s
        INNER JOIN (
            SELECT date, intDiv(toHour(time), 3) AS bucket,
                   max(ssn) AS ssn, max(observed_flux) AS sfi, max(kp_index) AS kp
            FROM solar.indices_raw FINAL
            GROUP BY date, bucket
        ) sol ON toDate(s.timestamp) = sol.date
             AND intDiv(toHour(s.timestamp), 3) = sol.bucket
        LEFT JOIN wspr._ifw_density d
            ON d.ssn_bin = intDiv(toUInt32(sol.ssn), ${DENSITY_SSN_BIN_WIDTH})
            AND d.lat_bin = intDiv(toInt32(
                ((reinterpretAsUInt8(substring(toString(s.grid), 2, 1)) - 65) * 10
                  + (reinterpretAsUInt8(substring(toString(s.grid), 4, 1)) - 48)
                  + (reinterpretAsUInt8(substring(toString(s.reporter_grid), 2, 1)) - 65) * 10
                  + (reinterpretAsUInt8(substring(toString(s.reporter_grid), 4, 1)) - 48)
                ) / 2.0 - 90 + 0.5
            ), ${DENSITY_LAT_BIN_WIDTH})
        WHERE s.band = ${band}
          AND s.timestamp >= '${DATE_START}' AND s.timestamp < '${DATE_END}'
          AND s.snr BETWEEN -35 AND 25
          AND s.distance BETWEEN 500 AND 18000
          AND length(toString(s.grid)) >= 4
          AND length(toString(s.reporter_grid)) >= 4
        ORDER BY
            log(1e-18 + toFloat64(
                cityHash64(toString(s.timestamp), toString(s.grid), toString(s.reporter_grid))
                % 4294967296
            ) / 4294967296.0)
            * sqrt(toFloat64(greatest(d.cell_count, ${DENSITY_FLOOR})))
        DESC
        LIMIT ${ROWS_PER_BAND}
        SETTINGS max_execution_time=600,
                 max_memory_usage=80000000000,
                 max_bytes_before_external_sort=10000000000,
                 max_bytes_before_external_group_by=20000000000,
                 max_threads=16
    "

    T1=$(date +%s%N)
    ELAPSED=$(( (T1 - T0) / 1000000 ))
    TOTAL=$(( TOTAL + ROWS_PER_BAND ))
    printf "done (%d.%ds) | cumulative: %s\n" "$((ELAPSED/1000))" "$((ELAPSED%1000/100))" "$(printf '%d' $TOTAL)"
done

# ── Phase C: Cleanup ─────────────────────────────────────────────
echo ""
echo "Step 3/3: Cleanup..."
clickhouse-client --host "$CH_HOST" --query "DROP TABLE IF EXISTS wspr._ifw_density"
echo "  Density table dropped."

END_TIME=$(date +%s)
WALL=$(( END_TIME - START_TIME ))

ACTUAL=$(clickhouse-client --host "$CH_HOST" --query "SELECT count() FROM wspr.training_continuous")

echo ""
echo "============================================================"
echo "Population Complete"
echo "============================================================"
echo "Total rows: ${ACTUAL}"
echo "Wall time: ${WALL}s"
echo "============================================================"
