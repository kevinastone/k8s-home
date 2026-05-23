# regal ignore:directory-package-mismatch
package policy.video

import rego.v1

# Extracts the first video stream from streams list
streams := [s | some s in input.media_info.streams; s.codec_type == "video"]

first_stream := streams[0]

# Individual calculated properties with safe defaults
default width := 0

width := first_stream.width

default height := 0

height := first_stream.height

default size := 0

size := to_number(input.media_info.format.size)

default codec := "unknown"

codec := first_stream.codec_name

default fps := 0

fps := f if {
	fps_str := first_stream.r_frame_rate
	parts := split(fps_str, "/")
	num := to_number(parts[0])
	den := to_number(parts[1])
	den != 0
	f := num / den
}

default bitrate := 0

bitrate := br if {
	candidates := [
		object.get(first_stream, "bit_rate", null),
		object.get(input.media_info.format, "bit_rate", null),
	]
	valid_rates := [to_number(c) | some c in candidates; c != null; c != "N/A"; to_number(c) > 1]
	count(valid_rates) > 0
	br := valid_rates[0]
}

default bpp := 0

bpp := val if {
	width != 0
	height != 0
	fps != 0
	val := bitrate / ((width * height) * fps)
}

default is_invalid_stream := false

is_invalid_stream if {
	height <= 0
}

is_invalid_stream if {
	lower(codec) == "unknown"
}

# Tier definitions based on height range
tiers := {
	"4K": {"min_height": 2000},
	"1080P": {"min_height": 1000},
	"720P": {"min_height": 700},
	"SD": {"min_height": 0},
}

# Match the resolution tier (the highest tier where height >= min_height)
matching_tier := "4K" if {
	height >= tiers["4K"].min_height
}

matching_tier := "1080P" if {
	height < tiers["4K"].min_height
	height >= tiers["1080P"].min_height
}

matching_tier := "720P" if {
	height < tiers["1080P"].min_height
	height >= tiers["720P"].min_height
}

matching_tier := "SD" if {
	height < tiers["720P"].min_height
}
