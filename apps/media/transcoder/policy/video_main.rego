# regal ignore:directory-package-mismatch
package policy.video

import rego.v1

import data.policy.video.codec_rules
import data.policy.video.ffmpeg_rules as ffmpeg
import data.policy.video.resolution_rules as video_resolution

# Extracts the first video stream from streams list
streams := [s | some s in input.media_info.streams; s.codec_type == "video"]

first_stream := streams[0]

# Individual calculated properties with safe defaults
default width := 0

width := video_resolution.stream_width(first_stream)

default height := 0

height := video_resolution.stream_height(first_stream)

default size := 0

size := to_number(input.media_info.format.size)

default codec := "unknown"

codec := codec_rules.canonicalize(lower(first_stream.codec_name))

parse_fps_str(fps_str) := f if {
	fps_str != "0/0"
	parts := split(fps_str, "/")
	num := to_number(parts[0])
	den := to_number(parts[1])
	den != 0
	f := num / den
}

parse_fps(stream) := f if {
	fps_str := object.get(stream, "avg_frame_rate", "0/0")
	f := parse_fps_str(fps_str)
} else := f if {
	fps_str := object.get(stream, "r_frame_rate", "0/0")
	f := parse_fps_str(fps_str)
}

default fps := 0

fps := parse_fps(first_stream)

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
	codec == "unknown"
}

# Calculated properties
resolution := video_resolution.resolution(height)

default is_vr := false

is_vr if {
	video_resolution.is_vr(first_stream)
}

# High-level transcoding downscaling policy decisions
default scale_height := 0

scale_height := 1080 if {
	resolution == "4K"
	not is_vr
}

error := ffmpeg.error

is_copying := ffmpeg.is_copying(codec, scale_height)

args := ffmpeg.args(is_copying, scale_height)

pre_input_args := ffmpeg.pre_input_args(is_copying)
