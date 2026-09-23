package sabnzbd

import "strings"

// Helper map to convert boolean values to 0 / 1 in INI output
#BoolToInt: {
	"true":  1
	"false": 0
}

// Helper to format a string value according to Python ConfigObj quoting rules:
// - Quotes if empty, contains commas, comments (#), or has leading/trailing whitespace
// - Uses single quotes if string contains double quotes
// - Uses triple single quotes if string contains both single and double quotes
// - Leaves bare otherwise
#QuoteIni: {
	in: string
	let _hasSingle = strings.Contains(in, "'")
	let _hasDouble = strings.Contains(in, "\"")
	let _needsQuotes = in == "" ||
	strings.Contains(in, ",") ||
	strings.Contains(in, "#") ||
	strings.HasPrefix(in, " ") ||
	strings.HasSuffix(in, " ") ||
	_hasDouble

	let _quote = [
		if _hasSingle && _hasDouble {"'''"},
		if _hasDouble {"'"},
		"\"",
	][0]

	out: [
		if _needsQuotes {"\(_quote)\(in)\(_quote)"},
		in,
	][0]
}
