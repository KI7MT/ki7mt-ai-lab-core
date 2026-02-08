#!/bin/bash
# ==============================================================================
# populate_v6_clean.sh — Phase 6: Clean Kp Constraint Training Set
# ==============================================================================
#
# Populates wspr.gold_v6 from wspr.gold_continuous by adding
# the kp_penalty = 1.0 - kp/9.0 constraint column. All IFW weights preserved.
#
# Phase 6 context: Phase 5.2 showed Kp inversion (+6.1 dB from Kp 0->9)
# because raw kp correlates with high SFI in the data. The kp_penalty column
# gives the model an explicit absorption-direction view of Kp:
#   Kp=0 (quiet) -> kp_penalty=1.0 (no penalty)
#   Kp=9 (storm) -> kp_penalty=0.0 (full penalty)
#
# Prerequisites:
#   - wspr.gold_v6 table exists (15-gold_v6.sql)
#   - wspr.gold_continuous populated (10M rows, populate_continuous.sh)
#
# Expected result: 10M rows (exact copy of gold_continuous + kp_penalty)
#
# Usage:
#   bash populate_v6_clean.sh                   # default: 192.168.1.90
#   CH_HOST=10.60.1.1 bash populate_v6_clean.sh # Thunderbolt
#
# ==============================================================================
set -e

CH_HOST="${CH_HOST:-192.168.1.90}"

START_TIME=$(date +%s)

echo "============================================================"
echo "Phase 6: Populating wspr.gold_v6"
echo "Source: wspr.gold_continuous (10M rows)"
echo "Host: ${CH_HOST}"
echo "============================================================"
echo ""

SOURCE_ROWS=$(clickhouse-client --host "$CH_HOST" --query "SELECT count() FROM wspr.gold_continuous")
echo "Source rows (gold_continuous): ${SOURCE_ROWS}"

if [ "$SOURCE_ROWS" -eq 0 ]; then
    echo "ERROR: wspr.gold_continuous is empty. Run populate_continuous.sh first."
    exit 1
fi

echo "Inserting with kp_penalty = 1.0 - kp/9.0 ..."

clickhouse-client --host "$CH_HOST" --query "
    INSERT INTO wspr.gold_v6
    SELECT
        snr,
        distance,
        band,
        hour,
        month,
        azimuth,
        tx_grid,
        rx_grid,
        ssn,
        sfi,
        kp,
        midpoint_lat,
        sampling_weight,
        sfi_dist_interact,
        1.0 - (kp / 9.0) AS kp_penalty
    FROM wspr.gold_continuous
"

END_TIME=$(date +%s)
WALL=$(( END_TIME - START_TIME ))

ACTUAL=$(clickhouse-client --host "$CH_HOST" --query "SELECT count() FROM wspr.gold_v6")

echo ""
echo "============================================================"
echo "Population Complete"
echo "============================================================"
echo "Total rows: ${ACTUAL}"
echo "Wall time: ${WALL}s"
echo "============================================================"
