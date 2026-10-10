package grafana

import (
	dash "github.com/grafana/grafana/kinds/dashboard:kind"
)

#DashboardSpec: dash.lineage.schemas[0].schema.spec
#VariableModel: dash.lineage.schemas[0].schema.#VariableModel
#DashboardLink: *#DashboardUrlLink | #DashboardTagLink

#Duration: string & =~"^[0-9]+(ms|[smhdwMy])$"

#Last: {
	in: #Duration
	out: {
		from: "now-\(in)"
		to:   "now"
	}
}

#DashboardUrlLink: dash.lineage.schemas[0].schema.#DashboardLink & {
	type:    "link"
	url:     string
	icon:    *"" | _
	tooltip: *"" | _
	tags: *[] | _
}

#DashboardTagLink: dash.lineage.schemas[0].schema.#DashboardLink & {
	type:       "dashboards"
	icon:       *"" | _
	tooltip:    *"" | _
	asDropdown: *false | _
}

#QueryVariable: V={
	#VariableModel
	name:  string
	type:  "query"
	label: *V.name | _
	datasource: {type: *"prometheus" | _, uid: *"prometheus" | _}
	query: {
		query: string
		refId: *"StandardVariableQuery" | _
	}
	definition: *V.query.query | _
	refresh:    *1 | _
	sort:       *1 | _
}

#Dashboard: #DashboardSpec & {
	title: string
	uid:   string
	links?: [...#DashboardLink]
}
