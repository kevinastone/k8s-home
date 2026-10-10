package grafana

// Base Prometheus Target
#PromTarget: {
	expr:         string
	legendFormat: string | *""
	format:       "time_series"
	instant:      bool | *false
	datasource?: {type: string, uid: string}
}

// Common Viz Legend Options
#LegendOptions: {
	showLegend?:  bool
	displayMode?: "list" | "table" | "hidden"
	placement?:   "bottom" | "right"
	calcs?: [...#CalcId]
}

// Common Viz Tooltip Options
#TooltipOptions: {
	mode?:      "single" | "multi" | "none"
	sort?:      "none" | "asc" | "desc"
	hideZeros?: bool
}

// Timeseries Panel Options
#TimeSeriesOptions: {
	alertThreshold?: bool
	legend?:         #LegendOptions
	tooltip?:        #TooltipOptions
}

// Base Panel Definition
#BasePanel: {
	title:        string | *""
	description?: string
	transparent?: bool
	datasource: {type: string | *"prometheus", uid: string | *"prometheus"}
	gridPos: {h?: int, w?: int, x?: int, y?: int}
	options?: {...}
	fieldConfig: {
		defaults: #FieldDefaults
		overrides: [...] | *[]
	}
	targets: [...#PromTarget]
	transformations?: [...]
}

// Timeseries Graph Panel
#TimeSeriesPanel: {
	#BasePanel
	type: "timeseries"
	options: #TimeSeriesOptions & {
		legend: {
			showLegend: bool | *false
		}
	}
	fieldConfig: defaults: custom: {
		drawStyle:         string | *"line"
		lineInterpolation: string | *"smooth"
		spanNulls:         bool | int | *true
		fillOpacity:       int | *10
		hideFrom?: {
			tooltip?: bool
			legend?:  bool
			viz?:     bool
		}
		axisPlacement?: "hidden" | "none" | "left" | "right" | "auto"
		...
	}
}

// Stat Panel
#StatPanel: {
	#BasePanel
	type: "stat"
	options: {
		reduceOptions:           #ReduceOptions
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
	gridPos: {h?: int, w?: int, x?: int, y?: int}
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
#StateTimelinePanel: {
	#BasePanel
	type: "state-timeline"
	options: {
		showValue:   "auto" | "always" | "never" | *"auto"
		mergeValues: bool | *true
		rowHeight:   number | *0.8
		alignValue:  "left" | "center" | "right" | *"left"
		tooltip: #TooltipOptions & {
			mode: "single" | "multi" | "none" | *"single"
			sort: "none" | "asc" | "desc" | *"none"
		}
		legend: #LegendOptions & {
			showLegend:  bool | *true
			displayMode: "list" | "table" | "hidden" | *"list"
			placement:   "bottom" | "right" | *"bottom"
		}
	}
}

// Gauge Panel
#GaugePanel: {
	#BasePanel
	type: "gauge"
	options: {
		orientation:          "auto" | "horizontal" | "vertical" | *"auto"
		showThresholdLabels:  bool | *false
		showThresholdMarkers: bool | *true
		sizing:               "auto" | "manual" | *"auto"
		minVizHeight?:        int
		minVizWidth?:         int
		reduceOptions: {
			values: bool | *true
			calcs: [...#CalcId] | *["last"]
			fields: string | *""
		}
	}
}

// Row Panel
#RowPanel: {
	title: string
	gridPos: {h: 1, w: 24, x?: int, y?: int}
	type:      "row"
	collapsed: bool | *false
	panels: [...] | *[]
}
