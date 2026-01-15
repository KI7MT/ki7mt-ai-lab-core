-- ==============================================================================
-- Name..........: ki7mt-ai-lab-core - Solar Silver Layer
-- Version.......: 1.0.0
-- Description...: Unified Daily Solar Indices View
-- ==============================================================================

CREATE OR REPLACE VIEW solar.v_daily_indices AS
SELECT
    date,
    MAX(observed_flux) AS sfi,
    MAX(ssn) AS ssn,
    MAX(kp_index) AS kp,
    MAX(ap_index) AS ap,
    ANY(source_file) AS primary_source
FROM solar.indices_raw FINAL
GROUP BY date
ORDER BY date DESC;
