package monitoring

import (
	"k8s-home.internal/lib/grafana"
)

// -----------------------------------------------------------------------------
// Shared Threshold Presets & Docs
// -----------------------------------------------------------------------------
#GreenRed80Thresholds: {
	mode: "absolute"
	steps: [
		{color: "green", value: null},
		{color: "red", value: 80},
	]
}

#BatteryChargeThresholds: {
	mode: "absolute"
	steps: [
		{color: "dark-red", value: null},
		{color: "dark-orange", value: 30},
		{color: "dark-yellow", value: 60},
		{color: "dark-green", value: 80},
	]
}

#BatteryRuntimeThresholds: {
	mode: "absolute"
	steps: [
		{color: "dark-red", value: null},
		{color: "dark-orange", value: 300},
		{color: "dark-green", value: 900},
	]
}

#NutStatusDescription: """
	 * OL - On line (mains is present)
	 * OB - On battery (mains is not present)
	 * LB - Low battery
	 * HB - High battery
	 * RB - The battery needs to be replaced
	 * CHRG - The battery is charging
	 * DISCHRG - The battery is discharging (inverter is providing load power)
	 * BYPASS - UPS bypass circuit is active -- no battery protection is available
	 * CAL - UPS is currently performing runtime calibration (on battery)
	 * OFF - UPS is offline and is not supplying power to the load
	 * OVER - UPS is overloaded
	 * TRIM - UPS is trimming incoming voltage (called \"buck\" in some hardware)
	 * BOOST - UPS is boosting incoming voltage
	 * FSD and SD - Forced Shutdown
	"""

// -----------------------------------------------------------------------------
// Panel Templates (direct panel schemas)
// -----------------------------------------------------------------------------
#NutStatPanel: grafana.#StatPanel & {
	transparent: true
	options: graphMode: "none"
	fieldConfig: defaults: color: mode: *"fixed" | _
}

#NutGaugePanel: grafana.#GaugePanel & {
	transparent: true
	fieldConfig: defaults: color: mode: "thresholds"
}

#NutTimeSeriesPanel: grafana.#TimeSeriesPanel & {
	transparent: true
	fieldConfig: defaults: {
		color: mode: *"palette-classic" | _
		thresholds: *#GreenRed80Thresholds | _
		custom: {
			axisBorderShow:    false
			axisCenteredZero:  false
			axisColorMode:     "text"
			axisPlacement:     "auto"
			drawStyle:         "line"
			fillOpacity:       50
			gradientMode:      "opacity"
			lineInterpolation: "linear"
			lineWidth:         1
			pointSize:         5
			scaleDistribution: type: "linear"
			showPoints: "never"
			spanNulls:  false
			stacking: mode:        "none"
			thresholdsStyle: mode: *"off" | _
			hideFrom: {legend: false, tooltip: false, viz: false}
		}
	}
	options: tooltip: mode: "multi"
}

// -----------------------------------------------------------------------------
// 1. Device Info
// -----------------------------------------------------------------------------
let mfrStat = #NutStatPanel & {
	title: "Manufacturer"
	gridPos: w: 8
	fieldConfig: defaults: thresholds: #GreenRed80Thresholds
	options: textMode: "name"
	targets: [
		grafana.#PromTarget & {
			expr:         #"network_ups_tools_device_info{ups="$ups"}"#
			instant:      true
			legendFormat: "{{mfr}}"
		},
	]
}

let modelStat = #NutStatPanel & {
	title: "Model"
	gridPos: w: 16
	fieldConfig: defaults: thresholds: #GreenRed80Thresholds
	options: textMode: "name"
	targets: [
		grafana.#PromTarget & {
			expr:         #"network_ups_tools_device_info{ups="$ups"}"#
			instant:      true
			legendFormat: "{{model}}"
		},
	]
}

let deviceInfoSection = grafana.#RowSection & {
	title:         "Device Info"
	defaultHeight: 3
	rows: [
		[mfrStat, modelStat],
	]
}

// -----------------------------------------------------------------------------
// 2. Status
// -----------------------------------------------------------------------------
let statusTransformations = [
	{id: "seriesToRows", options: {}},
	{
		id: "filterFieldsByName"
		options: include: names: ["Time", "Metric"]
	},
]

let statusMappings = [
	{
		type: "value"
		options: {
			OL: {color: "green", index: 0}
			OB: {color: "red", index: 1}
		}
	},
]

let statusStat = #NutStatPanel & {
	description: #NutStatusDescription
	gridPos: w: 3
	fieldConfig: defaults: {
		mappings: statusMappings
		thresholds: {
			mode: "absolute"
			steps: [{color: "green", value: null}]
		}
	}
	options: reduceOptions: fields: "/^Metric$/"
	transformations: statusTransformations
	targets: [
		grafana.#PromTarget & {
			expr:         #"network_ups_tools_ups_status{ups="$ups", flag=~"OB|OL"} == 1"#
			instant:      true
			legendFormat: "{{flag}}"
		},
	]
}

let flagsStat = #NutStatPanel & {
	title:       "Flags"
	description: #NutStatusDescription
	gridPos: w: 5
	fieldConfig: defaults: {
		noValue:  "-­"
		mappings: statusMappings
		thresholds: {
			mode: "absolute"
			steps: [{color: "green", value: null}]
		}
	}
	options: reduceOptions: {
		fields: "/^Metric$/"
		values: true
	}
	transformations: statusTransformations
	targets: [
		grafana.#PromTarget & {
			expr:         #"network_ups_tools_ups_status{ups="$ups", flag!~"OB|OL"} == 1"#
			instant:      true
			legendFormat: "{{flag}}"
		},
	]
}

let batteryRuntimeStat = #NutStatPanel & {
	title: "Battery Runtime"
	gridPos: w: 5
	fieldConfig: defaults: {
		unit:       "s"
		thresholds: #BatteryRuntimeThresholds
	}
	targets: [
		grafana.#PromTarget & {
			expr:    #"network_ups_tools_battery_runtime{ups="$ups"}"#
			instant: true
		},
	]
}

let batteryChargeStat = #NutStatPanel & {
	title: "Battery Charge"
	gridPos: w: 5
	fieldConfig: defaults: {
		unit:       "percent"
		thresholds: #BatteryChargeThresholds
	}
	options: reduceOptions: calcs: ["last"]
	targets: [
		grafana.#PromTarget & {
			expr:    #"network_ups_tools_battery_charge{ups="$ups"}"#
			instant: true
		},
	]
}

let powerDrawStat = #NutStatPanel & {
	title: "Power Draw"
	gridPos: w: 6
	fieldConfig: defaults: unit: "watt"
	options: reduceOptions: calcs: ["last"]
	targets: [
		grafana.#PromTarget & {
			expr:    #"(network_ups_tools_ups_load{ups="$ups"} / 100) * network_ups_tools_ups_realpower_nominal{ups="$ups"}"#
			instant: true
		},
	]
}

let statusTimeline = grafana.#StateTimelinePanel & {
	title:       ""
	transparent: true
	fieldConfig: defaults: {
		color: mode: "thresholds"
		displayName: "­"
		mappings:    statusMappings
		thresholds: {
			mode: "absolute"
			steps: [{color: "green", value: null}]
		}
		custom: {
			fillOpacity: 70
			lineWidth:   0
			spanNulls:   false
			insertNulls: false
			hideFrom: {legend: false, tooltip: false, viz: false}
		}
	}
	options: {
		alignValue:  "center"
		rowHeight:   0.9
		showValue:   "auto"
		mergeValues: true
		legend: showLegend: false
	}
	transformations: statusTransformations
	targets: [
		grafana.#PromTarget & {
			expr: #"max(network_ups_tools_ups_status{ups="$ups", flag=~"OB|OL"} == 1) by (flag)"#
		},
	]
}

let statusSection = grafana.#RowSection & {
	title:         "Status"
	defaultHeight: 3
	rows: [
		[
			statusStat,
			flagsStat,
			batteryRuntimeStat,
			batteryChargeStat,
			powerDrawStat,
		],
		[statusTimeline],
	]
}

// -----------------------------------------------------------------------------
// 3. Status Breakdown (Collapsed Row)
// -----------------------------------------------------------------------------
let statusBreakdownTimeline = grafana.#StateTimelinePanel & {
	title: ""
	fieldConfig: defaults: {
		color: mode: "palette-classic"
		thresholds: {
			mode: "absolute"
			steps: [{color: "green", value: null}]
		}
		custom: {
			fillOpacity: 70
			lineWidth:   0
			spanNulls:   false
			insertNulls: false
			hideFrom: {legend: false, tooltip: false, viz: false}
		}
	}
	options: {
		alignValue:  "left"
		rowHeight:   0.9
		showValue:   "never"
		mergeValues: true
		legend: showLegend: false
	}
	targets: [
		grafana.#PromTarget & {
			expr: #"max(network_ups_tools_ups_status{ups="$ups"} == 1) by (flag)"#
		},
	]
}

let statusBreakdownSection = grafana.#RowSection & {
	title:         "Status Breakdown"
	defaultHeight: 7
	collapsed:     true
	rows: [
		[statusBreakdownTimeline],
	]
}

// -----------------------------------------------------------------------------
// 4. Runtime
// -----------------------------------------------------------------------------
let batteryChargeGauge = #NutGaugePanel & {
	title: "Battery Charge"
	gridPos: w: 3
	fieldConfig: defaults: {
		unit:       "percent"
		min:        0
		max:        100
		thresholds: #BatteryChargeThresholds
	}
	targets: [
		grafana.#PromTarget & {
			expr:    #"network_ups_tools_battery_charge{ups="$ups"}"#
			instant: true
		},
	]
}

let batteryChargeTimeseries = #NutTimeSeriesPanel & {
	title: "Battery Charge"
	gridPos: w: 10
	fieldConfig: defaults: {
		unit: "percent"
		min:  0
		color: mode: "thresholds"
		thresholds: #BatteryChargeThresholds
		custom: {
			axisSoftMin: 0
			axisSoftMax: 100
			thresholdsStyle: mode: "area"
		}
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"network_ups_tools_battery_charge{ups="$ups"}"#
			legendFormat: "Charge"
		},
	]
}

let batteryRuntimeTimeseries = #NutTimeSeriesPanel & {
	title: "Battery Run Time Left"
	gridPos: w: 11
	fieldConfig: defaults: {
		unit: "s"
		min:  0
		color: {
			mode:     "thresholds"
			seriesBy: "last"
		}
		thresholds: #BatteryRuntimeThresholds
		custom: thresholdsStyle: mode: "area"
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"network_ups_tools_battery_runtime{ups="$ups"}"#
			legendFormat: "Runtime"
		},
	]
}

let runtimeSection = grafana.#RowSection & {
	title:         "Runtime"
	defaultHeight: 6
	rows: [
		[
			batteryChargeGauge,
			batteryChargeTimeseries,
			batteryRuntimeTimeseries,
		],
	]
}

// -----------------------------------------------------------------------------
// 5. Load
// -----------------------------------------------------------------------------
let loadGauge = #NutGaugePanel & {
	title: "Load"
	gridPos: w: 3
	fieldConfig: defaults: {
		unit:       "percent"
		thresholds: #GreenRed80Thresholds
	}
	options: reduceOptions: calcs: ["lastNotNull"]
	targets: [
		grafana.#PromTarget & {
			expr:    #"network_ups_tools_ups_load{ups="$ups"}"#
			instant: true
		},
	]
}

let loadTimeseries = #NutTimeSeriesPanel & {
	title: "Load"
	gridPos: w: 10
	fieldConfig: defaults: {
		unit: "percent"
		min:  0
		max:  100
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"network_ups_tools_ups_load{ups="$ups"}"#
			legendFormat: "Load"
		},
	]
}

let powerUsageTimeseries = #NutTimeSeriesPanel & {
	title: "Power Usage"
	gridPos: w: 11
	fieldConfig: defaults: unit: "watt"
	targets: [
		grafana.#PromTarget & {
			expr:         #"(network_ups_tools_ups_load{ups="$ups"} / 100) * network_ups_tools_ups_realpower_nominal{ups="$ups"}"#
			legendFormat: "Power"
		},
	]
}

let loadSection = grafana.#RowSection & {
	title:         "Load"
	defaultHeight: 6
	rows: [
		[
			loadGauge,
			loadTimeseries,
			powerUsageTimeseries,
		],
	]
}

// -----------------------------------------------------------------------------
// 6. Power Health
// -----------------------------------------------------------------------------
let lineVoltsGauge = #NutGaugePanel & {
	title: "Line Volts"
	gridPos: w: 3
	fieldConfig: defaults: {
		unit: "volt"
		min:  90
		max:  140
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "dark-red", value: null},
				{color: "dark-green", value: 95},
				{color: "dark-yellow", value: 125},
				{color: "dark-red", value: 135},
			]
		}
	}
	options: effects: gradient: false
	targets: [
		grafana.#PromTarget & {
			expr:    #"network_ups_tools_input_voltage{ups="$ups"}"#
			instant: true
		},
	]
}

let lineVoltsTimeseries = #NutTimeSeriesPanel & {
	gridPos: w: 9
	fieldConfig: defaults: {
		unit: "volt"
		min:  90
		max:  140
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"network_ups_tools_input_voltage{ups="$ups"}"#
			legendFormat: "Input Voltage"
		},
	]
}

let batteryVoltsGauge = #NutGaugePanel & {
	title: "Battery Volts"
	gridPos: w: 3
	fieldConfig: defaults: {
		unit:    "volt"
		min:     0
		max:     16
		noValue: "N/A"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "dark-red", value: null},
				{color: "dark-yellow", value: 10},
				{color: "dark-green", value: 12},
				{color: "dark-red", value: 14.4},
			]
		}
	}
	options: {
		orientation: "horizontal"
		effects: gradient: false
	}
	targets: [
		grafana.#PromTarget & {
			expr:    #"network_ups_tools_battery_voltage{ups="$ups"}"#
			instant: true
		},
	]
}

let batteryVoltsTimeseries = #NutTimeSeriesPanel & {
	gridPos: w: 9
	fieldConfig: defaults: {
		unit: "volt"
		min:  0
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"network_ups_tools_battery_voltage{ups="$ups"}"#
			legendFormat: "Battery Voltage"
		},
	]
}

let powerHealthSection = grafana.#RowSection & {
	title:         "Power Health"
	defaultHeight: 6
	rows: [
		[
			lineVoltsGauge,
			lineVoltsTimeseries,
			batteryVoltsGauge,
			batteryVoltsTimeseries,
		],
	]
}

let layout = grafana.#LayoutSections & {
	sections: [
		deviceInfoSection,
		statusSection,
		statusBreakdownSection,
		runtimeSection,
		loadSection,
		powerHealthSection,
	]
}

// -----------------------------------------------------------------------------
// Dashboard Output
// -----------------------------------------------------------------------------
out: grafana.#Dashboard & {
	title:   "UPS Monitoring"
	uid:     "network-ups-tools"
	refresh: "5s"
	time: (grafana.#Last & {in: "30m"}).out
	templating: list: [
		grafana.#QueryVariable & {
			name:  "ups"
			label: "UPS"
			query: query: "label_values(network_ups_tools_device_info, ups)"
		},
	]
	panels: layout.out
}
