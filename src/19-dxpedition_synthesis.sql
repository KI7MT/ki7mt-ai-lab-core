-- ==============================================================================
-- Name..........: @PROGRAM@ - DXpedition Synthesis (RBN Cross-Reference)
-- Version.......: @VERSION@
-- Copyright.....: @COPYRIGHT@
-- Description...: Tables for rare DXCC coverage via RBN × GDXF DXpedition
--                 cross-reference. Provides machine-measured SNR observations
--                 from 152 rare DXCC entities that have zero WSPR presence.
--
--                 Workflow:
--                 1. Fetch GDXF Mega DXpeditions Honor Roll catalog (332 entries)
--                 2. Cross-reference with RBN spots during active operation windows
--                 3. Add skimmer grid from callsign_grid Rosetta Stone
--                 4. Result: 2.52M paths with real SNR, tagged 'rbn-dxpedition-synthesis'
--
--                 These are one-way skimmer observations, NOT confirmed QSOs.
--                 The dx_grid is entity-level approximation, not exact location.
--
--                 V13 used 91K synthesized signatures from this data (50x upsample).
--
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS dxpedition;

-- --------------------------------------------------------------------------
-- GDXF DXpedition Catalog (source metadata)
-- --------------------------------------------------------------------------
-- One-time fetch from gdxf.de Mega DXpeditions Honor Roll.
-- 332 entries with callsign, entity, approximate grid, and operation dates.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dxpedition.catalog (
    callsign   String     COMMENT 'DXpedition callsign from GDXF catalog',
    entity     String     COMMENT 'DXCC entity name',
    grid       String     COMMENT 'Approximate 4-char Maidenhead grid (entity-level, not exact)',
    year       UInt16     COMMENT 'Year of operation',
    qsos       UInt32     COMMENT 'Total QSOs reported by GDXF (catalog metadata only)',
    start_ts   DateTime   COMMENT 'Operation start UTC',
    end_ts     DateTime   COMMENT 'Operation end UTC'
) ENGINE = MergeTree()
ORDER BY (callsign, start_ts)
COMMENT 'GDXF Mega DXpeditions Honor Roll -- catalog metadata for RBN cross-reference. Source: gdxf.de (one-time fetch 2026-02-07)';

-- --------------------------------------------------------------------------
-- RBN × DXpedition Cross-Reference (derived propagation paths)
-- --------------------------------------------------------------------------
-- DERIVED DATA: RBN skimmer spots matched to GDXF DXpedition callsigns
-- during active operation windows. One-way propagation observations with
-- machine-measured SNR. Grid for DX side is entity-level approximation.
-- NOT confirmed QSOs.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rbn.dxpedition_paths (
    timestamp    DateTime                   COMMENT 'RBN spot timestamp UTC',
    dx_call      String                     COMMENT 'DXpedition callsign',
    dx_entity    String                     COMMENT 'DXCC entity name (from GDXF catalog)',
    dx_grid      String                     COMMENT 'Approximate grid (entity-level, NOT exact station location)',
    skimmer_call String                     COMMENT 'RBN skimmer callsign',
    skimmer_grid String                     COMMENT 'Skimmer grid (from callsign_grid Rosetta Stone)',
    band         Int32                      COMMENT 'ADIF band ID',
    frequency    UInt32                     COMMENT 'Frequency in kHz',
    snr          Int16                      COMMENT 'Machine-measured SNR dB',
    tx_mode      LowCardinality(String)     COMMENT 'CW, RTTY, PSK31',
    source_type  LowCardinality(String)
                 DEFAULT 'rbn-dxpedition-synthesis'
                                            COMMENT 'DERIVED DATA -- one-way skimmer observations matched to DXpedition windows, NOT confirmed QSOs'
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, band, dx_call)
COMMENT 'DERIVED DATA: RBN skimmer spots matched to GDXF DXpedition callsigns during active operation windows. One-way propagation observations with machine-measured SNR. Grid for DX side is entity-level approximation. NOT confirmed QSOs.';
