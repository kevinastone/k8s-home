package sabnzbd

import (
	"strings"
	"text/template"
)

#FilterType: "A" | "R" | "M" | "C" | "S" | "F" | "<" | ">" | "G"
#Priority:   -100 | -1 | 0 | 1 | 2 | 3

#Filter: {
	cat:         string | *"None"
	pp:          string | *""
	script:      string | *"None"
	filter_type: #FilterType
	value:       string
	priority:    #Priority | "None" | *-100
	enabled:     bool | *true

	let _catStr = (#QuoteIni & {"in": cat}).out
	let _ppStr = (#QuoteIni & {"in": pp}).out
	let _scriptStr = (#QuoteIni & {"in": script}).out
	let _priorityStr = "\(priority)"

	out: "\(_catStr), \(_ppStr), \(_scriptStr), \(filter_type), \(value), \(_priorityStr), \(#BoolToInt["\(enabled)"])"
}

#Filters4kHdr: [
	#Filter & {filter_type: "R", value: "re:(1080|720)p", priority: "None"},
	#Filter & {filter_type: "R", value: "SDR", priority: "None"},
	#Filter & {filter_type: "M", value: "2160p", priority: "None"},
	#Filter & {filter_type: "M", value: "re:(DV|HDR)", priority: "None"},
]

#FilterPresets: {
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
	cat:      string | *"tv"
	uri:      #NzbGeekUri
	pp:       string | *""
	script:   string | *""
	enable:   bool | *true
	priority: int | *-100

	preset?: string
	filters: [...#Filter] | *#Filters4kHdr
	if preset != _|_ {
		filters: #FilterPresets[preset]
	}

	let seasonFilter = #Filter & {
		cat:         ""
		pp:          ""
		script:      "None"
		filter_type: "S"
		value:       template.Execute("S{{printf \"%02d\" .}}", season)
		priority:    -100
	}

	let allFilters = [
		for f in filters {f},
		seasonFilter,
	]

	out: """
		[[\(name)]]
		name = \(name)
		uri = \(uri.out)
		cat = \(cat)
		pp = \((#QuoteIni & {"in": pp}).out)
		script = \((#QuoteIni & {"in": script}).out)
		enable = \(#BoolToInt["\(enable)"])
		priority = \(priority)
		\(strings.Join([for i, f in allFilters {"filter\(i) = \(f.out)"}], "\n"))
		"""
}

shows: [...#TvShow]
