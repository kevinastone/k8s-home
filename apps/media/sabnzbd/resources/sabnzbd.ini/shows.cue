package sabnzbd

import (
	"list"
	"strings"
	"text/template"
)

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

#Filters4k: [
	#Filter & {filter_type: "R", value: "re:(1080|720)p"},
	#Filter & {filter_type: "M", value: "2160p"},
]

#FiltersHdr: [
	#Filter & {filter_type: "R", value: "SDR"},
	#Filter & {filter_type: "M", value: "re:(DV|HDR)"},
]

#Filters4kHdr: list.Concat([#Filters4k, #FiltersHdr])

#FilterPresets: {
	"4k":     #Filters4k
	"hdr":    #FiltersHdr
	"4k_hdr": #Filters4kHdr
}

#NzbGeekUri: {
	tvdb: int
	cat:  int | *5045
	dl:   int | *1
	out:  "https://api.nzbgeek.info/rss?dl=\(dl)&tvdb=\(tvdb)&cat=\(cat)&r=\(#Env.NZBGEEK_API_KEY)"
}

#TvShow: {
	name:     string
	season:   int & >=1 | *1
	cat:      #CategoryName | *"tv"
	uri:      #NzbGeekUri
	pp:       #PostProcessing.#Value | *"Default"
	script:   string | *""
	enable:   bool | *true
	priority: int | *-100

	preset?: string
	filters: [...#Filter] | *#Filters4kHdr
	if preset != _|_ {
		filters: #FilterPresets[preset]
	}

	let seasonFilter = #Filter & {
		filter_type: "S"
		value:       template.Execute("S{{printf \"%02d\" .}}", season)
	}

	let allFilters = list.Concat([filters, [seasonFilter]])

	out: """
		[[\(name)]]
		name = \(name)
		uri = \(uri.out)
		cat = \(cat)
		pp = \(#PostProcessing.#ToInt[pp])
		script = \((#QuoteIni & {"in": script}).out)
		enable = \(#BoolToInt["\(enable)"])
		priority = \(priority)
		\(strings.Join([for i, f in allFilters {"filter\(i) = \(f.out)"}], "\n"))
		"""
}

shows: [...#TvShow]
