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

// Common Field Config Defaults
#FieldDefaults: {
	unit?: string
	mappings: [...] | *[]
	links?: [...#DataLink]
	color?: #FieldColor
	thresholds?: {
		mode: "absolute" | "percentage"
		steps: [...]
	}
	custom?: {...}
}

// Base Panel Definition
#BasePanel: {
	title: string | *""
	datasource: {type: "prometheus", uid: "prometheus"}
	gridPos: {h: int, w: int, x?: int, y?: int}
	type: string
	options?: {...}
	fieldConfig: {
		defaults: #FieldDefaults
		overrides: [...] | *[]
	}
	targets: [...#PromTarget]
}

// Dashboard Link Definition
#DashboardLink: {
	title:       string
	url:         string
	tooltip?:    string
	type:        "link" | *"link"
	icon:        string | *"external link"
	targetBlank: bool | *true
	asDropdown:  bool | *false
	includeVars: bool | *false
	keepTime:    bool | *false
	tags: [...string] | *[]
}

// Timeseries Graph Panel
#TimeSeriesPanel: #BasePanel & {
	type: "timeseries"
	options: legend: showLegend: bool | *false
	fieldConfig: defaults: custom: {
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
}

// Stat Panel
#StatPanel: #BasePanel & {
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
}

// Alert List Panel
#AlertListPanel: {
	title: string | *""
	gridPos: {h: int, w: int, x?: int, y?: int}
	type: "alertlist"
	options: {
		viewMode:      "list" | "stat" | *"list"
		groupMode:     "default" | "none" | *"default"
		showInstances: bool | *true
		maxItems:      int | *50
		sortOrder:     int | *1
		stateFilter: {
			error:      bool | *true
			firing:     bool | *true
			pending:    bool | *true
			noData:     bool | *false
			normal:     bool | *false
			recovering: bool | *false
		}
	}
}

// State Timeline Panel
#StateTimelinePanel: #BasePanel & {
	type: "state-timeline"
	options: {
		showValue:   "auto" | "always" | "never" | *"auto"
		mergeValues: bool | *true
		rowHeight:   number | *0.8
		alignValue:  "left" | "center" | "right" | *"left"
		tooltip: {
			mode: "single" | "multi" | "none" | *"single"
			sort: "none" | "asc" | "desc" | *"none"
		}
		legend: {
			showLegend:  bool | *true
			displayMode: "list" | "table" | "hidden" | *"list"
			placement:   "bottom" | "right" | *"bottom"
		}
	}
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
	timepicker?: {
		refresh_intervals: [...string]
	}
	liveNow?: bool
	links?: [...#DashboardLink]
	templating: {
		list: [...] | *[]
	}
	panels: [...]
}
