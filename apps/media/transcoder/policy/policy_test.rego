package policy_test

import rego.v1

import data.policy

# -------------------------------------------------------------
# 1. Forced Transcoding Tests
# -------------------------------------------------------------

test_force_transcode_should_transcode if {
	policy.should_transcode with input as {
		"force_transcode": true,
		"height": 1080,
		"codec": "h264",
		"size": 100000000,
		"bpp": 0.01,
		"bitrate": 1000000,
	}
}

test_force_transcode_bypasses_small_size if {
	policy.should_transcode with input as {
		"force_transcode": true,
		"height": 1080,
		"codec": "h264",
		"size": 10000, # < 50MB
		"bpp": 0.01,
		"bitrate": 1000000,
	}
}

test_force_transcode_bypasses_efficient_codec if {
	policy.should_transcode with input as {
		"force_transcode": true,
		"height": 1080,
		"codec": "hevc", # Efficient codec
		"size": 100000000,
		"bpp": 0.01,
		"bitrate": 1000000,
	}
}

test_force_transcode_fails_on_invalid_stream if {
	not policy.should_transcode with input as {
		"force_transcode": true,
		"height": 0, # Invalid height
		"codec": "h264",
		"size": 100000000,
		"bpp": 0.01,
		"bitrate": 1000000,
	}
}

# -------------------------------------------------------------
# 2. Eligibility & Thresholds (Resolution Tier Matching)
# -------------------------------------------------------------

# --- 4K (height >= 2000) ---
test_4k_eligible_by_bitrate if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"height": 2160,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 10000000, # Eligible (>= 10M)
		"bpp": 0.01,
	}
}

test_4k_eligible_by_bpp if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"height": 2160,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 5000000,
		"bpp": 0.03, # Eligible (>= 0.03)
	}
}

test_4k_ineligible if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"height": 2160,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 5000000,
		"bpp": 0.02, # Ineligible
	}
}

# --- 1080P (1000 <= height < 2000) ---
test_1080p_eligible_by_bitrate if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"height": 1080,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 4000000, # Eligible (>= 4M)
		"bpp": 0.01,
	}
}

test_1080p_eligible_by_bpp if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"height": 1080,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 2000000,
		"bpp": 0.04, # Eligible (>= 0.04)
	}
}

test_1080p_ineligible if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"height": 1080,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 2000000,
		"bpp": 0.03, # Ineligible
	}
}

# --- 720P (700 <= height < 1000) ---
test_720p_eligible_by_bitrate if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"height": 720,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 2000000, # Eligible (>= 2M)
		"bpp": 0.01,
	}
}

test_720p_eligible_by_bpp if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"height": 720,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 1000000,
		"bpp": 0.05, # Eligible (>= 0.05)
	}
}

test_720p_ineligible if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"height": 720,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 1000000,
		"bpp": 0.04, # Ineligible
	}
}

# --- SD (height < 700) ---
test_sd_eligible_by_bitrate if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"height": 480,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 1500000, # Eligible (>= 1.5M)
		"bpp": 0.01,
	}
}

test_sd_eligible_by_bpp if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"height": 480,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 1000000,
		"bpp": 0.08, # Eligible (>= 0.08)
	}
}

test_sd_ineligible if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"height": 480,
		"codec": "h264",
		"size": 100000000,
		"bitrate": 1000000,
		"bpp": 0.07, # Ineligible
	}
}

# -------------------------------------------------------------
# 3. Skip Conditions
# -------------------------------------------------------------

test_skip_on_small_size if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"height": 1080,
		"codec": "h264",
		"size": 50000000, # Small size (< 50MB)
		"bitrate": 5000000,
		"bpp": 0.05,
	}
}

test_skip_on_efficient_codec if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"height": 1080,
		"codec": "hevc", # Efficient codec
		"size": 100000000,
		"bitrate": 5000000,
		"bpp": 0.05,
	}
}

