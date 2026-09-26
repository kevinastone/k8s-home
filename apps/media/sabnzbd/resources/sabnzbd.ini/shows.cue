package sabnzbd

import (
	"list"
	"strings"
	"text/template"
)

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

	presets: [...#FilterPresetName] | *["4k", "hdr"]
	filters: [...#Filter] | *list.Concat([for p in presets {filter_presets[p]}])

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
