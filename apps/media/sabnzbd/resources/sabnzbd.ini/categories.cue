package sabnzbd

#PostProcessing: {
	#Value: "Default" | "None" | "Repair" | "Unpack" | "Delete"

	#ToInt: {
		"Default": "\"\""
		"None":    "0"
		"Repair":  "1"
		"Unpack":  "2"
		"Delete":  "3"
	}
}

#CategoryScript: "Default" | "None" | string

#Category: {
	name:     string
	order:    int | *0
	pp:       #PostProcessing.#Value | *"Default"
	script:   #CategoryScript | *"Default"
	dir:      string | *""
	newzbin:  string | *""
	priority: int | *-100

	out: """
		[[\(name)]]
		name = \(name)
		order = \(order)
		pp = \(#PostProcessing.#ToInt[pp])
		script = \(script)
		dir = \((#QuoteIni & {"in": dir}).out)
		newzbin = \((#QuoteIni & {"in": newzbin}).out)
		priority = \(priority)
		"""
}

#CategoryOut: {
	cat:   #Category
	order: int

	out: (cat & {"order": order}).out
}

categories: [...#Category]
