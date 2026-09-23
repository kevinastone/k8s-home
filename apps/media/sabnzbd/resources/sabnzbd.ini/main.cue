package sabnzbd

import "strings"

out: """
	\(misc.out)

	[categories]
	\(strings.Join([for i, cat in categories {(#CategoryOut & {"cat": cat, "order": i}).out}], "\n\n"))

	[servers]
	\(strings.Join([for s in servers {s.out}], "\n\n"))

	[rss]
	\(strings.Join([for show in shows {show.out}], "\n\n"))
	"""
