package telegraf

import (
	"time"
	"k8s-home.internal/cue/grafana"
)

let _clickhouseDS = {type: "grafana-clickhouse-datasource", uid: "clickhouse"}

// Reusable Host TimeSeries Panel for System Health
#HealthTimeseries: grafana.#TimeSeriesPanel & {
	datasource: _clickhouseDS
	options: legend: showLegend: true
	fieldConfig: defaults: custom: {
		spanNulls:   div(time.ParseDuration("1h"), time.Millisecond)
		fillOpacity: 0
	}
}

let cpuTemp = #HealthTimeseries & {
	title: "CPU Temperature"
	fieldConfig: defaults: unit: "celsius"
	targets: [
		grafana.#ClickHouseTarget & {
			rawSql: """
				SELECT
				  toStartOfInterval(timestamp, INTERVAL $__interval_s SECOND) AS time,
				  host,
				  avg(value) AS value
				FROM metrics.telegraf
				WHERE $__timeFilter(timestamp)
				  AND name = 'host.temperature_celsius'
				  AND host IN ($host)
				GROUP BY time, host
				ORDER BY time
				"""
		},
	]
}

let cpuUsage = #HealthTimeseries & {
	title: "CPU Usage"
	fieldConfig: defaults: unit: "percent"
	targets: [
		grafana.#ClickHouseTarget & {
			rawSql: """
				SELECT
				  time,
				  host,
				  100 * sumIf(rate, mode NOT IN ('idle', 'iowait')) / nullIf(sum(rate), 0) AS value
				FROM (
				  SELECT
				    toStartOfInterval(timestamp, INTERVAL $__interval_s SECOND) AS time,
				    host,
				    tags['mode'] AS mode,
				    nonNegativeDerivative(value, timestamp) OVER (
				      PARTITION BY host, tags['cpu'], tags['mode']
				      ORDER BY timestamp
				    ) AS rate
				  FROM metrics.telegraf
				  WHERE $__timeFilter(timestamp)
				    AND name = 'host.cpu_seconds_total'
				    AND host IN ($host)
				)
				GROUP BY time, host
				ORDER BY time
				"""
		},
	]
}

// Load
let load1 = #HealthTimeseries & {
	title: "Load 1"
	targets: [
		grafana.#ClickHouseTarget & {
			rawSql: """
				SELECT
				  toStartOfInterval(timestamp, INTERVAL $__interval_s SECOND) AS time,
				  host,
				  avg(value) AS value
				FROM metrics.telegraf
				WHERE $__timeFilter(timestamp)
				  AND name = 'host.load1'
				  AND host IN ($host)
				GROUP BY time, host
				ORDER BY time
				"""
		},
	]
}

let load5 = #HealthTimeseries & {
	title: "Load 5"
	targets: [
		grafana.#ClickHouseTarget & {
			rawSql: """
				SELECT
				  toStartOfInterval(timestamp, INTERVAL $__interval_s SECOND) AS time,
				  host,
				  avg(value) AS value
				FROM metrics.telegraf
				WHERE $__timeFilter(timestamp)
				  AND name = 'host.load5'
				  AND host IN ($host)
				GROUP BY time, host
				ORDER BY time
				"""
		},
	]
}

// Disk Gauge
let diskGauge = grafana.#GaugePanel & {
	title:      "Disk Used"
	datasource: _clickhouseDS
	gridPos: h: 7
	fieldConfig: defaults: {
		unit: "percent"
		min:  0
		max:  100
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
				{color: "red", value: 80},
			]
		}
	}
	targets: [
		grafana.#ClickHouseTarget & {
			rawSql: """
				SELECT
				  toStartOfInterval(timestamp, INTERVAL $__interval_s SECOND) AS time,
				  host,
				  100 * avg(value) AS value
				FROM metrics.telegraf
				WHERE $__timeFilter(timestamp)
				  AND name = 'host.filesystem_used_ratio'
				  AND host IN ($host)
				GROUP BY time, host
				ORDER BY time
				"""
		},
	]
}

let cpuSection = grafana.#RowSection & {
	title:         "CPU Usage"
	defaultHeight: 9
	rows: [
		[cpuTemp, cpuUsage],
		[load1, load5],
		[diskGauge],
	]
}

out: grafana.#Dashboard & {
	title: "System Health"
	uid:   "system-health"
	time: (grafana.#Last & {in: "6h"}).out
	templating: list: [
		grafana.#ClickHouseQueryVariable & {
			name:       "host"
			label:      "Host"
			query:      "SELECT DISTINCT host FROM metrics.telegraf WHERE $__timeFilter(timestamp) AND host != '' ORDER BY host"
			multi:      true
			includeAll: true
		},
	]
	panels: cpuSection.out
}
