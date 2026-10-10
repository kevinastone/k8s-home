package grafana

// Time Duration String with Unit (e.g. 5s, 1m, 1h, 1d)
#Duration: string & =~"^[0-9]+(ms|[smhdwMy])$"

// Time Range Helper: (grafana.#Last & {in: "6h"}).out
#Last: {
	in: #Duration
	out: {
		from: "now-\(in)"
		to:   "now"
	}
}

// Common Dashboard Link Properties
#DashboardLinkBase: {
	title:        string
	tooltip?:     string
	icon?:        string
	targetBlank?: bool
	includeVars?: bool
	keepTime?:    bool
}

// External / URL Dashboard Link
#DashboardUrlLink: {
	#DashboardLinkBase
	type: "link"
	url:  string
}

// Tag-based Dashboard Dropdown Link
#DashboardTagLink: {
	#DashboardLinkBase
	type: "dashboards"
	tags: [...string]
	asDropdown?: bool
}

// Dashboard Link Discriminated Union (defaults to URL link variant)
#DashboardLink: *#DashboardUrlLink | #DashboardTagLink

// Template Query Variable
#QueryVariable: V={
	name:         string
	type:         "query"
	label?:       string | *V.name
	description?: string
	datasource: {type: string | *"prometheus", uid: string | *"prometheus"}
	query: {
		query: string
		refId: string | *"StandardVariableQuery"
	}
	definition: string | *V.query.query
	// 0: Never, 1: On dashboard load, 2: On time range change
	refresh: >=0 & <=2 | *1
	// 0: Disabled, 1: Alpha (asc), 2: Alpha (desc), 3: Num (asc), 4: Num (desc),
	// 5: Case-insensitive (asc), 6: Case-insensitive (desc), 7: Natural (asc), 8: Natural (desc)
	sort:        >=0 & <=8 | *1
	hide?:       0 | 1 | 2
	includeAll?: bool
	multi?:      bool
	regex?:      string
	options?: [...]
	current?: {
		text:  string
		value: string
	}
}

// Dashboard Definition
#Dashboard: {
	title:         string
	uid:           string
	schemaVersion: int | *39
	panels: [...]
	description?: string
	tags?: [...string]
	timezone?: "browser" | "utc"
	editable?: bool
	refresh?:  #Duration | bool | ""
	time?: {
		from?: string
		to?:   string
	}
	timepicker?: {
		refresh_intervals?: [...#Duration]
	}
	liveNow?: bool
	links?: [...#DashboardLink]
	templating?: {
		list?: [...]
	}
}
