package monitoring

import (
	"k8s-home.internal/cue/grafana"
)

// Reusable Room Card: Stat panel with sparklines + temperature trend graph
#RoomPanels: R={
	room:      string
	entity_id: string

	let _tempExpr = #"max by (entity_id) (last_over_time(zigbee2mqtt_temperature{entity_id="\#(R.entity_id)"}[2h])) * 9 / 5 + 32"#
	let _humidityExpr = #"max by (entity_id) (last_over_time(zigbee2mqtt_humidity{entity_id="\#(R.entity_id)"}[2h]))"#
	let _pressureExpr = #"max by (entity_id) (last_over_time(zigbee2mqtt_pressure{entity_id="\#(R.entity_id)"}[2h])) * 0.02952998"#

	// 1. Environment Stats Panel (Temp, Humidity, Pressure)
	statPanel: grafana.#StatPanel & {
		title: R.room
		gridPos: {h: 5, w: 6}
		options: {
			orientation: "horizontal"
			textMode:    "value_and_name"
			graphMode:   "area"
			colorMode:   "none"
		}
		fieldConfig: {
			defaults: {
				fieldMinMax: true
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
			grafana.#PromTarget & {expr: _tempExpr, legendFormat: "Temperature"},
			grafana.#PromTarget & {expr: _humidityExpr, legendFormat: "Humidity"},
			grafana.#PromTarget & {expr: _pressureExpr, legendFormat: "Pressure"},
		]
	}

	// 2. Temperature History Graph (matching Lovelace card footer)
	graphPanel: grafana.#TimeSeriesPanel & {
		title: "\(R.room) Temperature History"
		gridPos: {h: 4, w: 6}
		fieldConfig: defaults: {
			unit: "fahrenheit"
			custom: {
				spanNulls:   true
				fillOpacity: 10
			}
		}
		targets: [
			grafana.#PromTarget & {expr: _tempExpr, legendFormat: R.room},
		]
	}

	out: [statPanel, graphPanel]
}

// Reusable Power Device: Stat panel with built-in area sparkline
#PowerTile: P={
	name:      string
	entity_id: string

	let _powerExpr = #"max by (entity_id) (last_over_time(zigbee2mqtt_power{entity_id="\#(P.entity_id)"}[2h]))"#

	out: grafana.#StatPanel & {
		gridPos: {h: 3, w: 6}
		options: {
			orientation:            "auto"
			textMode:               "value_and_name"
			wideLayout:             true
			colorMode:              "none"
			graphMode:              "area"
			justifyMode:            "auto"
			showPercentChange:      false
			percentChangeColorMode: "standard"
		}
		fieldConfig: defaults: {
			unit: "watt"
			color: mode: "palette-classic"
			thresholds: {
				mode: "absolute"
				steps: [
					{color: "green", value: null},
				]
			}
		}
		targets: [
			grafana.#PromTarget & {expr: _powerExpr, legendFormat: P.name},
		]
	}
}

// Reusable Binary State Tile (e.g. appliances derived from power consumption)
#BinaryApplianceTile: T={
	name:      string
	entity_id: string
	threshold: number

	let _applianceExpr = #"max by (entity_id) (last_over_time(zigbee2mqtt_power{entity_id="\#(T.entity_id)"}[2h])) > bool \#(T.threshold)"#

	out: grafana.#StatPanel & {
		title: T.name
		gridPos: {h: 3, w: 6}
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
				expr:         _applianceExpr
				legendFormat: "State"
			},
		]
	}
}

// Declarative definitions of rooms and monitored devices
#Rooms: [
	{name: "Bedroom", entity_id: "bedroom_temperature"},
	{name: "Office", entity_id: "office_temperature"},
	{name: "Living Room", entity_id: "living_room_temperature"},
]

#PowerDevices: [
	{name: "Rack Power", entity_id: "rack_power"},
	{name: "Media Power", entity_id: "media_power"},
	{name: "Desk Power", entity_id: "desk_power"},
]

let washerTile = #BinaryApplianceTile & {
	name:      "Washing Machine"
	entity_id: "laundry_power"
	threshold: 10
}

// Dashboard columns layout
let roomColumns = [for r in #Rooms {
	(#RoomPanels & {room: r.name, entity_id: r.entity_id}).out
}]

let powerColumn = [
	for p in #PowerDevices {
		(#PowerTile & {name: p.name, entity_id: p.entity_id}).out
	},
	washerTile.out,
]

let layout = grafana.#LayoutColumns & {
	columns: [
		for col in roomColumns {col},
		powerColumn,
	]
}

// Final Dashboard Output
out: grafana.#Dashboard & {
	title: "Home"
	uid:   "home-overview"
	time: (grafana.#Last & {in: "24h"}).out
	tags: ["home", "iot"]
	panels: layout.out
}
