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

format_bytes(bytes) := msg if {
	# regal ignore:external-reference
	bytes >= GB

	# regal ignore:external-reference
	val := bytes / GB
	msg := sprintf("%.2f GB", [val])
} else := msg if {
	# regal ignore:external-reference
	bytes >= MB

	# regal ignore:external-reference
	val := bytes / MB
	msg := sprintf("%.2f MB", [val])
} else := msg if {
	# regal ignore:external-reference
	bytes >= KB

	# regal ignore:external-reference
	val := bytes / KB
	msg := sprintf("%.2f KB", [val])
} else := sprintf("%d Bytes", [bytes])
