package policy

import rego.v1

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
skip contains $"{format_bytes(input.size)} is smaller than {format_bytes(minimum_size)}" if {
	input.size < minimum_size
}
skip contains sprintf("bitrate %v is below threshold %v and BPP %.5f is below threshold %.5f for resolution tier %s", [input.bitrate, t.bitrate, input.bpp, t.bpp, matching_tier]) if {
	not is_resolution_eligible
	t := thresholds[matching_tier]
}

default deny := false

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
	not input.height
}

is_invalid_stream if {
	input.height <= 0
}

is_invalid_stream if {
	not input.codec
}

is_invalid_stream if {
	lower(input.codec) == "unknown"
}

efficient_codecs := {"hevc", "h265", "av1", "vp9"}
minimum_size := 52428800

is_efficient_codec if {
	lower(input.codec) in efficient_codecs
}

# Threshold definitions
thresholds := {
	"4K": {"min_height": 2000, "bpp": 0.03, "bitrate": 10000000},
	"1080P": {"min_height": 1000, "bpp": 0.04, "bitrate": 4000000},
	"720P": {"min_height": 700, "bpp": 0.05, "bitrate": 2000000},
	"SD": {"min_height": 0, "bpp": 0.08, "bitrate": 1500000},
}

# Match the resolution tier (the highest tier where input.height >= min_height)
matching_tier := "4K" if {
	input.height >= thresholds["4K"].min_height
}

matching_tier := "1080P" if {
	input.height < thresholds["4K"].min_height
	input.height >= thresholds["1080P"].min_height
}

matching_tier := "720P" if {
	input.height < thresholds["1080P"].min_height
	input.height >= thresholds["720P"].min_height
}

matching_tier := "SD" if {
	input.height < thresholds["720P"].min_height
}

# Check eligibility
resolution_eligible contains sprintf("BPP %.5f >= threshold %.5f", [input.bpp, t.bpp]) if {
	t := thresholds[matching_tier]
	input.bpp >= t.bpp
}

resolution_eligible contains sprintf("bitrate %v >= threshold %v", [input.bitrate, t.bitrate]) if {
	t := thresholds[matching_tier]
	input.bitrate >= t.bitrate
}

is_resolution_eligible if {
	count(resolution_eligible) > 0
}

format_bytes(bytes) := msg if {
    bytes >= 1073741824 # 1 GB
    gb := bytes / 1073741824
    msg := sprintf("%.2f GB", [gb])
} else := msg if {
    bytes >= 1048576 # 1 MB
    mb := bytes / 1048576
    msg := sprintf("%.2f MB", [mb])
} else := msg if {
    bytes >= 1024 # 1 KB
    kb := bytes / 1024
    msg := sprintf("%.2f KB", [kb])
} else := sprintf("%d Bytes", [bytes])
