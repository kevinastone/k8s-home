package sabnzbd

#FilterType: "A" | "R" | "M" | "C" | "S" | "F" | "<" | ">" | "G"
#Priority:   int & >=-1 & <=3

#Filter: {
	cat?:        #CategoryName
	pp:          #PostProcessing.#Value | *"Default"
	script?:     string
	filter_type: #FilterType
	value:       string
	priority?:   #Priority
	enabled:     bool | *true

	let _catStr = (#NoneOptional & {"in": cat}).out
	let _ppStr = #PostProcessing.#ToInt[pp]
	let _scriptStr = (#NoneOptional & {"in": script}).out
	let _priorityStr = (#NoneOptional & {"in": priority}).out

	out: "\((#QuoteIni & {"in": _catStr}).out), \(_ppStr), \((#QuoteIni & {"in": _scriptStr}).out), \(filter_type), \(value), \(_priorityStr), \(#BoolToInt["\(enabled)"])"
}

#FilterPresetName: or([for k, _ in filter_presets {k}])

filter_presets: [string]: [...#Filter]
