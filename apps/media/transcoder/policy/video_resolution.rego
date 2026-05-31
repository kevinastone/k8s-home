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

# Helper to safely extract height as a number
stream_height(stream) := h if {
	is_number(stream.height)
	h := stream.height
} else := h if {
	is_string(stream.height)
	h := to_number(stream.height)
}

# Helper to determine if the stream has a specific aspect ratio
is_aspect_ratio(stream, ratio_str) if {
	stream.display_aspect_ratio == ratio_str
} else if {
	dar := object.get(stream, "display_aspect_ratio", "")
	dar in {"", "N/A", "0:1"}
	w := stream_width(stream)
	h := stream_height(stream)
	h > 0
	match_ratio(w, h, ratio_str)
}

# Match aspect ratio using multiplication to avoid division by zero or float inaccuracies
match_ratio(w, h, "2:1") if {
	w == 2 * h
}

match_ratio(w, h, "1:1") if {
	w == h
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
	is_aspect_ratio(stream, "2:1")
}

is_vr(stream) if {
	is_aspect_ratio(stream, "1:1")
	stream_width(stream) >= 3840
}
