# regal ignore:opa-fmt
package policy_test

import rego.v1

import data.policy

# Helper to construct a raw input with standard video settings
raw_video(codec, width, height, rate, size, bitrate) := {"media_info": {
	"streams": [{
		"codec_type": "video",
		"codec_name": codec,
		"width": width,
		"height": height,
		"r_frame_rate": rate,
		"bit_rate": sprintf("%d", [bitrate]),
	}],
	"format": {
		"size": sprintf("%d", [size]),
		"bit_rate": sprintf("%d", [bitrate]),
	},
}}

# Helper to construct video with a specific force_transcode flag
raw_video_force(codec, width, height, rate, size, bitrate, force) := object.union(
	raw_video(codec, width, height, rate, size, bitrate),
	{"force_transcode": force},
)

# Helper to construct video + audio stream input
raw_audio(audio_codec) := {"media_info": {
	"streams": [
		{
			"codec_type": "video",
			"codec_name": "h264",
			"width": 1920,
			"height": 1080,
			"r_frame_rate": "24/1",
			"bit_rate": "6000000",
		},
		{
			"codec_type": "audio",
			"codec_name": audio_codec,
		},
	],
	"format": {"size": "100000000"},
}}

# -------------------------------------------------------------
# 1. Forced Transcoding Tests
# -------------------------------------------------------------

test_force_transcode_should_transcode if {
	policy.should_transcode with input as raw_video_force("h264", 1920, 1080, "24/1", 100000000, 1000000, true)
}

test_force_transcode_bypasses_small_size if {
	policy.should_transcode with input as raw_video_force("h264", 1920, 1080, "24/1", 10000, 1000000, true)
}

test_force_transcode_bypasses_efficient_codec if {
	policy.should_transcode with input as raw_video_force("hevc", 1920, 1080, "24/1", 100000000, 1000000, true)
}

test_force_transcode_fails_on_invalid_stream if {
	not policy.should_transcode with input as raw_video_force("h264", 1920, 0, "24/1", 100000000, 1000000, true)
}

# -------------------------------------------------------------
# 2. Eligibility & Thresholds (Resolution Tier Matching)
# -------------------------------------------------------------

# --- 4K (height >= 2000) ---
test_4k_eligible_by_bitrate if {
	policy.should_transcode with input as raw_video_force("h264", 3840, 2160, "24/1", 100000000, 10000000, false)
}

test_4k_eligible_by_bpp if {
	# width*height*fps = 3840 * 2160 * 24 = 199065600
	# bpp = 6000000 / 199065600 = 0.0301 (>= 0.03)
	policy.should_transcode with input as raw_video_force("h264", 3840, 2160, "24/1", 100000000, 6000000, false)
}

test_4k_ineligible if {
	# bpp = 4000000 / 199065600 = 0.0201 (< 0.03)
	not policy.should_transcode with input as raw_video_force("h264", 3840, 2160, "24/1", 100000000, 4000000, false)
}

# --- 1080P (1000 <= height < 2000) ---
test_1080p_eligible_by_bitrate if {
	policy.should_transcode with input as raw_video_force("h264", 1920, 1080, "24/1", 100000000, 4000000, false)
}

test_1080p_eligible_by_bpp if {
	# width*height*fps = 1920 * 1080 * 24 = 49766400
	# bpp = 2000000 / 49766400 = 0.0402 (>= 0.04)
	policy.should_transcode with input as raw_video_force("h264", 1920, 1080, "24/1", 100000000, 2000000, false)
}

test_1080p_ineligible if {
	# bpp = 1500000 / 49766400 = 0.0301 (< 0.04)
	not policy.should_transcode with input as raw_video_force("h264", 1920, 1080, "24/1", 100000000, 1500000, false)
}

# --- 720P (700 <= height < 1000) ---
test_720p_eligible_by_bitrate if {
	policy.should_transcode with input as raw_video_force("h264", 1280, 720, "24/1", 100000000, 2000000, false)
}

