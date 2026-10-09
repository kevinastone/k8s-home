package grafana

// Base Prometheus Target
#PromTarget: {
	expr:         string
	legendFormat: string | *""
	format:       "time_series"
	instant:      bool | *false
}

// Data Link Definition
#DataLink: {
	title:       string
	url:         string
	targetBlank: bool | *false
}

// Timeseries Graph Panel
#TimeSeriesPanel: {
	title: string
	datasource: {type: "prometheus", uid: "prometheus"}
	gridPos: {h: int, w: int, x?: int, y?: int}
	type: "timeseries"
	options: legend: showLegend: bool | *false
	fieldConfig: {
		defaults: {
			custom: {
				drawStyle:         "line"
				lineInterpolation: "smooth"
				spanNulls:         bool | *true
				fillOpacity:       int | *10
				hideFrom?: {
					tooltip?: bool
					legend?:  bool
					viz?:     bool
				}
				axisPlacement?: "hidden" | "none" | "left" | "right" | "auto"
			}
			unit?: string
		}
		overrides: [...] | *[]
	}
	targets: [...#PromTarget]
}

// Stat Panel
#StatPanel: {
	title: string
	datasource: {type: "prometheus", uid: "prometheus"}
	gridPos: {h: int, w: int, x?: int, y?: int}
	type: "stat"
	options: {
		reduceOptions: {values: false, calcs: ["lastNotNull"], fields: ""}
		orientation:             "horizontal" | "vertical" | "auto" | *"auto"
		textMode:                "auto" | "value" | "value_and_name" | "name" | *"auto"
		graphMode:               "none" | "area" | *"area"
		colorMode?:              "value" | "background" | "none"
		wideLayout?:             bool
		justifyMode?:            "auto" | "center"
		showPercentChange?:      bool
		percentChangeColorMode?: string
	}
	fieldConfig: {
		defaults: {
			mappings: [...] | *[]
			links?: [...#DataLink]
			thresholds?: {
				mode: "absolute" | "percentage"
				steps: [...]
			}
			unit?: string
			color?: {
				mode: string
			}
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
	templating: {
		list: [...] | *[]
	}
	panels: [...]
}
