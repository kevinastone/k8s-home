package monitoring

import (
	"k8s-home.internal/lib/grafana"
)

// -----------------------------------------------------------------------------
// Shared Threshold Presets
// -----------------------------------------------------------------------------
#GreenRed80Thresholds: [
	{color: "green", value: null},
	{color: "red", value: 80},
]

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
// Panel Templates
// -----------------------------------------------------------------------------
#NutStat: S={
	title:        string | *""
	description?: string
	expr:         string
	legend?:      string
	unit?:        string
	noValue?:     string
	thresholdSteps?: [...]
	colorMode:     string | *"fixed"
	textMode?:     string
	calc:          string | *"lastNotNull"
	fieldsRegex?:  string
	showAllValues: bool | *false
	mappings: [...] | *[]
	transformations: [...] | *[]

	out: grafana.#StatPanel & {
		title:       S.title
		transparent: true
		if S.description != _|_ {
			description: S.description
		}
		fieldConfig: defaults: {
			if S.unit != _|_ {
				unit: S.unit
			}
			if S.noValue != _|_ {
				noValue: S.noValue
			}
			color: mode: S.colorMode
			if len(S.mappings) > 0 {
				mappings: S.mappings
			}
			if S.thresholdSteps != _|_ {
				thresholds: {
					mode:  "absolute"
					steps: S.thresholdSteps
				}
			}
		}
		options: {
			graphMode: "none"
			textMode: [if S.textMode != _|_ {S.textMode}, "value"][0]
			reduceOptions: {
				calcs: [S.calc]
				if S.fieldsRegex != _|_ {
					fields: S.fieldsRegex
				}
				values: S.showAllValues
			}
		}
		if len(S.transformations) > 0 {
			transformations: S.transformations
		}
		targets: [
			grafana.#PromTarget & {
				expr:    S.expr
				instant: true
				if S.legend != _|_ {
					legendFormat: S.legend
				}
			},
		]
	}
}

#NutGauge: G={
	title:       string
	expr:        string
	legend?:     string
	unit?:       string
	min?:        number
	max?:        number
	calc:        string | *"last"
	gradient:    bool | *true
	orientation: "auto" | "horizontal" | *"auto"
	thresholdSteps: [...]
	mappings: [...] | *[]

	out: grafana.#GaugePanel & {
		title:       G.title
		transparent: true
		fieldConfig: defaults: {
			if G.unit != _|_ {
				unit: G.unit
			}
			if G.min != _|_ {
				min: G.min
			}
			if G.max != _|_ {
				max: G.max
			}
			color: mode: "thresholds"
			if len(G.mappings) > 0 {
				mappings: G.mappings
			}
			thresholds: {
				mode:  "absolute"
				steps: G.thresholdSteps
			}
		}
		options: {
			orientation: G.orientation
			if !G.gradient {
				effects: gradient: false
			}
			if G.calc != "last" {
				reduceOptions: calcs: [G.calc]
			}
		}
		targets: [
			grafana.#PromTarget & {
				expr:    G.expr
				instant: true
				if G.legend != _|_ {
					legendFormat: G.legend
				}
			},
		]
	}
}

#NutTimeseries: T={
	title:         string | *""
	expr:          string
	legend:        string
	unit?:         string
	min?:          number
	max?:          number
	softMin?:      number
	softMax?:      number
	thresholdMode: "off" | "area" | *"off"
	thresholdSteps: [...] | *#GreenRed80Thresholds
	colorMode: "palette-classic" | "thresholds" | *"palette-classic"
	seriesBy?: string

	out: grafana.#TimeSeriesPanel & {
		title:       T.title
		transparent: true
		fieldConfig: defaults: {
			if T.unit != _|_ {
				unit: T.unit
			}
			if T.min != _|_ {
				min: T.min
			}
			if T.max != _|_ {
				max: T.max
			}
			if T.seriesBy != _|_ {
				color: {
					mode:     T.colorMode
					seriesBy: T.seriesBy
				}
			}
			if T.seriesBy == _|_ {
				color: mode: T.colorMode
			}
			thresholds: {
				mode:  "absolute"
				steps: T.thresholdSteps
			}
			custom: {
				axisBorderShow:   false
				axisCenteredZero: false
				axisColorMode:    "text"
				axisPlacement:    "auto"
				if T.softMin != _|_ {
					axisSoftMin: T.softMin
				}
				if T.softMax != _|_ {
					axisSoftMax: T.softMax
				}
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
				thresholdsStyle: mode: T.thresholdMode
				hideFrom: {legend: false, tooltip: false, viz: false}
			}
		}
		options: tooltip: mode: "multi"
		targets: [
			grafana.#PromTarget & {
				expr:         T.expr
				legendFormat: T.legend
			},
		]
	}
}

