package sabnzbd

import "strings"

// Helper map to convert boolean values to 0 / 1 in INI output
#BoolToInt: {
	"true":  1
	"false": 0
}

// Action to take on duplicate downloads:
// off     (0) = Do not detect/block duplicates
// discard (1) = Drop/ignore duplicate NZB
// pause   (2) = Pause duplicate NZB in queue
// fail    (3) = Mark duplicate NZB as failed
#DupeAction: {
	#Value: "off" | "discard" | "pause" | "fail"

	#ToInt: {
		"off":     0
		"discard": 1
		"pause":   2
		"fail":    3
	}
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

// Helper to serialize an optional value to its string representation or "None" if unset
#NoneOptional: {
	in?: _
	out: [
		if in != _|_ {"\(in)"},
		"None",
	][0]
}

// Data size string supporting optional binary/decimal unit prefixes (e.g. "500M", "1G", "2.5G", "100K", "0", "-1", "")
// Matches SABnzbd's internal unit parser (K/M/G/T/P).
#DataSize: string & =~"^$|^-1$|^[0-9]+(\\.[0-9]+)?\\s*[kKmMgGtTpP]?[bB]?$"
