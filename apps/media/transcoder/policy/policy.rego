package policy

import rego.v1

import data.policy.media_info

# Unified media helper to support dual-mode inputs
media := media_info.info if {
	input.streams
} else := input

error contains "No valid video stream found" if {
	is_invalid_stream
}

default allow := false

allow if {
	is_resolution_eligible
}

skip contains "already efficiently encoded" if {
	is_efficient_codec
}

skip contains $"{format_bytes(media.size)} is smaller than {format_bytes(minimum_size)}" if {
	media.size < minimum_size
}

skip contains $"resolution tier {matching_tier} requirement failed: {msg}" if {
	not is_resolution_eligible
	some msg in resolution_ineligible
}

default deny := false

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
	not deny
	allow
}

reasons := error | skip
reason := concat("\n", reasons)

# -------------------------------------------------------------
# Helper Rules & Definitions
# -------------------------------------------------------------

is_invalid_stream if {
	not media.height
}

is_invalid_stream if {
	media.height <= 0
}

is_invalid_stream if {
	not media.codec
}

is_invalid_stream if {
	lower(media.codec) == "unknown"
}

efficient_codecs := {"hevc", "h265", "av1", "vp9"}
minimum_size := 52428800

is_efficient_codec if {
	lower(media.codec) in efficient_codecs
}

# Threshold definitions
thresholds := {
	"4K": {"min_height": 2000, "bpp": 0.03, "bitrate": 10000000},
	"1080P": {"min_height": 1000, "bpp": 0.04, "bitrate": 4000000},
	"720P": {"min_height": 700, "bpp": 0.05, "bitrate": 2000000},
	"SD": {"min_height": 0, "bpp": 0.08, "bitrate": 1500000},
}

# Match the resolution tier (the highest tier where media.height >= min_height)
matching_tier := "4K" if {
	media.height >= thresholds["4K"].min_height
}

matching_tier := "1080P" if {
	media.height < thresholds["4K"].min_height
	media.height >= thresholds["1080P"].min_height
}

matching_tier := "720P" if {
	media.height < thresholds["1080P"].min_height
	media.height >= thresholds["720P"].min_height
}

matching_tier := "SD" if {
	media.height < thresholds["720P"].min_height
}

# Failed requirements
resolution_ineligible contains $"BPP {media.bpp} < threshold {t.bpp}" if {
	t := thresholds[matching_tier]
	media.bpp < t.bpp
}

resolution_ineligible contains $"bitrate {media.bitrate} < threshold {t.bitrate}" if {
	t := thresholds[matching_tier]
	media.bitrate < t.bitrate
}

is_resolution_eligible if {
	count(resolution_ineligible) < 2
}

format_bytes(bytes) := msg if {
	bytes >= 1073741824 # 1 GB
	gb := bytes / 1073741824.0
	msg := sprintf("%.2f GB", [gb])
} else := msg if {
	bytes >= 1048576 # 1 MB
	mb := bytes / 1048576.0
	msg := sprintf("%.2f MB", [mb])
} else := msg if {
	bytes >= 1024 # 1 KB
	kb := bytes / 1024.0
	msg := sprintf("%.2f KB", [kb])
} else := sprintf("%d Bytes", [bytes])
