-- =============================================================================
-- File.........: 25-live_conditions.sql
-- Description..: Live solar conditions table for nowcasting / PSKR validation
-- Engine.......: Memory (volatile - recreate on ClickHouse restart)
-- Population...: solar-live-update.sh (cron, every 15 minutes)
--
-- This table holds the MOST RECENT solar conditions from NOAA SWPC:
--   - SFI (10.7cm flux, published once daily ~20:00 UTC from Penticton)
--   - Kp (planetary K-index, updated every 3 hours)
--   - X-ray flux (GOES satellite, updated every ~5 minutes)
--
-- Unlike solar.bronze (GFZ Potsdam, ~1 day lag), this table is near-real-time.
-- Use this for:
--   - Live PSK Reporter validation (matching spots to current conditions)
--   - Nowcasting predictions
--   - Storm-aware API responses
--
-- Memory engine means this table is LOST on ClickHouse restart.
-- The solar-live-update.sh cron will repopulate within 15 minutes.
-- =============================================================================

CREATE TABLE IF NOT EXISTS wspr.live_conditions
(
    kp_index    Float32,    -- Planetary K-index (0-9, 3-hourly)
    ap_index    Float32,    -- Planetary Ap index (linear equivalent)
    solar_flux  Float32,    -- 10.7cm SFI (sfu, daily from Penticton)
    xray_short  Float64,    -- GOES 0.05-0.4nm X-ray flux (W/m²)
    xray_long   Float64,    -- GOES 0.1-0.8nm X-ray flux (W/m²)
    conditions  String      -- Human-readable: Quiet/Unsettled/Storm/Severe Storm [+ Radio Blackout]
)
ENGINE = Memory;
