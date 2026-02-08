-- ============================================================================
-- ki7mt-ai-lab-core: Callsign → Grid Rosetta Stone
-- ============================================================================
-- Maps callsigns to their most-used 6-char Maidenhead grid from WSPR data.
-- Primary use: enriching RBN spots (which have no grid squares) with location.
--
-- Sources: wspr.spots_raw TX callsigns (callsign→grid) and RX (reporter→reporter_grid)
-- ReplacingMergeTree deduplicates by most recent last_seen across TX/RX inserts.
--
-- Expected: ~3.5M TX + ~50K RX = ~3.6M unique callsigns with grids.
-- ============================================================================

CREATE TABLE IF NOT EXISTS wspr.callsign_grid (
    callsign    String         COMMENT 'Callsign (uppercase, trimmed)',
    grid        FixedString(6) COMMENT 'Most common 6-char Maidenhead grid',
    grid_4      FixedString(4) COMMENT 'Field-level 4-char grid',
    spot_count  UInt32         COMMENT 'Total spots for this callsign',
    last_seen   Date           COMMENT 'Most recent spot date'
) ENGINE = ReplacingMergeTree(last_seen)
ORDER BY callsign
COMMENT 'Callsign→Grid Rosetta Stone from WSPR spots_raw (TX + RX)';

-- ============================================================================
-- Population: TX callsigns (callsign → grid)
-- ============================================================================
-- INSERT INTO wspr.callsign_grid
-- SELECT
--     replaceAll(toString(callsign), '\0', '')       AS callsign,
--     substring(replaceAll(toString(grid), '\0', ''), 1, 6)  AS grid,
--     substring(replaceAll(toString(grid), '\0', ''), 1, 4)  AS grid_4,
--     count()                                         AS spot_count,
--     max(toDate(timestamp))                          AS last_seen
-- FROM wspr.spots_raw
-- WHERE length(replaceAll(toString(grid), '\0', '')) >= 4
--   AND match(replaceAll(toString(grid), '\0', ''), '^[A-R]{2}[0-9]{2}')
-- GROUP BY callsign, grid
-- SETTINGS max_threads = 32, max_memory_usage = 40000000000;

-- ============================================================================
-- Population: RX callsigns (reporter → reporter_grid)
-- ReplacingMergeTree merges with TX rows; most recent last_seen wins.
-- ============================================================================
-- INSERT INTO wspr.callsign_grid
-- SELECT
--     replaceAll(toString(reporter), '\0', '')              AS callsign,
--     substring(replaceAll(toString(reporter_grid), '\0', ''), 1, 6)  AS grid,
--     substring(replaceAll(toString(reporter_grid), '\0', ''), 1, 4)  AS grid_4,
--     count()                                                AS spot_count,
--     max(toDate(timestamp))                                 AS last_seen
-- FROM wspr.spots_raw
-- WHERE length(replaceAll(toString(reporter_grid), '\0', '')) >= 4
--   AND match(replaceAll(toString(reporter_grid), '\0', ''), '^[A-R]{2}[0-9]{2}')
-- GROUP BY reporter, reporter_grid
-- SETTINGS max_threads = 32, max_memory_usage = 40000000000;

-- After both inserts, force merge to deduplicate:
-- OPTIMIZE TABLE wspr.callsign_grid FINAL;
