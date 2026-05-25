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

codecs := {
	"h264": {"h264", "h.264", "avc", "avc1"},
	"hevc": {"h265", "hevc"},
	"vc1": {"vc1", "vc-1", "wmv3"},
}

codec_normalization[variant] := canonical if {
	some canonical, variants in codecs
	some variant in variants
}

canonicalize(c) := object.get(codec_normalization, c, c)

default codec := "unknown"

codec := canonicalize(lower(first_stream.codec_name))

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

# Resolution definitions based on height range
resolutions := {
	"4K": {"min_height": 2000},
	"1080P": {"min_height": 1000},
	"720P": {"min_height": 700},
	"SD": {"min_height": 0},
}

# Match the resolution (the highest resolution where height >= min_height)
resolution := "4K" if {
	height >= resolutions["4K"].min_height
}

resolution := "1080P" if {
	height < resolutions["4K"].min_height
	height >= resolutions["1080P"].min_height
}

resolution := "720P" if {
	height < resolutions["1080P"].min_height
	height >= resolutions["720P"].min_height
}

resolution := "SD" if {
	height < resolutions["720P"].min_height
}

default scale_height := 0

scale_height := 1080 if {
	resolution == "4K"
}

default encoder := "software"

encoder := input.encoder

default quality := 24

quality := input.quality

default target_codec := "hevc"

target_codec := canonicalize(lower(input.target_codec))

supported_target_codecs := {"hevc", "av1"}

# Errors
error contains $"Unsupported target_codec: {target_codec}. Supported codecs are {supported_target_codecs}" if {
	not target_codec in supported_target_codecs
}

default args := []

args := array.concat(codec_args, scale_filter) if {
	count(codec_args) > 0
}

default is_equivalent_codec := false

is_equivalent_codec if {
	codec == target_codec
}

is_copying if {
	is_equivalent_codec
	not scale_height > 0
}

default selected_codec := ""

selected_codec := "hevc_vaapi" if {
	encoder == "hardware"
	target_codec == "hevc"
}

selected_codec := "av1_vaapi" if {
	encoder == "hardware"
	target_codec == "av1"
}

selected_codec := "libx265" if {
	encoder == "software"
	target_codec == "hevc"
}

selected_codec := "libsvtav1" if {
	encoder == "software"
	target_codec == "av1"
}

default quality_flag := ""

quality_flag := "-q:v" if {
	encoder == "hardware"
}

quality_flag := "-crf" if {
	encoder == "software"
}

encoding_options contains [quality_flag, $"{quality}"] if {
	quality_flag != ""
}

encoding_options contains ["-pix_fmt", "yuv420p10le"] if {
	selected_codec == "libx265"
}

encoding_options contains ["-profile:v", "main10"] if {
	selected_codec == "hevc_vaapi"
}

# Flattens the set of key-value option tuples into a single deterministic array of arguments for FFmpeg.
encoding_flags := [arg |
	some opt in encoding_options
	some arg in opt
]

codec_args := ["-c:v", "copy"] if {
	is_copying
}

codec_args := array.concat(["-c:v", selected_codec], encoding_flags) if {
	selected_codec != ""
	not is_copying
}

default scale_filter := []

scale_filter := ["-vf", $"scale_vaapi=w=-2:h={scale_height}:format=p010"] if {
	encoder == "hardware"
	not is_copying
	scale_height > 0
}

# Converts the frame format to p010 on the GPU, which is required for 10-bit hardware transcoding.
scale_filter := ["-vf", "scale_vaapi=format=p010"] if {
	encoder == "hardware"
	not is_copying
	not scale_height > 0
}

scale_filter := ["-vf", $"scale=-2:{scale_height}"] if {
	encoder == "software"
	scale_height > 0
}

default pre_input_args := []

pre_input_args := [
	"-hwaccel",
	"vaapi",
	"-hwaccel_device",
	"/dev/dri/renderD128",
	"-hwaccel_output_format",
	"vaapi",
] if {
	encoder == "hardware"
	not is_copying
}
