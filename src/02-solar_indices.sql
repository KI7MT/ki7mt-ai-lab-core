-- ==============================================================================
-- Name..........: @PROGRAM@ - Solar Raw Schema
-- Version.......: @VERSION@
-- Description...: Raw Layer for Solar Indices (SFI, SSN, Kp/Ap)
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS solar;

--
CREATE TABLE IF NOT EXISTS solar.indices_raw (
    date Date32,
    time DateTime,
    observed_flux Float32,
    adjusted_flux Float32,
    ssn Float32,
    kp_index Float32,
    ap_index Float32,
    xray_short Float32 DEFAULT 0 COMMENT 'GOES 0.05-0.4nm X-ray flux (W/m²)',
    xray_long Float32 DEFAULT 0 COMMENT 'GOES 0.1-0.8nm X-ray flux (W/m²)',
    source_file LowCardinality(String),
    updated_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (date, time)
COMMENT '@PROGRAM@ v@VERSION@ Solar Raw Table';