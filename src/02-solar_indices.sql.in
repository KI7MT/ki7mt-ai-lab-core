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
    source_file LowCardinality(String),
    updated_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (date, time)
COMMENT '@PROGRAM@ v@VERSION@ Solar Raw Table';