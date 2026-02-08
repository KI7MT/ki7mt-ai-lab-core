-- ============================================================================
-- ki7mt-ai-lab-core: Quality Distribution Materialized View
-- ============================================================================
-- Aggregates silver into hourly quality buckets for monitoring
-- the distribution of propagation scores across bands and time.
--
-- Backed by SummingMergeTree — incremental aggregation as new embeddings
-- are inserted into wspr.silver.
--
-- Dimensions: band, quality_bucket (0.1 resolution), hour
-- Metrics:    count, avg_distance, avg_kp
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS wspr.v_quality_distribution
(
    timestamp       DateTime,
    band            Int32,
    quality_bucket  Float64,
    count           UInt64,
    avg_distance    Float64,
    avg_kp          Float64
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(timestamp)
ORDER BY (band, quality_bucket, timestamp)
SETTINGS index_granularity = 8192
AS SELECT
    toStartOfHour(timestamp) AS timestamp,
    band,
    floor((embedding[4]) * 10) / 10 AS quality_bucket,
    count() AS count,
    avg(distance) AS avg_distance,
    avg(kp_index) AS avg_kp
FROM wspr.silver
GROUP BY
    timestamp,
    band,
    quality_bucket;
