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
			defaults: {}
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

	// 1. Current Power Stat Panel (clean number, no background overlap, no thresholds)
	stat: grafana.#StatPanel & {
		title: _name
		gridPos: {h: 2, w: 6, x: _x, y: _y}
		options: graphMode: "none"
		fieldConfig: defaults: unit: "watt"
		targets: [
			grafana.#PromTarget & {
				expr:         _powerExpr
				legendFormat: _name
			},
		]
	}

	// 2. Trend Graph directly below the stat value (no redundant title, no axis noise)
	graph: grafana.#TimeSeriesPanel & {
		title: ""
		gridPos: {h: 2, w: 6, x: _x, y: _y + 2}
		options: legend: showLegend: false
		fieldConfig: defaults: {
			unit: "watt"
			custom: {
				drawStyle:     "line"
				spanNulls:     true
				fillOpacity:   10
				axisPlacement: "none"
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

// Declarative definitions of rooms and monitored devices
#Rooms: [
	{name: "Bedroom", prefix: "bedroom_temperature"},
	{name: "Office", prefix: "office_temperature"},
	{name: "Living Room", prefix: "living_room_temperature"},
]

#PowerDevices: [
	{name: "Rack Power", entity_id: "rack_power_power"},
	{name: "Media Power", entity_id: "media_power_power"},
	{name: "Desk Power", entity_id: "desk_power_power"},
]

// Reusable Binary State Tile (e.g. appliances derived from power consumption)
#BinaryApplianceTile: {
	name:      string
	entity_id: string
	threshold: number
	x:         int | *18
	y:         int

	let _name = name
	let _entity_id = entity_id
	let _threshold = threshold
	let _x = x
	let _y = y

	out: grafana.#StatPanel & {
		title: _name
		gridPos: {h: 2, w: 6, x: _x, y: _y}
		options: graphMode: "none"
		fieldConfig: defaults: mappings: [
			{
				type: "value"
				options: {
					"0": {text: "Idle", color: "text"}
					"1": {text: "Running", color: "blue"}
				}
			},
		]
		targets: [
			grafana.#PromTarget & {
				expr:         #"{entity_id="\#(_entity_id)",__name__=~".*_value"} > bool \#(_threshold)"#
				legendFormat: "State"
			},
		]
	}
}

let roomPanels = [for i, r in #Rooms {
	(#RoomPanels & {room: r.name, prefix: r.prefix, x: i * 6, y: 0}).out
}]

let powerPanels = [for i, p in #PowerDevices {
	(#PowerTile & {name: p.name, entity_id: p.entity_id, x: 18, y: i * 4}).out
}]

let washerTile = #BinaryApplianceTile & {
	name:      "Washing Machine"
	entity_id: "laundry_power_power"
	threshold: 10
	x:         18
	y:         len(#PowerDevices) * 4
}

// Final Dashboard Output
out: grafana.#Dashboard & {
	title: "Home"
	uid:   "home-overview"
	tags: ["home", "iot"]
	panels: list.Concat(list.Concat([
		roomPanels,
		powerPanels,
		[[washerTile.out]],
	]))
}
