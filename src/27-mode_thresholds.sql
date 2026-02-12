-- ==============================================================================
-- Name..........: @PROGRAM@ - Mode Decode Thresholds
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: ADIF 3.1.6 mode to minimum decode threshold mapping.
--
--                 Maps each amateur radio mode to its threshold family
--                 (digital, cw, rtty, phone) and the minimum SNR in dB
--                 required for a viable decode.
--
--                 The waterfall:
--                   +5 dB -> SSB yes  RTTY yes  CW yes  FT8 yes
--                   -5 dB -> SSB no   RTTY yes  CW yes  FT8 yes
--                  -10 dB -> SSB no   RTTY no   CW yes  FT8 yes
--                  -20 dB -> SSB no   RTTY no   CW no   FT8 yes
--
--                 Classification logic is in the database, not hardcoded
--                 in scoring scripts. tools/score_model.py reads this table
--                 at startup for mode_hit computation.
--
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS validation;

-- --------------------------------------------------------------------------
-- Mode threshold lookup
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS validation.mode_thresholds (
    mode            String                  COMMENT 'ADIF 3.1.6 mode name (e.g., FT8, CW, SSB)',
    family          LowCardinality(String)  COMMENT 'Threshold family: digital, cw, rtty, phone',
    threshold_db    Float32                 COMMENT 'Minimum SNR for viable decode (dB)',
    description     String                  COMMENT 'Human-readable description'
) ENGINE = MergeTree()
ORDER BY mode
COMMENT '@PROGRAM@ v@VERSION@ ADIF mode to decode threshold mapping — ADIF 3.1.6 standard';

-- --------------------------------------------------------------------------
-- Populate thresholds
-- --------------------------------------------------------------------------
-- Digital modes: -20 dB (WSJT-X / narrow-band digital decode floor)
-- CW:           -10 dB (human / skimmer decode)
-- RTTY:          -5 dB (~300 Hz bandwidth)
-- Phone:         +5 dB (voice, ~2.4 kHz bandwidth)
-- --------------------------------------------------------------------------

INSERT INTO validation.mode_thresholds (mode, family, threshold_db, description) VALUES
    ('FT8',    'digital', -20.0, 'WSJT-X FT8 decode threshold'),
    ('FT4',    'digital', -20.0, 'WSJT-X FT4 decode threshold'),
    ('JS8',    'digital', -20.0, 'JS8Call decode threshold'),
    ('JT65',   'digital', -20.0, 'WSJT legacy JT65'),
    ('JT9',    'digital', -20.0, 'WSJT legacy JT9'),
    ('FST4',   'digital', -20.0, 'WSJT-X slow mode'),
    ('Q65',    'digital', -20.0, 'WSJT-X weak signal / EME'),
    ('PSK31',  'digital', -20.0, 'Narrow-band PSK'),
    ('OLIVIA', 'digital', -20.0, 'MFSK with FEC'),
    ('WSPR',   'digital', -28.0, 'WSPR beacon decode floor'),
    ('CW',     'cw',      -10.0, 'Human / skimmer CW decode'),
    ('RTTY',   'rtty',     -5.0, 'RTTY ~300 Hz bandwidth'),
    ('SSB',    'phone',     5.0, 'Voice SSB ~2.4 kHz bandwidth'),
    ('AM',     'phone',     5.0, 'Voice AM wider bandwidth'),
    ('FM',     'phone',     5.0, 'Voice FM (VHF primarily)');
