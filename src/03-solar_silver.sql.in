-- ==============================================================================
-- Name..........: @PROGRAM@ - Solar Silver Layer
-- Version.......: @VERSION@
-- Description...: Unified Daily Solar Indices View
-- ==============================================================================

CREATE OR REPLACE VIEW solar.v_daily_indices AS
SELECT
    date,
    MAX(observed_flux) AS sfi,
    MAX(ssn) AS ssn,
    MAX(kp_index) AS kp,
    MAX(ap_index) AS ap,
    any(source_file) AS primary_source
FROM solar.indices_raw FINAL
GROUP BY date
ORDER BY date DESC;
