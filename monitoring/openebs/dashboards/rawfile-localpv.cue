package openebs

import (
	"k8s-home.internal/lib/grafana"
)

#PoolThresholds: {
	mode: "absolute"
	steps: [
		{color: "green", value: null},
		{color: "yellow", value: 70},
		{color: "red", value: 85},
	]
}

#BlueThresholds: {
	mode: "absolute"
	steps: [
		{color: "blue", value: null},
	]
}

#GreenThresholds: {
	mode: "absolute"
	steps: [
		{color: "green", value: null},
	]
}

#PurpleThresholds: {
	mode: "absolute"
	steps: [
		{color: "purple", value: null},
	]
}

#OrangeThresholds: {
	mode: "absolute"
	steps: [
		{color: "orange", value: null},
	]
}

// -----------------------------------------------------------------------------
// Stat Panels
// -----------------------------------------------------------------------------
let totalPoolCapacity = grafana.#StatPanel & {
	title: "Total Pool Capacity"
	fieldConfig: defaults: {
		unit:       "bytes"
		thresholds: #BlueThresholds
	}
	targets: [
		grafana.#PromTarget & {
			expr: #"sum(rawfile_pool_capacity_bytes{node=~"$node"})"#
		},
	]
}

let poolRemainingCapacity = grafana.#StatPanel & {
	title: "Pool Free Space"
	fieldConfig: defaults: {
		unit:       "bytes"
		thresholds: #GreenThresholds
	}
	targets: [
		grafana.#PromTarget & {
			expr: #"sum(rawfile_pool_remaining_capacity_bytes{node=~"$node"})"#
		},
	]
}

let logicalAllocated = grafana.#StatPanel & {
	title: "Logical Allocated"
	fieldConfig: defaults: {
		unit:       "bytes"
		thresholds: #PurpleThresholds
	}
	targets: [
		grafana.#PromTarget & {
			expr: #"sum(rawfile_pool_volumes_logical_bytes{node=~"$node"})"#
		},
	]
}

let physicalConsumed = grafana.#StatPanel & {
	title: "Physical Used (Host Disk)"
	fieldConfig: defaults: {
		unit:       "bytes"
		thresholds: #OrangeThresholds
	}
	targets: [
		grafana.#PromTarget & {
			expr: #"sum(rawfile_pool_volumes_physical_bytes{node=~"$node"})"#
		},
	]
}

// -----------------------------------------------------------------------------
// Gauges
// -----------------------------------------------------------------------------
let poolUsageGauge = grafana.#GaugePanel & {
	title: "Pool Space Used %"
	fieldConfig: defaults: {
		unit:       "percent"
		min:        0
		max:        100
		thresholds: #PoolThresholds
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"(1 - (rawfile_pool_remaining_capacity_bytes{node=~"$node"} / rawfile_pool_capacity_bytes{node=~"$node"})) * 100"#
			legendFormat: "{{node}} - {{pool}}"
		},
	]
}

let thinRatioGauge = grafana.#GaugePanel & {
	title: "Physical vs Logical Used %"
	fieldConfig: defaults: {
		unit: "percent"
		min:  0
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
				{color: "yellow", value: 80},
				{color: "red", value: 100},
			]
		}
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"(rawfile_pool_volumes_physical_bytes{node=~"$node"} / rawfile_pool_volumes_logical_bytes{node=~"$node"}) * 100"#
			legendFormat: "{{node}} - {{pool}}"
		},
	]
}

let volumeCountStat = grafana.#StatPanel & {
	title: "Total Volumes"
	fieldConfig: defaults: {
		unit:       "none"
		thresholds: #GreenThresholds
	}
	targets: [
		grafana.#PromTarget & {
			expr: #"sum(rawfile_pool_volume_count{node=~"$node"})"#
		},
	]
}

// -----------------------------------------------------------------------------
// TimeSeries Panels
// -----------------------------------------------------------------------------
let poolTrendTimeseries = grafana.#TimeSeriesPanel & {
	title: "Storage Pool Trends"
	options: legend: showLegend: true
	fieldConfig: defaults: unit: "bytes"
	targets: [
		grafana.#PromTarget & {
			expr:         #"rawfile_pool_capacity_bytes{node=~"$node"}"#
			legendFormat: "Capacity ({{node}} - {{pool}})"
		},
		grafana.#PromTarget & {
			expr:         #"rawfile_pool_volumes_logical_bytes{node=~"$node"}"#
			legendFormat: "Logical Allocated ({{node}} - {{pool}})"
		},
		grafana.#PromTarget & {
			expr:         #"rawfile_pool_volumes_physical_bytes{node=~"$node"}"#
			legendFormat: "Physical Consumed ({{node}} - {{pool}})"
		},
	]
}

let volumePhysicalTimeseries = grafana.#TimeSeriesPanel & {
	title: "Physical Host Space Used per Volume"
	options: legend: showLegend: true
	fieldConfig: defaults: unit: "bytes"
	targets: [
		grafana.#PromTarget & {
			expr:         #"rawfile_volume_physical_bytes{node=~"$node"}"#
			legendFormat: "{{volume}}"
		},
	]
}

let volumeUtilizationTimeseries = grafana.#TimeSeriesPanel & {
	title: "Volume Filesystem Used %"
	options: legend: showLegend: true
	fieldConfig: defaults: {
		unit:       "percent"
		min:        0
		max:        100
		thresholds: #PoolThresholds
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"(rawfile_volume_used_bytes{node=~"$node"} / rawfile_volume_total_bytes{node=~"$node"}) * 100"#
			legendFormat: "{{volume}}"
		},
	]
}

// -----------------------------------------------------------------------------
// Sections
// -----------------------------------------------------------------------------
let overviewSection = grafana.#RowSection & {
	title:         "Overview"
	defaultHeight: 4
	rows: [
		[totalPoolCapacity, poolRemainingCapacity, logicalAllocated, physicalConsumed],
	]
}

let poolStatusSection = grafana.#RowSection & {
	title:         "Pool Utilization"
	defaultHeight: 7
	rows: [
		[poolUsageGauge, thinRatioGauge, volumeCountStat],
		[poolTrendTimeseries],
	]
}

let volumeSection = grafana.#RowSection & {
	title:         "Volumes"
	defaultHeight: 8
	rows: [
		[volumePhysicalTimeseries, volumeUtilizationTimeseries],
	]
}

let layout = grafana.#LayoutSections & {
	sections: [
		overviewSection,
		poolStatusSection,
		volumeSection,
	]
}

// -----------------------------------------------------------------------------
// Dashboard Output
// -----------------------------------------------------------------------------
out: grafana.#Dashboard & {
	title:   "OpenEBS Rawfile LocalPV"
	uid:     "openebs-rawfile"
	refresh: "30s"
	time: (grafana.#Last & {in: "6h"}).out
	templating: list: [
		grafana.#QueryVariable & {
			name:  "node"
			label: "Node"
			query: query: "label_values(rawfile_pool_capacity_bytes, node)"
			multi:      true
			includeAll: true
		},
	]
	panels: layout.out
}
