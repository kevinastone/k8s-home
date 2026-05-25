# regal ignore:directory-package-mismatch
package policy.video.resolution_rules

import rego.v1

# Resolution definitions based on height range
resolutions := {
	"4K": {"min_height": 2000},
	"1080P": {"min_height": 1000},
	"720P": {"min_height": 700},
	"SD": {"min_height": 0},
}

# Match the resolution (the highest resolution where height >= min_height)
resolution(height) := "4K" if {
	height >= resolutions["4K"].min_height
}

resolution(height) := "1080P" if {
	height < resolutions["4K"].min_height
	height >= resolutions["1080P"].min_height
}

resolution(height) := "720P" if {
	height < resolutions["1080P"].min_height
	height >= resolutions["720P"].min_height
}

resolution(height) := "SD" if {
	height < resolutions["720P"].min_height
}
