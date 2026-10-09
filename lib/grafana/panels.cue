package grafana

import "encoding/json"

// Base Prometheus Target
#PromTarget: {
	expr:         string
	legendFormat: string | *""
	format:       "time_series"
	instant:      bool | *false
}

// Data Link Definition
#DataLink: {
	title:       string | *"View History in Explore"
	url:         string
	targetBlank: bool | *false
}

// Helper to construct an Explore link for Prometheus
#ExploreLink: {
	#expr:       string
	title:       string | *"View History in Explore"
	targetBlank: bool | *false

	let _panes = {
		left: {
			datasource: "prometheus"
			queries: [
				{
					expr:  #expr
					refId: "A"
					datasource: {type: "prometheus", uid: "prometheus"}
				},
			]
			range: {
				from: "now-24h"
				to:   "now"
			}
			panelsState: {
				trace: {
					spanNulls: true
				}
				graph: {
					spanNulls: true
				}
			}
		}
	}

	url: "/explore?schemaVersion=1&panes=\(json.Marshal(_panes))"
}

// Timeseries Graph Panel
#TimeSeriesPanel: {
	title: string
	datasource: {type: "prometheus", uid: "prometheus"}
	gridPos: {h: int, w: int, x: int, y: int}
	type: "timeseries"
	options: legend: showLegend: bool | *false
	fieldConfig: defaults: {
		custom: {
			drawStyle:         "line"
			lineInterpolation: "smooth"
			spanNulls:         bool | *true
			fillOpacity:       int | *10
		}
		unit?: string
	}
	targets: [...#PromTarget]
}

// Stat Panel
#StatPanel: {
	title: string
	datasource: {type: "prometheus", uid: "prometheus"}
	gridPos: {h: int, w: int, x: int, y: int}
	type: "stat"
	options: {
		reduceOptions: {values: false, calcs: ["lastNotNull"], fields: ""}
		orientation: "horizontal" | "vertical" | "auto" | *"auto"
		textMode:    "auto" | "value" | "value_and_name" | "name" | *"auto"
		graphMode:   "none" | "area" | *"area"
	}
	fieldConfig: {
		defaults: {
			mappings: [...] | *[]
			links?: [...#DataLink]
			thresholds?: {
				mode: "absolute"
				steps: [...]
			}
			unit?: string
		}
		overrides: [...] | *[]
	}
	targets: [...#PromTarget]
}

// Dashboard Definition
#Dashboard: {
	title: string
	uid:   string
	tags: [...string] | *[]
	timezone:      "browser" | "utc" | *"browser"
	schemaVersion: int | *39
	refresh:       string | *"30s"
	time: {
		from: string | *"now-24h"
		to:   string | *"now"
	}
	panels: [...]
}
