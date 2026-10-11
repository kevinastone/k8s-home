package monitoring

import (
	"k8s-home.internal/lib/grafana"
)

#NutTarget: {
	expr: string
	grafana.#PromTarget
}

// Common base for all UPS dashboard TimeSeries panels
#NutTimeSeriesPanel: grafana.#TimeSeriesPanel & {
	transparent: true
	fieldConfig: defaults: custom: {
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
		stacking: mode: "none"
		hideFrom: {legend: false, tooltip: false, viz: false}
	}
	options: tooltip: mode: "multi"
}

// -----------------------------------------------------------------------------
// 1. Device Info
// -----------------------------------------------------------------------------
let mfrStat = grafana.#StatPanel & {
	title:       "Manufacturer"
	transparent: true
	gridPos: {h: 3, w: 8}
	fieldConfig: defaults: {
		color: mode: "fixed"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
				{color: "red", value: 80},
			]
		}
	}
	options: {
		graphMode: "none"
		reduceOptions: calcs: ["mean"]
		textMode: "name"
	}
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_device_info{ups="$ups"}"#
			instant:      true
			legendFormat: "{{mfr}}"
		},
	]
}

let modelStat = grafana.#StatPanel & {
	title:       "Model"
	transparent: true
	gridPos: {h: 3, w: 16}
	fieldConfig: defaults: {
		color: mode: "fixed"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
				{color: "red", value: 80},
			]
		}
	}
	options: {
		graphMode: "none"
		reduceOptions: calcs: ["mean"]
		textMode: "name"
	}
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_device_info{ups="$ups"}"#
			instant:      true
			legendFormat: "{{model}}"
		},
	]
}

let deviceInfoSection = {
	title: "Device Info"
	rows: [
		[mfrStat, modelStat],
	]
}

