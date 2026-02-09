#!/bin/bash
# ==============================================================================
# populate_balloon_callsigns.sh — WSPR Balloon / Telemetry Detection
# ==============================================================================
#
# Populates wspr.balloon_callsigns with three categories of non-terrestrial
# callsigns that must be excluded from V14+ model training:
#
#   1. velocity_tier     — >= 45 unique grids in a single UTC day
#   2. type2_telemetry   — Not in callsign_grid Rosetta Stone (synthetic)
#   3. reserved_prefix   — Q-prefix (ITU reserved) or invalid digit prefixes
#
# Physics rationale (Gemini Pro velocity framework):
#   A 4-char Maidenhead grid is ~200 km × 100 km. Crossing 45 grids/day
#   implies 9,000+ km of travel — only possible at high altitude (balloons)
#   or aircraft. Ground stations, maritime mobile, and vehicles cannot
#   physically achieve this.
#
# WSPR Type 2 telemetry: Pico balloon trackers (VE3KCL, SA6BSS, etc.) use
# the WSPR Type 2 protocol to encode GPS coordinates as synthetic callsigns
# and grid locators. These appear in wspr.bronze as valid-looking spots but
# are telemetry, not propagation observations from fixed locations.
#
# Prerequisites:
#   - wspr.balloon_callsigns table exists (17-balloon_callsigns.sql)
#   - wspr.bronze populated (10.8B rows)
#   - wspr.callsign_grid populated (3.64M verified operators)
#
# Expected result: ~1.51M flagged callsigns, ~276M spots (2.56% of bronze)
#   velocity_tier:    ~96 callsigns, ~160M spots
#   type2_telemetry:  ~1.2M callsigns, ~110M spots
#   reserved_prefix:  ~308K callsigns, ~6M spots
#
# Usage:
#   bash populate_balloon_callsigns.sh                   # default: 192.168.1.90
#   CH_HOST=10.60.1.1 bash populate_balloon_callsigns.sh # Thunderbolt
#
# ==============================================================================
set -e

CH_HOST="${CH_HOST:-192.168.1.90}"

echo "============================================================"
echo "Populating wspr.balloon_callsigns"
echo "Host: ${CH_HOST}"
echo "============================================================"
echo ""

# --------------------------------------------------------------------------
# Pre-flight: verify prerequisites
# --------------------------------------------------------------------------
CG_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.callsign_grid")
if [ "$CG_COUNT" -lt 1000000 ]; then
    echo "ERROR: wspr.callsign_grid has only ${CG_COUNT} rows (expected ~3.6M)"
    echo "Run callsign_grid population first."
    exit 1
fi
echo "Pre-flight: callsign_grid has ${CG_COUNT} verified operators"

BRONZE_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.bronze")
echo "Pre-flight: wspr.bronze has ${BRONZE_COUNT} spots"
echo ""

# --------------------------------------------------------------------------
# Truncate existing data for idempotent re-run
# --------------------------------------------------------------------------
echo "Truncating wspr.balloon_callsigns..."
clickhouse-client --host "$CH_HOST" --query \
    "TRUNCATE TABLE IF EXISTS wspr.balloon_callsigns"
echo ""

# --------------------------------------------------------------------------
# Step 1: Velocity Tier (>= 45 grids/day)
# --------------------------------------------------------------------------
echo "[1/3] Velocity tier (>= 45 grids/day)..."
T0=$(date +%s)

clickhouse-client --host "$CH_HOST" --query "
    INSERT INTO wspr.balloon_callsigns
    SELECT
        cs AS callsign,
        'velocity_tier' AS flag_reason,
        max_daily AS max_daily_grids,
        total_spots,
        total_grids,
        first_seen,
        last_seen
    FROM (
        SELECT
            cs,
            max(daily_grids) AS max_daily,
            sum(daily_spots) AS total_spots,
            uniqExact(g4) AS total_grids,
            min(d) AS first_seen,
            max(d) AS last_seen
        FROM (
            SELECT
                replaceAll(toString(callsign), '\0', '') AS cs,
                toDate(timestamp) AS d,
                substring(replaceAll(toString(grid), '\0', ''), 1, 4) AS g4,
                count() AS daily_spots
            FROM wspr.bronze
            WHERE match(replaceAll(toString(grid), '\0', ''), '^[A-R]{2}[0-9]{2}')
            GROUP BY cs, d, g4
        )
        GROUP BY cs, d
        HAVING uniqExact(g4) AS daily_grids >= 45
    )
    GROUP BY cs
    SETTINGS max_threads = 64, max_memory_usage = 80000000000
"

VT_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns WHERE flag_reason = 'velocity_tier'")
VT_SPOTS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT sum(total_spots) FROM wspr.balloon_callsigns WHERE flag_reason = 'velocity_tier'")
T1=$(date +%s)
echo "  Done ($(( T1 - T0 ))s): ${VT_COUNT} callsigns, ${VT_SPOTS} spots"
echo ""