test_720p_eligible_by_bpp if {
	# width*height*fps = 1280 * 720 * 24 = 22118400
	# bpp = 1105920 / 22118400 = 0.05 (>= 0.05)
	policy.should_transcode with input as raw_video_force("h264", 1280, 720, "24/1", 100000000, 1105920, false)
}

test_720p_ineligible if {
	# bpp = 884736 / 22118400 = 0.04 (< 0.05)
	not policy.should_transcode with input as raw_video_force("h264", 1280, 720, "24/1", 100000000, 884736, false)
}

# --- SD (height < 700) ---
test_sd_eligible_by_bitrate if {
	policy.should_transcode with input as raw_video_force("h264", 854, 480, "24/1", 100000000, 1500000, false)
}

test_sd_eligible_by_bpp if {
	# width*height*fps = 854 * 480 * 24 = 9838080
	# bpp = 800000 / 9838080 = 0.0813 (>= 0.08)
	policy.should_transcode with input as raw_video_force("h264", 854, 480, "24/1", 100000000, 800000, false)
}

test_sd_ineligible if {
	# bpp = 688665 / 9838080 = 0.07 (< 0.08)
	not policy.should_transcode with input as raw_video_force("h264", 854, 480, "24/1", 100000000, 688665, false)
}

# -------------------------------------------------------------
# 3. Skip Conditions
# -------------------------------------------------------------

test_skip_on_small_size if {
	not policy.should_transcode with input as raw_video_force("h264", 1920, 1080, "24/1", 49000000, 5000000, false)
}

test_skip_on_efficient_codec if {
	not policy.should_transcode with input as raw_video_force("hevc", 1920, 1080, "24/1", 100000000, 5000000, false)
}

test_skip_on_efficient_codec_case_insensitive if {
	not policy.should_transcode with input as raw_video_force("HEVC", 1920, 1080, "24/1", 100000000, 5000000, false)
}

test_skip_on_low_bitrate_and_bpp if {
	inp := {
		"force_transcode": false,
		"media_info": {
			"streams": [{
				"codec_type": "video",
				"codec_name": "vc1",
				"width": 1920,
				"height": 1080,
				"r_frame_rate": "60000/1001",
				"bit_rate": "128018",
			}],
			"format": {
				"size": "67108864",
				"bit_rate": "128018",
			},
		},
	}
	not policy.should_transcode with input as inp
	msg := "resolution tier 1080P requirement failed: BPP 0.0010299802115483539095 < threshold 0.04"
	policy.skip[msg] with input as inp
	policy.skip["resolution tier 1080P requirement failed: bitrate 128018 < threshold 4000000"] with input as inp
}

# -------------------------------------------------------------
# 4. Invalid Streams / Error Conditions
# -------------------------------------------------------------

test_error_on_zero_height if {
	policy.error with input as raw_video("h264", 1920, 0, "24/1", 100000000, 1000000)
}

test_error_on_negative_height if {
	policy.error with input as raw_video("h264", 1920, -10, "24/1", 100000000, 1000000)
}

test_error_on_missing_height if {
	inp := {"media_info": {
		"streams": [{
			"codec_type": "video",
			"codec_name": "h264",
		}],
		"format": {"size": "100000"},
	}}
	policy.error with input as inp
}

test_error_on_unknown_codec if {
	policy.error with input as raw_video("unknown", 1920, 1080, "24/1", 100000000, 1000000)
}

test_error_on_unknown_codec_case_insensitive if {
	policy.error with input as raw_video("UNKNOWN", 1920, 1080, "24/1", 100000000, 1000000)
}

test_error_on_missing_codec if {
	inp := {"media_info": {
		"streams": [{
			"codec_type": "video",
			"height": 1080,
		}],
		"format": {"size": "100000"},
	}}
	policy.error with input as inp
}

test_error_on_missing_input_extension if {
	policy.error["No file extension found in input filepath"] with input as {
		"filepath": "movie",
		"output_filepath": "",
	}
}

