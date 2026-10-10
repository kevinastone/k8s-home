package vm_monitoring

import (
	"k8s-home.internal/lib/grafana"
)

#HealthTarget: {
	expr: string
	grafana.#PromTarget
	legendFormat: "__auto"
}

// Reusable Host TimeSeries Panel for System Health
#HealthTimeseries: H={
	title: string
	expr:  string
	unit?: string

	out: grafana.#TimeSeriesPanel & {
		title: H.title
		options: {
			legend: {
				calcs: []
				displayMode: "list"
				placement:   "bottom"
				showLegend:  true
			}
			tooltip: {
				hideZeros: false
				mode:      "single"
				sort:      "none"
			}
		}
		fieldConfig: defaults: {
			if H.unit != _|_ {
				unit: H.unit
			}
			color: mode: "palette-classic"
			thresholds: {
				mode: "absolute"
				steps: [
					{color: "green", value: null},
					{color: "red", value: 80},
				]
			}
			custom: {
				drawStyle:         "line"
				lineInterpolation: "linear"
				spanNulls:         3600000
				fillOpacity:       0
				pointSize:         5
				showPoints:        "auto"
				axisPlacement:     "auto"
				axisColorMode:     "text"
				thresholdsStyle: mode: "off"
			}
		}
		targets: [
			#HealthTarget & {expr: H.expr},
		]
	}
}

let cpuTemp = #HealthTimeseries & {
	title: "CPU Temperature"
	expr:  #"avg by(host) (telegraf_temp_temp{host=~"$host"})"#
	unit:  "celsius"
}

let cpuUsage = #HealthTimeseries & {
	title: "CPU Usage"
	expr:  #"avg by(host) (telegraf_cpu_usage_active{host=~"$host"})"#
	unit:  "percent"
}

// Load
let load1 = #HealthTimeseries & {
	title: "Load 1"
	expr:  #"avg by(host) (telegraf_system_load1{host=~"$host"})"#
}

let load5 = #HealthTimeseries & {
	title: "Load 5"
	expr:  #"avg by(host) (telegraf_system_load5{host=~"$host"})"#
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
	options: {
		orientation:          "auto"
		showThresholdLabels:  false
		showThresholdMarkers: true
		sizing:               "auto"
		minVizHeight:         75
		minVizWidth:          75
		reduceOptions: {
			values: true
			calcs: ["last"]
			fields: ""
		}
	}
	targets: [
		#HealthTarget & {
			expr:    #"avg by(host) (telegraf_disk_used_percent{host=~"$host"})"#
			instant: true
		},
	]
}

let cpuSection = grafana.#RowSection & {
	title:         "CPU Usage"
	defaultHeight: 9
	rows: [
		[cpuTemp.out, cpuUsage.out],
		[load1.out, load5.out],
		[diskGauge],
	]
}

out: grafana.#Dashboard & {
	title:   "System Health"
	uid:     "system-health"
	refresh: ""
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