// -----------------------------------------------------------------------------
// 2. Status
// -----------------------------------------------------------------------------
let statusStat = grafana.#StatPanel & {
	title:       ""
	transparent: true
	gridPos: {h: 3, w: 3}
	description: """
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
	fieldConfig: defaults: {
		color: mode: "fixed"
		mappings: [
			{
				type: "value"
				options: {
					OL: {color: "green", index: 0}
					OB: {color: "red", index: 1}
				}
			},
		]
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
			]
		}
	}
	options: {
		graphMode: "none"
		reduceOptions: fields: "/^Metric$/"
		textMode: "value"
	}
	transformations: [
		{id: "seriesToRows", options: {}},
		{
			id: "filterFieldsByName"
			options: include: names: ["Time", "Metric"]
		},
	]
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_ups_status{ups="$ups", flag=~"OB|OL"} == 1"#
			instant:      true
			legendFormat: "{{flag}}"
		},
	]
}

let flagsStat = grafana.#StatPanel & {
	title:       "Flags"
	transparent: true
	gridPos: {h: 3, w: 5}
	description: statusStat.description
	fieldConfig: defaults: {
		color: mode: "fixed"
		noValue: "-­"
		mappings: [
			{
				type: "value"
				options: {
					OL: {color: "green", index: 0}
					OB: {color: "red", index: 1}
				}
			},
		]
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
			]
		}
	}
	options: {
		graphMode: "none"
		reduceOptions: {
			fields: "/^Metric$/"
			values: true
		}
		textMode: "value"
	}
	transformations: [
		{id: "seriesToRows", options: {}},
		{
			id: "filterFieldsByName"
			options: include: names: ["Time", "Metric"]
		},
	]
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_ups_status{ups="$ups", flag!~"OB|OL"} == 1"#
			instant:      true
			legendFormat: "{{flag}}"
		},
	]
}

let batteryRuntimeStat = grafana.#StatPanel & {
	title:       "Battery Runtime"
	transparent: true
	gridPos: {h: 3, w: 5}
	fieldConfig: defaults: {
		unit: "s"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "dark-red", value: null},
				{color: "#EAB839", value: 300},
				{color: "dark-green", value: 900},
			]
		}
	}
	options: {
		graphMode: "none"
		textMode:  "value"
	}
	targets: [
		#NutTarget & {
			expr:    #"network_ups_tools_battery_runtime{ups="$ups"}"#
			instant: true
		},
	]
}

let batteryChargeStat = grafana.#StatPanel & {
	title:       "Battery Charge"
	transparent: true
	gridPos: {h: 3, w: 5}
	fieldConfig: defaults: {
		unit: "percent"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "dark-red", value: null},
				{color: "orange", value: 30},
				{color: "#EAB839", value: 60},
				{color: "dark-green", value: 80},
			]
		}
	}
	options: {
		graphMode: "none"
		reduceOptions: calcs: ["last"]
		textMode: "value"
	}
	targets: [
		#NutTarget & {
			expr:    #"network_ups_tools_battery_charge{ups="$ups"}"#
			instant: true
		},
	]
}

let powerDrawStat = grafana.#StatPanel & {
	title:       "Power Draw"
	transparent: true
	gridPos: {h: 3, w: 6}
	fieldConfig: defaults: {
		unit: "watt"
		color: mode: "fixed"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "dark-red", value: null},
			]
		}
	}
	options: {
		graphMode: "none"
		reduceOptions: calcs: ["last"]
		textMode: "value"
	}
	targets: [
		#NutTarget & {
			expr:    #"(network_ups_tools_ups_load{ups="$ups"} / 100) * network_ups_tools_ups_realpower_nominal{ups="$ups"}"#
			instant: true
		},
	]
}

let statusTimeline = grafana.#StateTimelinePanel & {
	title:       ""
	transparent: true
	gridPos: {h: 3, w: 24}
	fieldConfig: defaults: {
		color: mode: "thresholds"
		displayName: "­"
		mappings: [
			{
				type: "value"
				options: {
					OL: {color: "green", index: 0}
					OB: {color: "red", index: 1}
				}
			},
		]
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
			]
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
	transformations: [
		{id: "seriesToRows", options: {}},
		{
			id: "filterFieldsByName"
			options: include: names: ["Time", "Metric"]
		},
	]
	targets: [
		#NutTarget & {
			expr:         #"max(network_ups_tools_ups_status{ups="$ups", flag=~"OB|OL"} == 1) by (flag)"#
			legendFormat: "__auto"
		},
	]
}

let statusSection = {
	title: "Status"
	rows: [
		[statusStat, flagsStat, batteryRuntimeStat, batteryChargeStat, powerDrawStat],
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
			steps: [
				{color: "green", value: null},
			]
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
		#NutTarget & {
			expr:         #"max(network_ups_tools_ups_status{ups="$ups"} == 1) by (flag)"#
			legendFormat: "__auto"
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
let batteryChargeGauge = grafana.#GaugePanel & {
	title:       "Battery Charge"
	transparent: true
	gridPos: {h: 6, w: 3}
	fieldConfig: defaults: {
		unit: "percent"
		min:  0
		max:  100
		color: mode: "thresholds"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "dark-red", value: null},
				{color: "dark-orange", value: 30},
				{color: "dark-yellow", value: 60},
				{color: "dark-green", value: 80},
			]
		}
	}
	targets: [
		#NutTarget & {
			expr:    #"network_ups_tools_battery_charge{ups="$ups"}"#
			instant: true
		},
	]
}

let batteryChargeTimeseries = #NutTimeSeriesPanel & {
	title: "Battery Charge"
	gridPos: {h: 6, w: 10}
	fieldConfig: defaults: {
		unit: "percent"
		min:  0
		color: mode: "thresholds"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "red", value: null},
				{color: "orange", value: 30},
				{color: "yellow", value: 60},
				{color: "green", value: 80},
			]
		}
		custom: {
			axisSoftMin: 0
			axisSoftMax: 100
			thresholdsStyle: mode: "area"
		}
	}
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_battery_charge{ups="$ups"}"#
			legendFormat: "Charge"
		},
	]
}

let batteryRuntimeTimeseries = #NutTimeSeriesPanel & {
	title: "Battery Run Time Left"
	gridPos: {h: 6, w: 11}
	fieldConfig: defaults: {
		unit: "s"
		min:  0
		color: {
			mode:     "thresholds"
			seriesBy: "last"
		}
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "red", value: null},
				{color: "orange", value: 300},
				{color: "green", value: 900},
			]
		}
		custom: thresholdsStyle: mode: "area"
	}
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_battery_runtime{ups="$ups"}"#
			legendFormat: "Runtime"
		},
	]
}

let runtimeSection = {
	title: "Runtime"
	rows: [
		[batteryChargeGauge, batteryChargeTimeseries, batteryRuntimeTimeseries],
	]
}

// -----------------------------------------------------------------------------
// 5. Load
// -----------------------------------------------------------------------------
let loadGauge = grafana.#GaugePanel & {
	title:       "Load"
	transparent: true
	gridPos: {h: 6, w: 3}
	fieldConfig: defaults: {
		unit: "percent"
		color: mode: "thresholds"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
				{color: "red", value: 80},
			]
		}
	}
	options: reduceOptions: calcs: ["lastNotNull"]
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_ups_load{ups="$ups"}"#
			instant:      true
			legendFormat: "__auto"
		},
	]
}

let loadTimeseries = #NutTimeSeriesPanel & {
	title: "Load"
	gridPos: {h: 6, w: 10}
	fieldConfig: defaults: {
		unit: "percent"
		min:  0
		max:  100
		color: mode: "palette-classic"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
				{color: "red", value: 80},
			]
		}
		custom: thresholdsStyle: mode: "off"
	}
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_ups_load{ups="$ups"}"#
			legendFormat: "Load"
		},
	]
}

let powerUsageTimeseries = #NutTimeSeriesPanel & {
	title: "Power Usage"
	gridPos: {h: 6, w: 11}
	fieldConfig: defaults: {
		unit: "watt"
		color: mode: "palette-classic"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "red", value: null},
			]
		}
		custom: thresholdsStyle: mode: "off"
	}
	targets: [
		#NutTarget & {
			expr:         #"(network_ups_tools_ups_load{ups="$ups"} / 100) * network_ups_tools_ups_realpower_nominal{ups="$ups"}"#
			legendFormat: "Power"
		},
	]
}

let loadSection = {
	title: "Load"
	rows: [
		[loadGauge, loadTimeseries, powerUsageTimeseries],
	]
}

// -----------------------------------------------------------------------------
// 6. Power Health
// -----------------------------------------------------------------------------
let lineVoltsGauge = grafana.#GaugePanel & {
	title:       "Line Volts"
	transparent: true
	gridPos: {h: 6, w: 3}
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
		#NutTarget & {
			expr:    #"network_ups_tools_input_voltage{ups="$ups"}"#
			instant: true
		},
	]
}

let lineVoltsTimeseries = #NutTimeSeriesPanel & {
	title: ""
	gridPos: {h: 6, w: 9}
	fieldConfig: defaults: {
		unit: "volt"
		min:  90
		max:  140
		color: mode: "palette-classic"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
				{color: "red", value: 80},
			]
		}
		custom: thresholdsStyle: mode: "off"
	}
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_input_voltage{ups="$ups"}"#
			legendFormat: "Input Voltage"
		},
	]
}

let batteryVoltsGauge = grafana.#GaugePanel & {
	title:       "Battery Volts"
	transparent: true
	gridPos: {h: 6, w: 3}
	fieldConfig: defaults: {
		unit: "volt"
		min:  0
		max:  16
		mappings: [
			{
				type: "special"
				options: {
					match: "null"
					result: text: "N/A"
				}
			},
		]
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
		#NutTarget & {
			expr:    #"network_ups_tools_battery_voltage{ups="$ups"}"#
			instant: true
		},
	]
}

let batteryVoltsTimeseries = #NutTimeSeriesPanel & {
	title: ""
	gridPos: {h: 6, w: 9}
	fieldConfig: defaults: {
		unit: "volt"
		min:  0
		color: mode: "palette-classic"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
				{color: "red", value: 80},
			]
		}
		custom: thresholdsStyle: mode: "off"
	}
	targets: [
		#NutTarget & {
			expr:         #"network_ups_tools_battery_voltage{ups="$ups"}"#
			legendFormat: "Battery Voltage"
		},
	]
}

let powerHealthSection = {
	title: "Power Health"
	rows: [
		[lineVoltsGauge, lineVoltsTimeseries, batteryVoltsGauge, batteryVoltsTimeseries],
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
