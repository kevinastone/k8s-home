package monitoring

import (
	"k8s-home.internal/lib/grafana"
)

// Single, full-page history graph for any sensor or metric
let historyPanel = grafana.#TimeSeriesPanel & {
	title: "${title} History"
	gridPos: {h: 20, w: 24, x: 0, y: 0}
	options: legend: showLegend: true
	fieldConfig: {
		defaults: {
			custom: {
				spanNulls:   true
				fillOpacity: 10
			}
		}
		overrides: [
			{
				matcher: {id: "byRegexp", options: ".*_°F_.*"}
				properties: [{id: "unit", value: "fahrenheit"}]
			},
			{
				matcher: {id: "byRegexp", options: ".*_%_.*"}
				properties: [{id: "unit", value: "percent"}]
			},
			{
				matcher: {id: "byRegexp", options: ".*_inHg_.*"}
				properties: [{id: "unit", value: "inHg"}]
			},
			{
				matcher: {id: "byRegexp", options: ".*_W_.*"}
				properties: [{id: "unit", value: "watt"}]
			},
			{
				matcher: {id: "byRegexp", options: ".*_kWh_.*"}
				properties: [{id: "unit", value: "kwh"}]
			},
			{
				matcher: {id: "byRegexp", options: ".*_V_.*"}
				properties: [{id: "unit", value: "volt"}]
			},
			{
				matcher: {id: "byRegexp", options: ".*_A_.*"}
				properties: [{id: "unit", value: "amp"}]
			},
		]
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"{entity_id="${entity}",__name__=~".*_value"}"#
			legendFormat: "{{__name__}}"
		},
	]
}

out: grafana.#Dashboard & {
	title: "Sensor History"
	uid:   "home-history"
	tags: ["home", "iot"]
	templating: list: [
		{
			name:    "entity"
			type:    "textbox"
			label:   "Entity"
			default: "bedroom_temperature_temperature"
			current: {
				selected: false
				text:     "bedroom_temperature_temperature"
				value:    "bedroom_temperature_temperature"
			}
			hide: 2
		},
		{
			name:    "title"
			type:    "textbox"
			label:   "Title"
			default: "Sensor"
			current: {
				selected: false
				text:     "Sensor"
				value:    "Sensor"
			}
			hide: 2
		},
	]
	panels: [historyPanel]
}
