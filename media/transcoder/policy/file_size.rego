# regal ignore:directory-package-mismatch
package policy.file.size

import rego.v1

# regal ignore:prefer-snake-case
B := 1

# regal ignore:prefer-snake-case
KB := 1024 * B

# regal ignore:prefer-snake-case
MB := 1024 * KB

# regal ignore:prefer-snake-case
GB := 1024 * MB

# regal ignore:prefer-snake-case
TB := 1024 * GB

format_val(val) := $"{floor(val)}.00" if {
	floor(val) == val
} else := sprintf("%.2f", [val])

format_bytes(bytes) := msg if {
	# regal ignore:external-reference
	bytes >= GB

	# regal ignore:external-reference
	val := bytes / GB
	msg := $"{format_val(val)} GB"
} else := msg if {
	# regal ignore:external-reference
	bytes >= MB

	# regal ignore:external-reference
	val := bytes / MB
	msg := $"{format_val(val)} MB"
} else := msg if {
	# regal ignore:external-reference
	bytes >= KB

	# regal ignore:external-reference
	val := bytes / KB
	msg := $"{format_val(val)} KB"
} else := $"{bytes} Bytes"