# --------------------------------------------------------------------------
# Step 2: Type 2 Telemetry (not in callsign_grid)
# --------------------------------------------------------------------------
echo "[2/3] Type 2 telemetry (not in callsign_grid)..."
T0=$(date +%s)

clickhouse-client --host "$CH_HOST" --query "
    INSERT INTO wspr.balloon_callsigns
    SELECT
        cs AS callsign,
        'type2_telemetry' AS flag_reason,
        0 AS max_daily_grids,
        total_spots,
        total_grids,
        first_seen,
        last_seen
    FROM (
        SELECT
            replaceAll(toString(b.callsign), '\0', '') AS cs,
            count() AS total_spots,
            uniqExact(substring(replaceAll(toString(b.grid), '\0', ''), 1, 4)) AS total_grids,
            min(toDate(b.timestamp)) AS first_seen,
            max(toDate(b.timestamp)) AS last_seen
        FROM wspr.bronze b
        LEFT JOIN wspr.callsign_grid cg
            ON replaceAll(toString(b.callsign), '\0', '') = cg.callsign
        WHERE cg.callsign IS NULL
          AND replaceAll(toString(b.callsign), '\0', '')
              NOT IN (SELECT callsign FROM wspr.balloon_callsigns)
        GROUP BY cs
    )
    SETTINGS max_threads = 64, max_memory_usage = 80000000000
"

T2_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns WHERE flag_reason = 'type2_telemetry'")
T2_SPOTS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT sum(total_spots) FROM wspr.balloon_callsigns WHERE flag_reason = 'type2_telemetry'")
T1=$(date +%s)
echo "  Done ($(( T1 - T0 ))s): ${T2_COUNT} callsigns, ${T2_SPOTS} spots"
echo ""

# --------------------------------------------------------------------------
# Step 3: Reserved Prefixes (Q-prefix, invalid digit blocks)
# --------------------------------------------------------------------------
echo "[3/3] Reserved prefixes (Q-prefix, digit-leading non-allocated)..."
T0=$(date +%s)

clickhouse-client --host "$CH_HOST" --query "
    INSERT INTO wspr.balloon_callsigns
    SELECT
        cs AS callsign,
        'reserved_prefix' AS flag_reason,
        0 AS max_daily_grids,
        total_spots,
        total_grids,
        first_seen,
        last_seen
    FROM (
        SELECT
            replaceAll(toString(b.callsign), '\0', '') AS cs,
            count() AS total_spots,
            uniqExact(substring(replaceAll(toString(b.grid), '\0', ''), 1, 4)) AS total_grids,
            min(toDate(b.timestamp)) AS first_seen,
            max(toDate(b.timestamp)) AS last_seen
        FROM wspr.bronze b
        WHERE (
            match(replaceAll(toString(b.callsign), '\0', ''), '^Q')
            OR match(replaceAll(toString(b.callsign), '\0', ''), '^[0-9]{2}')
        )
        AND replaceAll(toString(b.callsign), '\0', '')
            NOT IN (SELECT callsign FROM wspr.balloon_callsigns)
        AND replaceAll(toString(b.callsign), '\0', '')
            NOT IN (SELECT callsign FROM wspr.callsign_grid)
        GROUP BY cs
    )
    SETTINGS max_threads = 64, max_memory_usage = 80000000000
"

RP_COUNT=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns WHERE flag_reason = 'reserved_prefix'")
RP_SPOTS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT sum(total_spots) FROM wspr.balloon_callsigns WHERE flag_reason = 'reserved_prefix'")
T1=$(date +%s)
echo "  Done ($(( T1 - T0 ))s): ${RP_COUNT} callsigns, ${RP_SPOTS} spots"
echo ""

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
TOTAL_CS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT count() FROM wspr.balloon_callsigns")
TOTAL_SPOTS=$(clickhouse-client --host "$CH_HOST" --query \
    "SELECT sum(total_spots) FROM wspr.balloon_callsigns")

echo "============================================================"
echo "Population Complete"
echo "============================================================"
echo "velocity_tier:    ${VT_COUNT} callsigns, ${VT_SPOTS} spots"
echo "type2_telemetry:  ${T2_COUNT} callsigns, ${T2_SPOTS} spots"
echo "reserved_prefix:  ${RP_COUNT} callsigns, ${RP_SPOTS} spots"
echo "------------------------------------------------------------"
echo "TOTAL:            ${TOTAL_CS} callsigns, ${TOTAL_SPOTS} spots"
echo "Contamination:    $(echo "scale=2; ${TOTAL_SPOTS} * 100 / ${BRONZE_COUNT}" | bc)%"
echo "============================================================"
