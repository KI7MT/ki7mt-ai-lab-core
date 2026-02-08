-- 11-contest_schema_v1.sql — Contest QSO schema for parsed Cabrillo logs
--
-- Stores QSOs parsed from CQ WW, ARRL, and other contest Cabrillo logs.
-- Exchange stored as raw strings (format varies by contest).
-- No dedup at ingest — same QSO may appear in both stations' logs.

CREATE DATABASE IF NOT EXISTS contest;

CREATE TABLE IF NOT EXISTS contest.qsos (
    timestamp    DateTime                COMMENT 'QSO timestamp UTC',
    frequency    UInt32                  COMMENT 'Frequency kHz',
    band         Int32                   COMMENT 'ADIF band ID',
    mode         LowCardinality(String)  COMMENT 'CW, PH, RY, DG, FM',
    call_1       String                  COMMENT 'Logging station callsign',
    call_2       String                  COMMENT 'Worked station callsign',
    rst_sent     String                  COMMENT 'RST/signal report sent',
    exch_sent    String                  COMMENT 'Sent exchange (raw, space-joined)',
    rst_rcvd     String                  COMMENT 'RST/signal report received',
    exch_rcvd    String                  COMMENT 'Received exchange (raw, space-joined)',
    contest      LowCardinality(String)  COMMENT 'Contest ID from CONTEST header',
    source       LowCardinality(String)  COMMENT 'Source key (cq-ww/2005cw)'
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, band, call_1, call_2)
SETTINGS index_granularity = 8192;
