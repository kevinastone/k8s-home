package monitoring

import (
	"k8s-home.internal/lib/grafana"
)

// Single, full-page history graph for any sensor or metric
let historyPanel = grafana.#TimeSeriesPanel & {
	title: "${title} History"
	gridPos: {h: 20, w: 24, x: 0, y: 0}
	options: legend: showLegend: true
	fieldConfig: defaults: {
		unit: "${unit}"
		custom: {
			spanNulls:   true
			fillOpacity: 10
		}
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"{entity_id="${entity}",__name__=~".*_value"}"#
			legendFormat: "${title}"
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
		{
			name:    "unit"
			type:    "textbox"
			label:   "Unit"
			default: ""
			current: {
				selected: false
				text:     ""
				value:    ""
			}
			hide: 2
		},
	]
	panels: [historyPanel]
}
