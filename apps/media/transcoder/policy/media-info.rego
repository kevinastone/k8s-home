# regal ignore:directory-package-mismatch
package policy.media_info

import rego.v1

# Extracts the first video stream from streams list
video_streams := [s | some s in input.streams; s.codec_type == "video"]

first_video_stream := video_streams[0]

# Individual calculated properties with safe defaults
default width := 0

width := first_video_stream.width

default height := 0

height := first_video_stream.height

default size := 0

size := to_number(input.format.size)

default codec := "unknown"

codec := first_video_stream.codec_name

default fps := 0

fps := f if {
	fps_str := first_video_stream.r_frame_rate
	parts := split(fps_str, "/")
	num := to_number(parts[0])
	den := to_number(parts[1])
	den != 0
	f := num / den
}

default bitrate := 0

bitrate := br if {
	candidates := [
		object.get(first_video_stream, "bit_rate", null),
		object.get(input.format, "bit_rate", null),
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
