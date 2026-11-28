package policy

import rego.v1

import data.policy.audio
import data.policy.file.path as filepath
import data.policy.file.size as file_size
import data.policy.video

error contains "No valid video stream found" if {
	video.is_invalid_stream
}

error contains msg if {
	some msg in filepath.error
}

error contains msg if {
	some msg in video.error
}

skip contains "already efficiently encoded" if {
	is_efficient_codec
}

skip contains $"{file_size.format_bytes(video.size)} is smaller than {file_size.format_bytes(minimum_size)}" if {
	video.size < minimum_size
}

skip contains "both video and audio can be copied without transcoding" if {
	video.is_copying
	audio.is_copying
}

deny contains $"resolution tier {video.resolution} requirement failed: {msg}" if {
	not is_resolution_eligible
	some msg in resolution_ineligible
}

deny contains "VR video is not supported" if {
	video.is_vr
}

# METADATA
# entrypoint: true
default should_transcode := false

should_transcode if {
	count(error) == 0
	input.force_transcode
}

should_transcode if {
	count(error) == 0
	count(skip) == 0
	count(deny) == 0
}

transcode_params := {
	"audio_args": audio.args,
	"video_args": video.args,
	"pre_input_args": video.pre_input_args,
}

reasons := (error | skip) | deny

default final_output_filepath := ""

final_output_filepath := filepath.final_output_filepath

# -------------------------------------------------------------
# Helper Rules & Definitions
# -------------------------------------------------------------

efficient_codecs := {"hevc", "h265", "av1", "vp9"}
minimum_size := 500 * file_size.MB

is_efficient_codec if {
	video.codec in efficient_codecs
}

legacy_codecs := {"h264", "vc1", "vp8"}

legacy_thresholds := {
	"4K": {"bpp": 0.03, "bitrate": 10000000},
	"1080P": {"bpp": 0.04, "bitrate": 4000000},
	"720P": {"bpp": 0.05, "bitrate": 2000000},
	"SD": {"bpp": 0.08, "bitrate": 1500000},
}

# Failed requirements
resolution_ineligible contains $"BPP {video.bpp} < threshold {t.bpp}" if {
	video.codec in legacy_codecs
	t := legacy_thresholds[video.resolution]
	video.bpp < t.bpp
}

resolution_ineligible contains $"bitrate {video.bitrate} < threshold {t.bitrate}" if {
	video.codec in legacy_codecs
	t := legacy_thresholds[video.resolution]
	video.bitrate < t.bitrate
}

is_resolution_eligible if {
	count(resolution_ineligible) < 2
}
