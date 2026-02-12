-- ============================================================================
-- ki7mt-ai-lab-core: PSK Reporter Ingest Watermark Table
-- ============================================================================
-- Tracks which JSONL files have been loaded into pskr.bronze by pskr-ingest.
-- Each row represents one gzip JSONL file from the pskr-collector output.
--
-- Design notes:
--   - ReplacingMergeTree(loaded_at) allows re-loads to update rather than
--     duplicate — only the latest row per file_path survives FINAL
--   - ORDER BY (file_path) gives O(1) lookup for "has this been loaded?"
--   - Tiny table: ~24 rows/day (~9K rows/year at hourly rotation)
--   - row_count=0 distinguishes primed entries (bootstrap) from real loads
--   - hostname tracks which host performed the ingest (multi-host safety)
-- ============================================================================

CREATE TABLE IF NOT EXISTS pskr.ingest_log (
    file_path    String                  COMMENT 'Relative path: 2026/02/10/spots-085833.jsonl.gz',
    file_size    UInt64                  COMMENT 'File size in bytes at load time',
    row_count    UInt64                  COMMENT 'Rows loaded (0 for primed entries)',
    loaded_at    DateTime DEFAULT now()  COMMENT 'When loaded (UTC)',
    elapsed_ms   UInt32                  COMMENT 'Processing time ms',
    hostname     LowCardinality(String)  COMMENT 'Host that performed the load'
) ENGINE = ReplacingMergeTree(loaded_at)
ORDER BY (file_path)
SETTINGS index_granularity = 256
COMMENT 'PSKR incremental ingest watermark — tracks loaded JSONL files';
