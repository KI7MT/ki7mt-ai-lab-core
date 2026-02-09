#!/bin/bash
# ==============================================================================
# populate_balloon_callsigns.sh — WSPR Balloon / Telemetry Detection V2
# ==============================================================================
#
# Populates wspr.balloon_callsigns_v2 with date-level balloon flags.
# Supersedes V1 (callsign-level) which had 99.7% false positives.
#
# V2 uses two flag categories:
#
#   1. velocity_day     — (callsign, date) pairs where >= 45 unique 4-char
#                         grids observed on a single UTC day. Only flight dates
#                         are flagged; ground-station days preserved.
#
#   2. type2_telemetry  — Callsigns NOT in callsign_grid Rosetta Stone (3.64M
#                         verified operators). These are WSPR Type 2 GPS
#                         telemetry encodings — synthetic, not real operators.
#
# Physics rationale (Gemini Pro velocity framework):
#   A 4-char Maidenhead grid is ~200 km x 100 km. Crossing 45 grids/day
#   implies 9,000+ km of travel — only possible at high altitude (balloons).
#
# CRITICAL: callsign_grid MUST have >= 3M rows or type2_telemetry detection
# will produce massive false positives (the V1 disaster).
#
# Prerequisites:
#   - wspr.balloon_callsigns_v2 table exists (21-balloon_callsigns_v2.sql)
#   - wspr.bronze populated (10.8B rows)
#   - wspr.callsign_grid populated (>= 3M verified operators)
#
# Expected result:
#   velocity_day:     ~500 (callsign, date) pairs, ~913K spots
#   type2_telemetry:  ~940 callsigns, ~37K spots
#   TOTAL:            ~1,443 entries, ~950K spots (0.009% of bronze)
#
# Usage:
#   bash populate_balloon_callsigns.sh
#   CH_HOST=10.60.1.1 bash populate_balloon_callsigns.sh
#
# ==============================================================================
set -e

CH_HOST="${CH_HOST:-192.168.1.90}"
MIN_CALLSIGN_GRID=3000000

echo "============================================================"
echo "Populating wspr.balloon_callsigns_v2 (Date-Level Detection)"
echo "Host: ${CH_HOST}"
echo "============================================================"
echo ""

# --------------------------------------------------------------------------
# Pre-flight: verify prerequisites
# --------------------------------------------------------------------------
CG_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.callsign_grid")
if [ "$CG_COUNT" -lt "$MIN_CALLSIGN_GRID" ]; then
    echo "============================================================"
    echo "ASSERTION FAILED — CALLSIGN_GRID TOO SMALL"
    echo "============================================================"
    echo "wspr.callsign_grid has ${CG_COUNT} rows (minimum: ${MIN_CALLSIGN_GRID})"
    echo ""
    echo "Type2 telemetry detection requires a full Rosetta Stone."
    echo "Without it, legitimate operators will be flagged as telemetry."
    echo ""
    echo "Run: bash populate_callsign_grid.sh"
    echo "============================================================"
    exit 1
fi
echo "Pre-flight: callsign_grid has ${CG_COUNT} verified operators [OK]"

BRONZE_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.bronze")
echo "Pre-flight: wspr.bronze has ${BRONZE_COUNT} spots"
echo ""

# --------------------------------------------------------------------------
# Truncate existing data for idempotent re-run
# --------------------------------------------------------------------------
echo "Truncating wspr.balloon_callsigns_v2..."
clickhouse-client --host "$CH_HOST" --query \
    "TRUNCATE TABLE IF EXISTS wspr.balloon_callsigns_v2"
echo ""

# --------------------------------------------------------------------------
# Step 1: Velocity Day (>= 45 grids on a specific date)
# --------------------------------------------------------------------------
echo "[1/2] Velocity day (>= 45 grids/day, per-date)..."
T0=$(date +%s)

