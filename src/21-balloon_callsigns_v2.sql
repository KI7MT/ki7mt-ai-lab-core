-- ==============================================================================
-- Name..........: @PROGRAM@ - WSPR Balloon / Telemetry V2 (Date-Level Flags)
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Date-level balloon/telemetry detection. Supersedes V1
--                 (17-balloon_callsigns.sql) which flagged entire callsigns —
--                 producing 99.7% false positives because operators like K1TE
--                 and NI5F are ground stations 87-99% of the time but
--                 occasionally launch pico balloons.
--
--                 V2 uses two flag categories:
--
--                 1. velocity_day — (callsign, date) pairs where the callsign
--                    was observed in >= 45 unique 4-char grids on that specific
--                    UTC date. Only the balloon flight days are flagged, not
--                    the operator's entire history. At 200 km per grid, 45
--                    grids/day = 9,000+ km travel, only possible at altitude.
--
--                 2. type2_telemetry — Callsigns NOT present in the
--                    callsign_grid Rosetta Stone (3.64M verified amateur
--                    operators from 10.8B WSPR spots). These are WSPR Type 2
--                    protocol GPS telemetry encodings — synthetic callsigns
--                    that look valid but are not real operators.
--
--                 V2 results (vs V1):
--                   V1: 1.51M entries, 276M spots (2.56%) — 99.7% false positives
--                   V2: 1,443 entries, 950K spots (0.009%) — surgical precision
--                   Signature impact: V1 removed 3.46M (3.70%), V2 removes 20K (0.021%)
--
--                 IMPORTANT: wspr.callsign_grid MUST be populated (3M+ rows)
--                 before running type2_telemetry detection. If callsign_grid is
--                 empty, nearly all callsigns will be falsely flagged as telemetry.
--                 The population script enforces this with a pre-flight assertion.
--
--                 Population script: scripts/populate_balloon_callsigns.sh
-- ==============================================================================

CREATE TABLE IF NOT EXISTS wspr.balloon_callsigns_v2 (
    callsign    String                 COMMENT 'Callsign (uppercase, trimmed)',
    flag_reason LowCardinality(String) COMMENT 'velocity_day | type2_telemetry',
    flag_date   Date DEFAULT '1970-01-01'
                                       COMMENT 'Date of balloon flight (velocity_day) or epoch (type2_telemetry)',
    daily_grids UInt16                 COMMENT 'Unique 4-char grids on flag_date (velocity_day only)',
    total_spots UInt64                 COMMENT 'Spots on flag_date (velocity_day) or all time (type2_telemetry)'
) ENGINE = MergeTree()
ORDER BY (callsign, flag_date)
COMMENT 'V2 date-level balloon/telemetry flags. velocity_day: (callsign,date) pairs with >=45 grids/day. type2_telemetry: not in callsign_grid Rosetta Stone.';

-- ==============================================================================
-- Population Step 1: Velocity Day (>= 45 grids/day, per-date)
-- ==============================================================================
-- Identifies (callsign, date) pairs where the callsign crossed 45+ unique
-- 4-char Maidenhead grids in a single UTC day. Only the specific flight dates
-- are flagged — the operator's ground-station activity is preserved.
--
-- INSERT INTO wspr.balloon_callsigns_v2
-- SELECT
--     cs AS callsign,
--     'velocity_day' AS flag_reason,
--     d AS flag_date,
--     daily_grids,
--     daily_spots AS total_spots
-- FROM (
--     SELECT
--         replaceAll(toString(callsign), '\0', '') AS cs,
--         toDate(timestamp) AS d,
--         uniqExact(substring(replaceAll(toString(grid), '\0', ''), 1, 4)) AS daily_grids,
--         count() AS daily_spots
--     FROM wspr.bronze
--     WHERE match(replaceAll(toString(grid), '\0', ''), '^[A-R]{2}[0-9]{2}')
--     GROUP BY cs, d
--     HAVING daily_grids >= 45
-- )
-- SETTINGS max_threads = 64, max_memory_usage = 80000000000;

-- ==============================================================================
-- Population Step 2: Type 2 Telemetry (not in callsign_grid Rosetta Stone)
-- ==============================================================================
-- WSPR Type 2 protocol encodes GPS telemetry as synthetic callsigns. These
-- are NOT in the callsign_grid Rosetta Stone (3.64M verified operators from
-- 10.8B WSPR TX+RX records). Must run AFTER callsign_grid is populated and
-- AFTER velocity_day rows are inserted (to avoid double-counting).
--
-- CRITICAL: callsign_grid must have >= 3M rows or this will produce massive
-- false positives (the V1 disaster that flagged 1.2M legitimate operators).
--
-- INSERT INTO wspr.balloon_callsigns_v2
-- SELECT
--     cs AS callsign,
--     'type2_telemetry' AS flag_reason,
--     toDate('1970-01-01') AS flag_date,
--     0 AS daily_grids,
--     total_spots
-- FROM (
--     SELECT
--         replaceAll(toString(b.callsign), '\0', '') AS cs,
--         count() AS total_spots
--     FROM wspr.bronze b
--     LEFT JOIN wspr.callsign_grid cg
--         ON replaceAll(toString(b.callsign), '\0', '') = cg.callsign
--     WHERE cg.callsign IS NULL
--       AND replaceAll(toString(b.callsign), '\0', '')
--           NOT IN (SELECT callsign FROM wspr.balloon_callsigns_v2)
--     GROUP BY cs
-- )
-- SETTINGS max_threads = 64, max_memory_usage = 80000000000;
