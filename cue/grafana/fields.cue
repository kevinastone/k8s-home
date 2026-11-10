package grafana

import (
	dash "github.com/grafana/grafana/kinds/dashboard:kind"
	"github.com/grafana/grafana/packages/grafana-schema/src/common"
)

#FieldColorModeId:  dash.lineage.schemas[0].schema.#FieldColorModeId
#FieldColor:        dash.lineage.schemas[0].schema.#FieldColor
#FieldConfig:       dash.lineage.schemas[0].schema.#FieldConfig
#FieldConfigSource: dash.lineage.schemas[0].schema.#FieldConfigSource
#GridPos:           dash.lineage.schemas[0].schema.#GridPos
#ThresholdsConfig:  dash.lineage.schemas[0].schema.#ThresholdsConfig
#ValueMapping:      dash.lineage.schemas[0].schema.#ValueMapping
#MatcherConfig:     dash.lineage.schemas[0].schema.#MatcherConfig

#CalcId:
	"last" |
	"lastNotNull" |
	"first" |
	"firstNotNull" |
	"mean" |
	"sum" |
	"min" |
	"max" |
	"count" |
	"range" |
	"delta" |
	"step" |
	"diff" |
	"diffperc" |
	"changeCount" |
	"distinctCount" |
	"logmin" |
	"allIsNull" |
	"allIsZero"

#ReduceOptions: common.ReduceDataOptions & {
	values: *false | _
	calcs: *["lastNotNull"] | _
	fields: *"" | _
}

#FieldDefaults: #FieldConfig & {
	mappings: *[] | _
}