test_skip_on_efficient_codec_case_insensitive if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"height": 1080,
		"codec": "HEVC", # Case-insensitive check
		"size": 100000000,
		"bitrate": 5000000,
		"bpp": 0.05,
	}
}

test_skip_on_low_bitrate_and_bpp if {
	not policy.should_transcode with input as {
		"width": 1920,
		"height": 1080,
		"size": 67108864,
		"fps": 59.94005994005994,
		"bitrate": 128018,
		"bpp": 0.001029980211548354,
		"codec": "vc1",
		"force_transcode": false,
	}
	policy.skip["resolution tier 1080P requirement failed: BPP 0.001029980211548354 < threshold 0.04"] with input as {
		"width": 1920,
		"height": 1080,
		"size": 67108864,
		"fps": 59.94005994005994,
		"bitrate": 128018,
		"bpp": 0.001029980211548354,
		"codec": "vc1",
		"force_transcode": false,
	}
	policy.skip["resolution tier 1080P requirement failed: bitrate 128018 < threshold 4000000"] with input as {
		"width": 1920,
		"height": 1080,
		"size": 67108864,
		"fps": 59.94005994005994,
		"bitrate": 128018,
		"bpp": 0.001029980211548354,
		"codec": "vc1",
		"force_transcode": false,
	}
}

# -------------------------------------------------------------
# 4. Invalid Streams / Error Conditions
# -------------------------------------------------------------

test_error_on_zero_height if {
	policy.error with input as {
		"height": 0,
		"codec": "h264",
	}
}

test_error_on_negative_height if {
	policy.error with input as {
		"height": -10,
		"codec": "h264",
	}
}

test_error_on_missing_height if {
	policy.error with input as {"codec": "h264"}
}

test_error_on_unknown_codec if {
	policy.error with input as {
		"height": 1080,
		"codec": "unknown",
	}
}

test_error_on_unknown_codec_case_insensitive if {
	policy.error with input as {
		"height": 1080,
		"codec": "UNKNOWN",
	}
}

test_error_on_missing_codec if {
	policy.error with input as {"height": 1080}
}

# -------------------------------------------------------------
# 5. Raw ffprobe Input Parsing Tests
# -------------------------------------------------------------

test_raw_input_eligible_h264 if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"streams": [{
			"codec_type": "video",
			"codec_name": "h264",
			"width": 1920,
			"height": 1080,
			"r_frame_rate": "24/1",
			"bit_rate": "6000000",
		}],
		"format": {
			"size": "100000000",
			"bit_rate": "6100000",
		},
	}
}

test_raw_input_skip_efficient_codec if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"streams": [{
			"codec_type": "video",
			"codec_name": "hevc",
			"width": 1920,
			"height": 1080,
			"r_frame_rate": "24/1",
			"bit_rate": "6000000",
		}],
		"format": {"size": "100000000"},
	}
}

test_raw_input_skip_small_size if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"streams": [{
			"codec_type": "video",
			"codec_name": "h264",
			"width": 1920,
			"height": 1080,
			"r_frame_rate": "24/1",
			"bit_rate": "6000000",
		}],
		"format": {"size": "10000"}, # < 50MB
	}
}

test_raw_input_error_invalid_stream if {
	policy.error with input as {
		"streams": [{
			"codec_type": "video",
			"codec_name": "unknown",
			"width": 0,
			"height": 0,
		}],
		"format": {"size": "100000000"},
	}
}

test_raw_input_bitrate_fallback_to_format if {
	# No bit_rate on video stream, should fall back to format.bit_rate
	policy.should_transcode with input as {
		"force_transcode": false,
		"streams": [{
			"codec_type": "video",
			"codec_name": "h264",
			"width": 1920,
			"height": 1080,
			"r_frame_rate": "24/1",
		}],
		"format": {
			"size": "100000000",
			"bit_rate": "6000000",
		},
	}
}
