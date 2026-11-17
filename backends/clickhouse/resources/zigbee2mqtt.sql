CREATE DATABASE IF NOT EXISTS metrics;

CREATE TABLE IF NOT EXISTS metrics.zigbee2mqtt
(
    timestamp DateTime64(3, 'UTC'),
    entity_id LowCardinality(String),
    name LowCardinality(String),
    value Float64
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (name, entity_id, timestamp)
TTL toDateTime(timestamp) + INTERVAL 3 DAY TO VOLUME 'cold'
SETTINGS storage_policy = 'hot_to_cold';
