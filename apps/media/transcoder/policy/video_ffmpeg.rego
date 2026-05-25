# regal ignore:directory-package-mismatch
package policy.video.ffmpeg_rules

import rego.v1

import data.policy.video.codec_rules as codec

default encoder := "software"

encoder := input.encoder

default quality := 24

quality := input.quality

default target_codec := "hevc"

target_codec := codec.canonicalize(lower(input.target_codec))

supported_target_codecs := {"hevc", "av1"}

# Match target codec validations
error contains $"Unsupported target_codec: {target_codec}. Supported codecs are {supported_target_codecs}" if {
	not target_codec in supported_target_codecs
}

# Source-codec inspection rules (returning boolean true/false)

is_equivalent_codec(codec_name) if {
	codec_name == target_codec
} else := false

is_copying(codec_name, scale_height) if {
	is_equivalent_codec(codec_name)
	not scale_height > 0
} else := false

# FFmpeg encoding arguments compilation functions

default selected_codec := ""

selected_codec := "hevc_vaapi" if {
	encoder == "hardware"
	target_codec == "hevc"
} else := "av1_vaapi" if {
	encoder == "hardware"
	target_codec == "av1"
} else := "libx265" if {
	encoder == "software"
	target_codec == "hevc"
} else := "libsvtav1" if {
	encoder == "software"
	target_codec == "av1"
}

default quality_flag := ""

quality_flag := "-q:v" if {
	encoder == "hardware"
} else := "-crf" if {
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

codec_args(is_copying_bool) := ["-c:v", "copy"] if {
	is_copying_bool == true
} else := array.concat(["-c:v", selected_codec], encoding_flags) if {
	selected_codec != ""
	is_copying_bool == false
} else := []

scale_filter(is_copying_bool, scale_height) := ["-vf", $"scale_vaapi=w=-2:h={scale_height}:format=p010"] if {
	encoder == "hardware"
	is_copying_bool == false
	scale_height > 0
} else := ["-vf", "scale_vaapi=format=p010"] if {
	encoder == "hardware"
	is_copying_bool == false
	not scale_height > 0
} else := ["-vf", $"scale=-2:{scale_height}"] if {
	encoder == "software"
	scale_height > 0
} else := []

pre_input_args(is_copying_bool) := [
	"-hwaccel",
	"vaapi",
	"-hwaccel_device",
	"/dev/dri/renderD128",
	"-hwaccel_output_format",
	"vaapi",
] if {
	encoder == "hardware"
	is_copying_bool == false
} else := []

args(is_copying_bool, scale_height) := array.concat(ca, sf) if {
	ca := codec_args(is_copying_bool)
	count(ca) > 0
	sf := scale_filter(is_copying_bool, scale_height)
} else := []