// -----------------------------------------------------------------------------
// 1. Device Info
// -----------------------------------------------------------------------------
let mfrStat = #NutStat & {
	title:          "Manufacturer"
	expr:           #"network_ups_tools_device_info{ups="$ups"}"#
	legend:         "{{mfr}}"
	calc:           "mean"
	textMode:       "name"
	thresholdSteps: #GreenRed80Thresholds
}

let modelStat = #NutStat & {
	title:          "Model"
	expr:           #"network_ups_tools_device_info{ups="$ups"}"#
	legend:         "{{model}}"
	calc:           "mean"
	textMode:       "name"
	thresholdSteps: #GreenRed80Thresholds
}

let deviceInfoSection = {
	title: "Device Info"
	rows: [
		[(mfrStat.out & {gridPos: {h: 3, w: 8}}), (modelStat.out & {gridPos: {h: 3, w: 16}})],
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

let statusStat = #NutStat & {
	description: #NutStatusDescription
	expr:        #"network_ups_tools_ups_status{ups="$ups", flag=~"OB|OL"} == 1"#
	legend:      "{{flag}}"
	fieldsRegex: "/^Metric$/"
	mappings:    statusMappings
	thresholdSteps: [{color: "green", value: null}]
	transformations: statusTransformations
}

let flagsStat = #NutStat & {
	title:         "Flags"
	description:   #NutStatusDescription
	noValue:       "-­"
	expr:          #"network_ups_tools_ups_status{ups="$ups", flag!~"OB|OL"} == 1"#
	legend:        "{{flag}}"
	fieldsRegex:   "/^Metric$/"
	showAllValues: true
	mappings:      statusMappings
	thresholdSteps: [{color: "green", value: null}]
	transformations: statusTransformations
}

let batteryRuntimeStat = #NutStat & {
	title: "Battery Runtime"
	unit:  "s"
	expr:  #"network_ups_tools_battery_runtime{ups="$ups"}"#
	thresholdSteps: [
		{color: "dark-red", value: null},
		{color: "#EAB839", value: 300},
		{color: "dark-green", value: 900},
	]
}

let batteryChargeStat = #NutStat & {
	title: "Battery Charge"
	unit:  "percent"
	calc:  "last"
	expr:  #"network_ups_tools_battery_charge{ups="$ups"}"#
	thresholdSteps: [
		{color: "dark-red", value: null},
		{color: "orange", value: 30},
		{color: "#EAB839", value: 60},
		{color: "dark-green", value: 80},
	]
}

let powerDrawStat = #NutStat & {
	title: "Power Draw"
	unit:  "watt"
	calc:  "last"
	expr:  #"(network_ups_tools_ups_load{ups="$ups"} / 100) * network_ups_tools_ups_realpower_nominal{ups="$ups"}"#
	thresholdSteps: [
		{color: "dark-red", value: null},
	]
}

let statusTimeline = grafana.#StateTimelinePanel & {
	title:       ""
	transparent: true
	gridPos: {h: 3, w: 24}
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

let statusSection = {
	title: "Status"
	rows: [
		[
			(statusStat.out & {gridPos: {h: 3, w: 3}}),
			(flagsStat.out & {gridPos: {h: 3, w: 5}}),
			(batteryRuntimeStat.out & {gridPos: {h: 3, w: 5}}),
			(batteryChargeStat.out & {gridPos: {h: 3, w: 5}}),
			(powerDrawStat.out & {gridPos: {h: 3, w: 6}}),
		],
		[statusTimeline],
	]
}

// -----------------------------------------------------------------------------
// 3. Status Breakdown (Collapsed Row)
// -----------------------------------------------------------------------------
let statusBreakdownTimeline = grafana.#StateTimelinePanel & {
	title: ""
	gridPos: {h: 7, w: 24}
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

let statusBreakdownSection = {
	title:     "Status Breakdown"
	collapsed: true
	rows: [
		[statusBreakdownTimeline],
	]
}

// -----------------------------------------------------------------------------
// 4. Runtime
// -----------------------------------------------------------------------------
let batteryChargeGauge = #NutGauge & {
	title: "Battery Charge"
	unit:  "percent"
	min:   0
	max:   100
	expr:  #"network_ups_tools_battery_charge{ups="$ups"}"#
	thresholdSteps: [
		{color: "dark-red", value: null},
		{color: "dark-orange", value: 30},
		{color: "dark-yellow", value: 60},
		{color: "dark-green", value: 80},
	]
}

