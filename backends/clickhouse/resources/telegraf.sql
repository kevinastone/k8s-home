CREATE DATABASE IF NOT EXISTS metrics;

CREATE TABLE IF NOT EXISTS metrics.telegraf
(
    timestamp DateTime64(3, 'UTC'),
    host LowCardinality(String),
    name LowCardinality(String),
    value Float64,
    tags Map(LowCardinality(String), String),
    INDEX idx_tags_keys mapKeys(tags) TYPE bloom_filter(0.01) GRANULARITY 4,
    INDEX idx_tags_vals mapValues(tags) TYPE bloom_filter(0.01) GRANULARITY 4
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (name, host, timestamp)
TTL toDateTime(timestamp) + INTERVAL 3 DAY TO VOLUME 'cold'
SETTINGS storage_policy = 'hot_to_cold';
