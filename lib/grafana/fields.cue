package grafana

// Field Color Modes matching Grafana's canonical schema
#FieldColorModeId:
	"thresholds" |
	"fixed" |
	"shades" |
	"palette-classic" |
	"palette-classic-by-name" |
	"palette-colorblind" |
	"palette-categorical-next" |
	"continuous-GrYlRd" |
	"continuous-RdYlGr" |
	"continuous-BlYlRd" |
	"continuous-YlRd" |
	"continuous-BlPu" |
	"continuous-YlBl" |
	"continuous-blues" |
	"continuous-reds" |
	"continuous-greens" |
	"continuous-purples" |
	"continuous-viridis" |
	"continuous-magma" |
	"continuous-plasma" |
	"continuous-inferno" |
	"continuous-cividis"

// Field Color Definition
#FieldColor: {
	mode:        #FieldColorModeId
	fixedColor?: string
	seriesBy?:   "min" | "max" | "last"
}

// Data Link Definition
#DataLink: {
	title:       string
	url:         string
	targetBlank: bool | *false
}

// Standard Grafana Field Reducer Calculations (ReducerID)
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

// Common Reduce Options for Stat, Gauge, Bar Gauge, etc.
#ReduceOptions: {
	values: bool | *false
	calcs: [...#CalcId] | *["lastNotNull"]
	fields: string | *""
}

// Common Field Config Defaults
#FieldDefaults: {
	displayName?: string
	unit?:        string
	min?:         number
	max?:         number
	noValue?:     string
	mappings: [...] | *[]
	links?: [...#DataLink]
	color?: #FieldColor
	thresholds?: {
		mode: "absolute" | "percentage"
		steps: [...]
	}
	custom?: {...}
}