clickhouse-client --host "$CH_HOST" --query "
    INSERT INTO wspr.balloon_callsigns_v2
    SELECT
        cs AS callsign,
        'velocity_day' AS flag_reason,
        d AS flag_date,
        daily_grids,
        daily_spots AS total_spots
    FROM (
        SELECT
            replaceAll(toString(callsign), '\0', '') AS cs,
            toDate(timestamp) AS d,
            uniqExact(substring(replaceAll(toString(grid), '\0', ''), 1, 4)) AS daily_grids,
            count() AS daily_spots
        FROM wspr.bronze
        WHERE match(replaceAll(toString(grid), '\0', ''), '^[A-R]{2}[0-9]{2}')
        GROUP BY cs, d
        HAVING daily_grids >= 45
    )
    SETTINGS max_threads = 64, max_memory_usage = 80000000000
"

VD_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns_v2 WHERE flag_reason = 'velocity_day'")
VD_CALLS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT uniqExact(callsign) FROM wspr.balloon_callsigns_v2 WHERE flag_reason = 'velocity_day'")
VD_SPOTS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT sum(total_spots) FROM wspr.balloon_callsigns_v2 WHERE flag_reason = 'velocity_day'")
T1=$(date +%s)
echo "  Done ($(( T1 - T0 ))s): ${VD_COUNT} (callsign,date) pairs from ${VD_CALLS} callsigns, ${VD_SPOTS} spots"
echo ""

# --------------------------------------------------------------------------
# Step 2: Type 2 Telemetry (not in callsign_grid Rosetta Stone)
# --------------------------------------------------------------------------
echo "[2/2] Type 2 telemetry (not in callsign_grid)..."
T0=$(date +%s)

clickhouse-client --host "$CH_HOST" --query "
    INSERT INTO wspr.balloon_callsigns_v2
    SELECT
        cs AS callsign,
        'type2_telemetry' AS flag_reason,
        toDate('1970-01-01') AS flag_date,
        0 AS daily_grids,
        total_spots
    FROM (
        SELECT
            replaceAll(toString(b.callsign), '\0', '') AS cs,
            count() AS total_spots
        FROM wspr.bronze b
        LEFT JOIN wspr.callsign_grid cg
            ON replaceAll(toString(b.callsign), '\0', '') = cg.callsign
        WHERE cg.callsign IS NULL
          AND replaceAll(toString(b.callsign), '\0', '')
              NOT IN (SELECT callsign FROM wspr.balloon_callsigns_v2)
        GROUP BY cs
    )
    SETTINGS max_threads = 64, max_memory_usage = 80000000000
"

T2_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns_v2 WHERE flag_reason = 'type2_telemetry'")
T2_SPOTS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT sum(total_spots) FROM wspr.balloon_callsigns_v2 WHERE flag_reason = 'type2_telemetry'")
T1=$(date +%s)
echo "  Done ($(( T1 - T0 ))s): ${T2_COUNT} callsigns, ${T2_SPOTS} spots"
echo ""

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
TOTAL_ENTRIES=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns_v2")
TOTAL_SPOTS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT sum(total_spots) FROM wspr.balloon_callsigns_v2")

echo "============================================================"
echo "Population Complete — V2 Date-Level Detection"
echo "============================================================"
echo "velocity_day:     ${VD_COUNT} (callsign,date) pairs (${VD_CALLS} unique callsigns), ${VD_SPOTS} spots"
echo "type2_telemetry:  ${T2_COUNT} callsigns, ${T2_SPOTS} spots"
echo "------------------------------------------------------------"
echo "TOTAL:            ${TOTAL_ENTRIES} entries, ${TOTAL_SPOTS} spots"
echo "Contamination:    $(echo "scale=4; ${TOTAL_SPOTS} * 100 / ${BRONZE_COUNT}" | bc)%"
echo "============================================================"
echo ""
echo "Compare to V1: 1.51M entries, 276M spots (2.56%) — 99.7% false positives"
echo "V2 precision:  ~${TOTAL_ENTRIES} entries, ~${TOTAL_SPOTS} spots — surgical"
echo "============================================================"
