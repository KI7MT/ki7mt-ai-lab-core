-- ==============================================================================
-- Name..........: @PROGRAM@ - Geographic Functions
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Maidenhead Grid Square to Lat/Lon UDFs (Placeholder)
-- ==============================================================================
--
-- FUTURE IMPLEMENTATION:
--   This schema will contain User-Defined Functions (UDFs) for converting
--   Maidenhead grid locators to geographic coordinates. These functions
--   enable spatial analysis of WSPR propagation paths.
--
-- PLANNED FUNCTIONS:
--   1. maidenhead_to_lat(grid String) -> Float64
--      - Converts 4/6/8-character grid to latitude (center of grid)
--
--   2. maidenhead_to_lon(grid String) -> Float64
--      - Converts 4/6/8-character grid to longitude (center of grid)
--
--   3. maidenhead_to_point(grid String) -> Tuple(Float64, Float64)
--      - Returns (latitude, longitude) tuple
--
--   4. great_circle_distance(grid1 String, grid2 String) -> UInt32
--      - Calculates distance in km between two grid squares
--
--   5. bearing(grid1 String, grid2 String) -> UInt16
--      - Calculates azimuth from grid1 to grid2 (0-359 degrees)
--
-- GRID PRECISION:
--   - 4-char (e.g., "DM79"): ~460 km x ~920 km resolution
--   - 6-char (e.g., "DM79lv"): ~19 km x ~9 km resolution
--   - 8-char (e.g., "DM79lv38"): ~800m x ~400m resolution
--
-- IMPLEMENTATION NOTES:
--   - ClickHouse supports SQL UDFs via CREATE FUNCTION
--   - For high-performance scenarios, consider dictionary lookups
--   - Grid validation should reject invalid characters/lengths
--
-- ==============================================================================

-- Placeholder: Create geo schema namespace
CREATE DATABASE IF NOT EXISTS geo
COMMENT '@PROGRAM@ v@VERSION@ Geographic Functions (Placeholder)';

-- ==============================================================================
-- MAIDENHEAD VALIDATION VIEW (for testing)
-- ==============================================================================
-- This view validates that a grid locator follows the Maidenhead format
-- Pattern: [A-R][A-R][0-9][0-9] (4-char)
--          [A-R][A-R][0-9][0-9][a-x][a-x] (6-char)
-- ==============================================================================

CREATE OR REPLACE VIEW geo.v_grid_validation_example AS
SELECT
    'DM79lv' AS sample_grid,
    length('DM79lv') AS grid_length,
    match('DM79lv', '^[A-Ra-r]{2}[0-9]{2}([A-Xa-x]{2})?([0-9]{2})?$') AS is_valid_format;

-- ==============================================================================
-- FUTURE: UDF Implementation (requires ClickHouse 23.8+)
-- ==============================================================================
-- Uncomment when ready to implement:
--
-- CREATE FUNCTION IF NOT EXISTS maidenhead_to_lat AS (grid) ->
--     -- Latitude calculation:
--     -- First char (A-R) = 10-degree field (A=0, R=170), subtract 90
--     -- Third char (0-9) = 1-degree square
--     -- Fifth char (a-x) = 2.5-minute subsquare (if present)
--     multiIf(
--         length(grid) >= 4,
--         (toUInt8(upper(substring(grid, 1, 1))) - 65) * 10 +
--         toUInt8(substring(grid, 3, 1)) - 90 +
--         if(length(grid) >= 6,
--            (toUInt8(lower(substring(grid, 5, 1))) - 97) * (2.5/60) + (1.25/60),
--            0.5),
--         NULL
--     );
--
-- CREATE FUNCTION IF NOT EXISTS maidenhead_to_lon AS (grid) ->
--     -- Longitude calculation:
--     -- Second char (A-R) = 20-degree field (A=0, R=340), subtract 180
--     -- Fourth char (0-9) = 2-degree square
--     -- Sixth char (a-x) = 5-minute subsquare (if present)
--     multiIf(
--         length(grid) >= 4,
--         (toUInt8(upper(substring(grid, 2, 1))) - 65) * 20 +
--         toUInt8(substring(grid, 4, 1)) * 2 - 180 +
--         if(length(grid) >= 6,
--            (toUInt8(lower(substring(grid, 6, 1))) - 97) * (5/60) + (2.5/60),
--            1.0),
--         NULL
--     );
-- ==============================================================================
