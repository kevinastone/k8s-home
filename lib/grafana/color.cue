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