let batteryChargeTimeseries = #NutTimeseries & {
	title:         "Battery Charge"
	unit:          "percent"
	min:           0
	softMin:       0
	softMax:       100
	colorMode:     "thresholds"
	thresholdMode: "area"
	expr:          #"network_ups_tools_battery_charge{ups="$ups"}"#
	legend:        "Charge"
	thresholdSteps: [
		{color: "red", value: null},
		{color: "orange", value: 30},
		{color: "yellow", value: 60},
		{color: "green", value: 80},
	]
}

let batteryRuntimeTimeseries = #NutTimeseries & {
	title:         "Battery Run Time Left"
	unit:          "s"
	min:           0
	colorMode:     "thresholds"
	seriesBy:      "last"
	thresholdMode: "area"
	expr:          #"network_ups_tools_battery_runtime{ups="$ups"}"#
	legend:        "Runtime"
	thresholdSteps: [
		{color: "red", value: null},
		{color: "orange", value: 300},
		{color: "green", value: 900},
	]
}

let runtimeSection = {
	title: "Runtime"
	rows: [
		[
			(batteryChargeGauge.out & {gridPos: {h: 6, w: 3}}),
			(batteryChargeTimeseries.out & {gridPos: {h: 6, w: 10}}),
			(batteryRuntimeTimeseries.out & {gridPos: {h: 6, w: 11}}),
		],
	]
}

// -----------------------------------------------------------------------------
// 5. Load
// -----------------------------------------------------------------------------
let loadGauge = #NutGauge & {
	title:          "Load"
	unit:           "percent"
	calc:           "lastNotNull"
	expr:           #"network_ups_tools_ups_load{ups="$ups"}"#
	thresholdSteps: #GreenRed80Thresholds
}

let loadTimeseries = #NutTimeseries & {
	title:          "Load"
	unit:           "percent"
	min:            0
	max:            100
	expr:           #"network_ups_tools_ups_load{ups="$ups"}"#
	legend:         "Load"
	thresholdSteps: #GreenRed80Thresholds
}

let powerUsageTimeseries = #NutTimeseries & {
	title:  "Power Usage"
	unit:   "watt"
	expr:   #"(network_ups_tools_ups_load{ups="$ups"} / 100) * network_ups_tools_ups_realpower_nominal{ups="$ups"}"#
	legend: "Power"
	thresholdSteps: [
		{color: "red", value: null},
	]
}

let loadSection = {
	title: "Load"
	rows: [
		[
			(loadGauge.out & {gridPos: {h: 6, w: 3}}),
			(loadTimeseries.out & {gridPos: {h: 6, w: 10}}),
			(powerUsageTimeseries.out & {gridPos: {h: 6, w: 11}}),
		],
	]
}

// -----------------------------------------------------------------------------
// 6. Power Health
// -----------------------------------------------------------------------------
let lineVoltsGauge = #NutGauge & {
	title:    "Line Volts"
	unit:     "volt"
	min:      90
	max:      140
	gradient: false
	expr:     #"network_ups_tools_input_voltage{ups="$ups"}"#
	thresholdSteps: [
		{color: "dark-red", value: null},
		{color: "dark-green", value: 95},
		{color: "dark-yellow", value: 125},
		{color: "dark-red", value: 135},
	]
}

let lineVoltsTimeseries = #NutTimeseries & {
	unit:           "volt"
	min:            90
	max:            140
	expr:           #"network_ups_tools_input_voltage{ups="$ups"}"#
	legend:         "Input Voltage"
	thresholdSteps: #GreenRed80Thresholds
}

let batteryVoltsGauge = #NutGauge & {
	title:       "Battery Volts"
	unit:        "volt"
	min:         0
	max:         16
	gradient:    false
	orientation: "horizontal"
	expr:        #"network_ups_tools_battery_voltage{ups="$ups"}"#
	mappings: [
		{
			type: "special"
			options: {
				match: "null"
				result: text: "N/A"
			}
		},
	]
	thresholdSteps: [
		{color: "dark-red", value: null},
		{color: "dark-yellow", value: 10},
		{color: "dark-green", value: 12},
		{color: "dark-red", value: 14.4},
	]
}

let batteryVoltsTimeseries = #NutTimeseries & {
	unit:           "volt"
	min:            0
	expr:           #"network_ups_tools_battery_voltage{ups="$ups"}"#
	legend:         "Battery Voltage"
	thresholdSteps: #GreenRed80Thresholds
}

let powerHealthSection = {
	title: "Power Health"
	rows: [
		[
			(lineVoltsGauge.out & {gridPos: {h: 6, w: 3}}),
			(lineVoltsTimeseries.out & {gridPos: {h: 6, w: 9}}),
			(batteryVoltsGauge.out & {gridPos: {h: 6, w: 3}}),
			(batteryVoltsTimeseries.out & {gridPos: {h: 6, w: 9}}),
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
