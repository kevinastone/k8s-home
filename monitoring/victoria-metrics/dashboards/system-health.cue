package vm_monitoring

import (
	"time"
	"k8s-home.internal/lib/grafana"
)

// Reusable Host TimeSeries Panel for System Health
#HealthTimeseries: grafana.#TimeSeriesPanel & {
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
		grafana.#PromTarget & {
			expr: #"avg by(host) (telegraf_temp_temp{host=~"$host"})"#
		},
	]
}

let cpuUsage = #HealthTimeseries & {
	title: "CPU Usage"
	fieldConfig: defaults: unit: "percent"
	targets: [
		grafana.#PromTarget & {
			expr: #"avg by(host) (telegraf_cpu_usage_active{host=~"$host"})"#
		},
	]
}

// Load
let load1 = #HealthTimeseries & {
	title: "Load 1"
	targets: [
		grafana.#PromTarget & {
			expr: #"avg by(host) (telegraf_system_load1{host=~"$host"})"#
		},
	]
}

let load5 = #HealthTimeseries & {
	title: "Load 5"
	targets: [
		grafana.#PromTarget & {
			expr: #"avg by(host) (telegraf_system_load5{host=~"$host"})"#
		},
	]
}

// Disk Gauge
let diskGauge = grafana.#GaugePanel & {
	title: "Disk Used"
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
		grafana.#PromTarget & {
			expr: #"avg by(host) (telegraf_disk_used_percent{host=~"$host"})"#
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
		grafana.#QueryVariable & {
			name:  "host"
			label: "Host"
			query: query: #"label_values({__name__=~"telegraf_.*"}, host)"#
			multi:      true
			includeAll: true
		},
	]
	panels: cpuSection.out
}
