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

	let _tempExpr = "{entity_id=\"\(_prefix)_temperature\",__name__=~\".*_value\"}"
	let _humidityExpr = "{entity_id=\"\(_prefix)_humidity\",__name__=~\".*_value\"}"
	let _pressureExpr = "{entity_id=\"\(_prefix)_pressure\",__name__=~\".*_value\"}"

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
					properties: [
						{id: "unit", value: "fahrenheit"},
						{id: "links", value: [grafana.#ExploreLink & {#expr: _tempExpr, title: "\(_room) Temperature History"}]},
					]
				},
				{
					matcher: {id: "byName", options: "Humidity"}
					properties: [
						{id: "unit", value: "percent"},
						{id: "links", value: [grafana.#ExploreLink & {#expr: _humidityExpr, title: "\(_room) Humidity History"}]},
					]
				},
				{
					matcher: {id: "byName", options: "Pressure"}
					properties: [
						{id: "unit", value: "inHg"},
						{id: "links", value: [grafana.#ExploreLink & {#expr: _pressureExpr, title: "\(_room) Pressure History"}]},
					]
				},
			]
		}
		targets: [
			grafana.#PromTarget & {
				expr:         "last_over_time(\(_tempExpr)[24h])"
				legendFormat: "Temperature"
			},
			grafana.#PromTarget & {
				expr:         "last_over_time(\(_humidityExpr)[24h])"
				legendFormat: "Humidity"
			},
			grafana.#PromTarget & {
				expr:         "last_over_time(\(_pressureExpr)[24h])"
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

// Reusable Power Tile template
#PowerTile: {
	name:      string
	entity_id: string
	gridPos: {h: int, w: int, x: int, y: int}

	let _powerExpr = "{entity_id=\"\(entity_id)\",__name__=~\".*_value\"}"

	grafana.#StatPanel & {
		title:     name
		"gridPos": gridPos
		fieldConfig: defaults: {
			unit: "watt"
			links: [
				grafana.#ExploreLink & {#expr: _powerExpr, title: "\(name) Power History"},
			]
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
				expr:         "last_over_time(\(_powerExpr)[24h])"
				legendFormat: name
			},
		]
	}
}

let bedroom = #RoomPanels & {room: "Bedroom", prefix: "bedroom_temperature", x: 0, y: 0}
let office = #RoomPanels & {room: "Office", prefix: "office_temperature", x: 6, y: 0}
let living = #RoomPanels & {room: "Living Room", prefix: "living_room_temperature", x: 12, y: 0}

let rackPower = #PowerTile & {name: "Rack Power", entity_id: "rack_power_power", gridPos: {h: 2, w: 6, x: 18, y: 0}}
let mediaPower = #PowerTile & {name: "Media Power", entity_id: "media_power_power", gridPos: {h: 2, w: 6, x: 18, y: 2}}
let deskPower = #PowerTile & {name: "Desk Power", entity_id: "desk_power_power", gridPos: {h: 2, w: 6, x: 18, y: 4}}

let washerExpr = "{entity_id=\"laundry_power_power\",__name__=~\".*_value\"}"

let washerTile = grafana.#StatPanel & {
	title: "Washing Machine"
	gridPos: {h: 3, w: 6, x: 18, y: 6}
	options: graphMode: "none"
	fieldConfig: defaults: {
		links: [
			grafana.#ExploreLink & {#expr: washerExpr, title: "Laundry Power History"},
		]
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
			expr:         "last_over_time(\(washerExpr)[24h]) > bool 10"
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
		[rackPower, mediaPower, deskPower, washerTile],
	])
}
