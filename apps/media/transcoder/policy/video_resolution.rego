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

# Helper to safely extract width as a number
stream_width(stream) := w if {
	is_number(stream.width)
	w := stream.width
} else := w if {
	is_string(stream.width)
	w := to_number(stream.width)
}

# Determine if a video stream is VR
default is_vr(_) := false

is_vr(stream) if {
	is_string(stream.side_data_type)
	contains(stream.side_data_type, "Spherical")
}

is_vr(stream) if {
	is_array(stream.side_data_list)
	some side_data in stream.side_data_list
	is_string(side_data.side_data_type)
	contains(side_data.side_data_type, "Spherical")
}

is_vr(stream) if {
	stream.display_aspect_ratio == "2:1"
	stream_width(stream) >= 3840
}

is_vr(stream) if {
	stream.display_aspect_ratio == "1:1"
	stream_width(stream) >= 3840
}