test_error_on_missing_output_extension if {
	policy.error["No file extension found in resolved output filepath: custom/path"] with input as {
		"filepath": "movie.mkv",
		"output_filepath": "custom/path",
	}
}

# -------------------------------------------------------------
# 5. Raw ffprobe Input Parsing Tests
# -------------------------------------------------------------

test_raw_input_eligible_h264 if {
	policy.should_transcode with input as {
		"force_transcode": false,
		"media_info": {
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
		},
	}
}

test_raw_input_skip_efficient_codec if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"media_info": {
			"streams": [{
				"codec_type": "video",
				"codec_name": "hevc",
				"width": 1920,
				"height": 1080,
				"r_frame_rate": "24/1",
				"bit_rate": "6000000",
			}],
			"format": {"size": "100000000"},
		},
	}
}

test_raw_input_skip_small_size if {
	not policy.should_transcode with input as {
		"force_transcode": false,
		"media_info": {
			"streams": [{
				"codec_type": "video",
				"codec_name": "h264",
				"width": 1920,
				"height": 1080,
				"r_frame_rate": "24/1",
				"bit_rate": "6000000",
			}],
			"format": {"size": "10000"}, # < 50MB
		},
	}
}

test_raw_input_error_invalid_stream if {
	policy.error with input as {"media_info": {
		"streams": [{
			"codec_type": "video",
			"codec_name": "unknown",
			"width": 0,
			"height": 0,
		}],
		"format": {"size": "100000000"},
	}}
}

test_raw_input_bitrate_fallback_to_format if {
	# No bit_rate on video stream, should fall back to format.bit_rate
	policy.should_transcode with input as {
		"force_transcode": false,
		"media_info": {
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
		},
	}
}

# -------------------------------------------------------------
# 6. Transcoding Parameter Tests
# -------------------------------------------------------------

test_transcode_params_default if {
	policy.transcode_params == {
		"quality": 24,
		"audio_args": [],
	}
}

test_transcode_params_audio_copy if {
	policy.transcode_params.audio_args == ["-c:a", "copy"] with input as raw_audio("aac")
}

test_transcode_params_audio_transcode if {
	policy.transcode_params.audio_args == ["-c:a", "aac", "-b:a", "192k"] with input as raw_audio("flac")
}

test_transcode_params_audio_no_audio if {
	policy.transcode_params.audio_args == [] with input as {"media_info": {
		"streams": [{
			"codec_type": "video",
			"codec_name": "h264",
			"width": 1920,
			"height": 1080,
			"r_frame_rate": "24/1",
			"bit_rate": "6000000",
		}],
		"format": {"size": "100000000"},
	}}
}

test_transcode_params_audio_fallback if {
	policy.transcode_params.audio_args == ["-c:a", "copy"] with input as raw_audio("mp3")
}

# -------------------------------------------------------------
# 7. Output Filepath Resolution Tests
# -------------------------------------------------------------

test_final_output_filepath_default if {
	policy.final_output_filepath == "incoming/movie.mkv" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "",
	}
}

test_final_output_filepath_directory if {
	policy.final_output_filepath == "Output/movie.mkv" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "Output/",
	}
}

test_final_output_filepath_incompatible_container if {
	policy.final_output_filepath == "incoming/movie.mp4" with input as {
		"filepath": "incoming/movie.avi",
		"output_filepath": "",
	}
}

test_final_output_filepath_directory_incompatible_container if {
	policy.final_output_filepath == "Output/movie.mp4" with input as {
		"filepath": "incoming/movie.avi",
		"output_filepath": "Output/",
	}
}

test_final_output_filepath_custom_compatible if {
	policy.final_output_filepath == "custom/path.mp4" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "custom/path.mp4",
	}
}

test_final_output_filepath_custom_incompatible if {
	policy.final_output_filepath == "custom/path.mp4" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "custom/path.wmv",
	}
}

test_final_output_filepath_no_extension if {
	policy.final_output_filepath == "" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "custom/path",
	}
}
