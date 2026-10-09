package monitoring

import (
	"list"
	"k8s-home.internal/lib/grafana"
)

// Reusable Room Card: Stat panel with sparklines + temperature trend graph
#RoomPanels: {
	room:   string
	prefix: string
	x:      int
	y:      int

	let _room = room
	let _prefix = prefix
	let _x = x
	let _y = y

	let _tempExpr = #"{entity_id="\#(_prefix)_temperature",__name__=~".*_value"}"#
	let _humidityExpr = #"{entity_id="\#(_prefix)_humidity",__name__=~".*_value"}"#
	let _pressureExpr = #"{entity_id="\#(_prefix)_pressure",__name__=~".*_value"}"#

	// 1. Environment Stats Panel (Temp, Humidity, Pressure)
	statPanel: grafana.#StatPanel & {
		title: "\(_room)"
		gridPos: {h: 5, w: 6, x: _x, y: _y}
		options: {
			orientation: "horizontal"
			textMode:    "value_and_name"
			graphMode:   "area"
		}
		fieldConfig: {
			defaults: {
				thresholds: {
					mode: "absolute"
					steps: [
						{color: "blue", value: null},
						{color: "green", value: 68},
						{color: "red", value: 80},
					]
				}
			}
			overrides: [
				{
					matcher: {id: "byName", options: "Temperature"}
					properties: [{id: "unit", value: "fahrenheit"}]
				},
				{
					matcher: {id: "byName", options: "Humidity"}
					properties: [{id: "unit", value: "percent"}]
				},
				{
					matcher: {id: "byName", options: "Pressure"}
					properties: [{id: "unit", value: "inHg"}]
				},
			]
		}
		targets: [
			grafana.#PromTarget & {
				expr:         _tempExpr
				legendFormat: "Temperature"
			},
			grafana.#PromTarget & {
				expr:         _humidityExpr
				legendFormat: "Humidity"
			},
			grafana.#PromTarget & {
				expr:         _pressureExpr
				legendFormat: "Pressure"
			},
		]
	}

	// 2. Temperature History Graph (matching Lovelace card footer)
	graphPanel: grafana.#TimeSeriesPanel & {
		title: "\(_room) Temperature History"
		gridPos: {h: 4, w: 6, x: _x, y: _y + 5}
		fieldConfig: defaults: {
			unit: "fahrenheit"
			custom: {
				spanNulls:   true
				fillOpacity: 10
			}
		}
		targets: [
			grafana.#PromTarget & {
				expr:         _tempExpr
				legendFormat: "\(_room)"
			},
		]
	}

	out: [statPanel, graphPanel]
}

// Reusable Power Device: Stat panel on top, dedicated trend graph directly below
#PowerTile: {
	name:      string
	entity_id: string
	x:         int | *18
	y:         int

	let _name = name
	let _entity_id = entity_id
	let _x = x
	let _y = y
	let _powerExpr = #"{entity_id="\#(_entity_id)",__name__=~".*_value"}"#

	// 1. Current Power Stat Panel (clean number, no background overlap)
	stat: grafana.#StatPanel & {
		title: _name
		gridPos: {h: 2, w: 6, x: _x, y: _y}
		options: graphMode: "none"
		fieldConfig: defaults: {
			unit: "watt"
			thresholds: {
				mode: "absolute"
				steps: [
					{color: "green", value: null},
					{color: "orange", value: 150},
					{color: "red", value: 300},
				]
			}
		}
		targets: [
			grafana.#PromTarget & {
				expr:         _powerExpr
				legendFormat: _name
			},
		]
	}

	// 2. Trend Graph directly below the stat value (interactive tooltip, connected line)
	graph: grafana.#TimeSeriesPanel & {
		title: "\(_name) Trend"
		gridPos: {h: 2, w: 6, x: _x, y: _y + 2}
		options: legend: showLegend: false
		fieldConfig: defaults: {
			unit: "watt"
			custom: {
				drawStyle:   "line"
				spanNulls:   true
				fillOpacity: 10
			}
		}
		targets: [
			grafana.#PromTarget & {
				expr:         _powerExpr
				legendFormat: _name
			},
		]
	}

	out: [stat, graph]
}

let bedroom = #RoomPanels & {room: "Bedroom", prefix: "bedroom_temperature", x: 0, y: 0}
let office = #RoomPanels & {room: "Office", prefix: "office_temperature", x: 6, y: 0}
let living = #RoomPanels & {room: "Living Room", prefix: "living_room_temperature", x: 12, y: 0}

let rackPower = #PowerTile & {name: "Rack Power", entity_id: "rack_power_power", y: 0}
let mediaPower = #PowerTile & {name: "Media Power", entity_id: "media_power_power", y: 4}
let deskPower = #PowerTile & {name: "Desk Power", entity_id: "desk_power_power", y: 8}

let washerExpr = #"{entity_id="laundry_power_power",__name__=~".*_value"}"#

let washerTile = grafana.#StatPanel & {
	title: "Washing Machine"
	gridPos: {h: 2, w: 6, x: 18, y: 12}
	options: graphMode: "none"
	fieldConfig: defaults: {
		mappings: [
			{
				type: "value"
				options: {
					"0": {text: "Idle", color: "text"}
					"1": {text: "Running", color: "blue"}
				}
			},
		]
	}
	targets: [
		grafana.#PromTarget & {
			expr:         "\(washerExpr) > bool 10"
			legendFormat: "State"
		},
	]
}

// Final Dashboard Output
out: grafana.#Dashboard & {
	title: "Home"
	uid:   "home-overview"
	tags: ["home", "iot"]
	panels: list.Concat([
		bedroom.out,
		office.out,
		living.out,
		rackPower.out,
		mediaPower.out,
		deskPower.out,
		[washerTile],
	])
}
