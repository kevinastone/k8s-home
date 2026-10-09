package monitoring

import "list"

// Reusable Prometheus target definition
#PromTarget: {
	expr:         string
	legendFormat: string | *""
	format:       "time_series"
	instant:      bool | *false
}

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

	// 1. Environment Stats Panel (Temp, Humidity, Pressure)
	statPanel: {
		type:  "stat"
		title: "\(_room)"
		datasource: {type: "prometheus", uid: "prometheus"}
		gridPos: {h: 5, w: 6, x: _x, y: _y}
		options: {
			reduceOptions: {values: false, calcs: ["lastNotNull"], fields: ""}
			orientation: "horizontal"
			textMode:    "value_and_name"
			graphMode:   "area"
		}
		fieldConfig: {
			defaults: {
				mappings: []
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
			#PromTarget & {
				expr:         "last_over_time({entity_id=\"\(prefix)_temperature\",__name__=~\".*_value\"}[24h])"
				legendFormat: "Temperature"
			},
			#PromTarget & {
				expr:         "last_over_time({entity_id=\"\(prefix)_humidity\",__name__=~\".*_value\"}[24h])"
				legendFormat: "Humidity"
			},
			#PromTarget & {
				expr:         "last_over_time({entity_id=\"\(prefix)_pressure\",__name__=~\".*_value\"}[24h])"
				legendFormat: "Pressure"
			},
		]
	}

	// 2. Temperature History Graph (matching Lovelace card footer)
	graphPanel: {
		type:  "timeseries"
		title: "\(_room) Temperature History"
		datasource: {type: "prometheus", uid: "prometheus"}
		gridPos: {h: 4, w: 6, x: _x, y: _y + 5}
		options: {
			legend: {
				showLegend: false
			}
		}
		fieldConfig: defaults: {
			unit: "fahrenheit"
			custom: {
				drawStyle:         "line"
				lineInterpolation: "smooth"
				spanNulls:         true
				fillOpacity:       10
			}
		}
		targets: [
			#PromTarget & {
				expr:         "{entity_id=\"\(_prefix)_temperature\",__name__=~\".*_value\"}"
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

	type:  "stat"
	title: name
	datasource: {type: "prometheus", uid: "prometheus"}
	options: {
		reduceOptions: {values: false, calcs: ["lastNotNull"], fields: ""}
		graphMode: "area"
	}
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
		#PromTarget & {
			expr:         "last_over_time({entity_id=\"\(entity_id)\",__name__=~\".*_value\"}[24h])"
			legendFormat: name
		},
	]
}

let bedroom = #RoomPanels & {room: "Bedroom", prefix: "bedroom_temperature", x: 0, y: 0}
let office = #RoomPanels & {room: "Office", prefix: "office_temperature", x: 6, y: 0}
let living = #RoomPanels & {room: "Living Room", prefix: "living_room_temperature", x: 12, y: 0}

let rackPower = #PowerTile & {name: "Rack Power", entity_id: "rack_power_power", gridPos: {h: 2, w: 6, x: 18, y: 0}}
let mediaPower = #PowerTile & {name: "Media Power", entity_id: "media_power_power", gridPos: {h: 2, w: 6, x: 18, y: 2}}
let deskPower = #PowerTile & {name: "Desk Power", entity_id: "desk_power_power", gridPos: {h: 2, w: 6, x: 18, y: 4}}

let washerTile = {
	type:  "stat"
	title: "Washing Machine"
	datasource: {type: "prometheus", uid: "prometheus"}
	gridPos: {h: 3, w: 6, x: 18, y: 6}
	options: {
		reduceOptions: {values: false, calcs: ["lastNotNull"], fields: ""}
		graphMode: "none"
	}
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
		#PromTarget & {
			expr:         "last_over_time({entity_id=\"laundry_power_power\",__name__=~\".*_value\"}[24h]) > bool 10"
			legendFormat: "State"
		},
	]
}

// Final Dashboard Output
out: {
	title: "Home"
	uid:   "home-overview"
	tags: ["home", "iot"]
	timezone:      "browser"
	schemaVersion: 39
	refresh:       "30s"
	time: {
		from: "now-24h"
		to:   "now"
	}
	panels: list.Concat([
		bedroom.out,
		office.out,
		living.out,
		[rackPower, mediaPower, deskPower, washerTile],
	])
}
