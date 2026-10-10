package vm_monitoring

import (
	"k8s-home.internal/lib/grafana"
)

// Reusable alert counter stat tile
#AlertCountTile: T={
	title:  string
	legend: string | *T.title
	color:  string
	expr:   string

	out: grafana.#StatPanel & {
		title: T.title
		gridPos: {h: 4, w: 6}
		options: {
			orientation: "auto"
			textMode:    "auto"
			graphMode:   "none"
			colorMode:   "background"
		}
		fieldConfig: defaults: {
			color: {
				mode:       "fixed"
				fixedColor: T.color
			}
			thresholds: {
				mode: "absolute"
				steps: [
					{color: "green", value: null},
					{color: T.color, value: 1},
				]
			}
		}
		targets: [
			grafana.#PromTarget & {
				expr:         T.expr
				legendFormat: T.legend
				instant:      true
			},
		]
	}
}

let criticalTile = #AlertCountTile & {
	title:  "Critical Alerts"
	legend: "Critical"
	color:  "red"
	expr:   #"count(ALERTS{alertstate="firing", severity="critical"}) or vector(0)"#
}

let warningTile = #AlertCountTile & {
	title:  "Warning Alerts"
	legend: "Warning"
	color:  "orange"
	expr:   #"count(ALERTS{alertstate="firing", severity="warning"}) or vector(0)"#
}

let totalFiringTile = grafana.#StatPanel & {
	title: "Total Firing Alerts"
	gridPos: {h: 4, w: 6}
	options: {
		orientation: "auto"
		textMode:    "auto"
		graphMode:   "none"
		colorMode:   "background"
	}
	fieldConfig: defaults: {
		color: mode: "thresholds"
		thresholds: {
			mode: "absolute"
			steps: [
				{color: "green", value: null},
				{color: "semi-dark-yellow", value: 1},
				{color: "red", value: 5},
			]
		}
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"count(ALERTS{alertstate="firing"}) or vector(0)"#
			legendFormat: "Firing"
			instant:      true
		},
	]
}

let pendingTile = #AlertCountTile & {
	title:  "Pending Alerts"
	legend: "Pending"
	color:  "yellow"
	expr:   #"count(ALERTS{alertstate="pending"}) or vector(0)"#
}

let alertListPanel = grafana.#AlertListPanel & {
	title: "Active & Firing Alerts"
	gridPos: {h: 12, w: 24}
}

let alertTimelinePanel = grafana.#StateTimelinePanel & {
	title: "Alert Timeline (Last 24 Hours)"
	gridPos: {h: 8, w: 24}
	fieldConfig: defaults: {
		color: mode: "palette-classic"
		custom: {
			fillOpacity: 70
			lineWidth:   0
		}
		mappings: [
			{
				type: "value"
				options: {
					"0": {color: "green", index: 0, text: "Inactive"}
					"1": {color: "red", index: 1, text: "Firing"}
				}
			},
		]
	}
	targets: [
		grafana.#PromTarget & {
			expr:         #"ALERTS{alertstate="firing"}"#
			legendFormat: "{{alertname}} ({{namespace}})"
		},
	]
}

let layout = grafana.#LayoutRows & {
	rows: [
		[criticalTile.out, warningTile.out, totalFiringTile, pendingTile.out],
		[alertListPanel],
		[alertTimelinePanel],
	]
}

out: grafana.#Dashboard & {
	title: "Alerts Single-Pane Overview"
	uid:   "alerts-single-pane"
	tags: ["alerts", "alertmanager", "victoria-metrics"]
	refresh: "10s"
	time: {
		from: "now-6h"
		to:   "now"
	}
	timepicker: refresh_intervals: [
		"5s",
		"10s",
		"30s",
		"1m",
		"5m",
	]
	liveNow: true
	links: [
		{
			title:   "Alertmanager Silences"
			url:     "/alerting/silences?alertmanager=Alertmanager"
			tooltip: "Manage or create Alertmanager silences"
		},
		{
			title:   "Alert Groups"
			url:     "/alerting/groups?alertmanager=Alertmanager"
			tooltip: "View grouped alerts in Alertmanager"
		},
		{
			title:   "Notification Policies"
			url:     "/alerting/routes?alertmanager=Alertmanager"
			tooltip: "View Alertmanager routing tree"
		},
	]
	panels: layout.out
}
