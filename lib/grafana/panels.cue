package grafana

import (
	dash "github.com/grafana/grafana/kinds/dashboard:kind"
	gaugePlugin "github.com/grafana/grafana/public/app/plugins/panel/gauge:grafanaplugin"
	statPlugin "github.com/grafana/grafana/public/app/plugins/panel/stat:grafanaplugin"
	stateTimelinePlugin "github.com/grafana/grafana/public/app/plugins/panel/state-timeline:grafanaplugin"
	tsPlugin "github.com/grafana/grafana/public/app/plugins/panel/timeseries:grafanaplugin"
)

#Panel:                          dash.lineage.schemas[0].schema.#Panel
#CanonicalTimeSeriesOptions:     tsPlugin.composableKinds.PanelCfg.lineage.schemas[0].schema.Options
#CanonicalTimeSeriesFieldConfig: tsPlugin.composableKinds.PanelCfg.lineage.schemas[0].schema.FieldConfig

#CanonicalStatOptions:  statPlugin.composableKinds.PanelCfg.lineage.schemas[0].schema.Options
#CanonicalGaugeOptions: gaugePlugin.composableKinds.PanelCfg.lineage.schemas[0].schema.Options

#CanonicalStateTimelineOptions:     stateTimelinePlugin.composableKinds.PanelCfg.lineage.schemas[0].schema.Options
#CanonicalStateTimelineFieldConfig: stateTimelinePlugin.composableKinds.PanelCfg.lineage.schemas[0].schema.FieldConfig

#PromTarget: {
	expr:         string
	legendFormat: string | *"__auto"
	format:       "time_series"
	instant:      bool | *false
	datasource?: {type: string, uid: string}
}

#BasePanel: #Panel & {
	title?: string | *""
	datasource: {type: string | *"prometheus", uid: string | *"prometheus"}
	fieldConfig?: defaults: #FieldDefaults
	targets?: [...#PromTarget]
}

#TimeSeriesPanel: {
	#BasePanel
	type: "timeseries"
	options: #CanonicalTimeSeriesOptions & {
		legend: {
			showLegend:  *false | _
			displayMode: *"list" | _
			placement:   *"bottom" | _
			calcs: *[] | _
		}
		tooltip: {
			mode: *"single" | _
			sort: *"none" | _
		}
	}
	fieldConfig: defaults: custom: #CanonicalTimeSeriesFieldConfig & {
		drawStyle:         *"line" | _
		lineInterpolation: *"smooth" | _
		spanNulls:         *true | _
		fillOpacity:       *10 | _
	}
}

#StatPanel: {
	#BasePanel
	type: "stat"
	options: #CanonicalStatOptions & {
		orientation:   *"auto" | _
		reduceOptions: #ReduceOptions
	}
}

#AlertListPanel: {
	#BasePanel
	type: "alertlist"
	options: {
		viewMode:      *"list" | "stat"
		groupMode:     *"default" | "none"
		showInstances: *true | bool
		maxItems:      *50 | int
		sortOrder:     *1 | int
		stateFilter: {
			error:      *true | bool
			firing:     *true | bool
			pending:    *true | bool
			noData:     *false | bool
			normal:     *false | bool
			recovering: *false | bool
		}
	}
}

#StateTimelinePanel: {
	#BasePanel
	type: "state-timeline"
	options: #CanonicalStateTimelineOptions & {
		tooltip: {
			mode: *"single" | _
			sort: *"none" | _
		}
		legend: {
			showLegend:  *true | _
			displayMode: *"list" | _
			placement:   *"bottom" | _
			calcs: *[] | _
		}
	}
}

#GaugePanel: {
	#BasePanel
	type: "gauge"
	options: #CanonicalGaugeOptions & {
		orientation:   *"auto" | _
		reduceOptions: #ReduceOptions
	}
}

#RowPanel: dash.lineage.schemas[0].schema.#RowPanel & {
	id:        *0 | uint32
	collapsed: *false | _
	panels: *[] | _
	gridPos: {
		h: *1 | _
		w: *24 | _
	}
}
