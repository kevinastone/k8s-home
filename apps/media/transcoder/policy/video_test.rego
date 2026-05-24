# regal ignore:directory-package-mismatch
package policy.video_test

import rego.v1

import data.policy.video

test_video_standard if {
	info := video with input as {"media_info": {
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
	}}

	info.width == 1920
	info.height == 1080
	info.codec == "h264"
	info.fps == 24
	info.bitrate == 6000000
	info.size == 100000000
	info.bpp == 6000000 / ((1920 * 1080) * 24)
}

test_fps_fraction_calculation if {
	info := video with input as {"media_info": {
		"streams": [{
			"codec_type": "video",
			"r_frame_rate": "30000/1001",
		}],
		"format": {"size": "0"},
	}}

	info.fps > 29.97
	info.fps < 29.98
}

test_fps_zero_denominator if {
	info := video with input as {"media_info": {
		"streams": [{
			"codec_type": "video",
			"r_frame_rate": "0/0",
		}],
		"format": {"size": "0"},
	}}

	info.fps == 0
}

test_fps_avg_frame_rate_preferred if {
	info := video with input as {"media_info": {
		"streams": [{
			"codec_type": "video",
			"avg_frame_rate": "24/1",
			"r_frame_rate": "90000/1",
		}],
		"format": {"size": "0"},
	}}

	info.fps == 24
}

test_fps_avg_frame_rate_fallback_to_r_frame_rate if {
	info := video with input as {"media_info": {
		"streams": [{
			"codec_type": "video",
			"avg_frame_rate": "0/0",
			"r_frame_rate": "30/1",
		}],
		"format": {"size": "0"},
	}}

	info.fps == 30
}

test_fps_avg_frame_rate_missing_fallback if {
	info := video with input as {"media_info": {
		"streams": [{
			"codec_type": "video",
			"r_frame_rate": "60/1",
		}],
		"format": {"size": "0"},
	}}

	info.fps == 60
}

test_bitrate_fallback_to_format if {
	info := video with input as {"media_info": {
		"streams": [{
			"codec_type": "video",
			"r_frame_rate": "24/1",
		}],
		"format": {
			"size": "0",
			"bit_rate": "5000000",
		},
	}}

	info.bitrate == 5000000
}

test_bitrate_invalid_fallbacks if {
	info := video with input as {"media_info": {
		"streams": [{
			"codec_type": "video",
			"bit_rate": "N/A",
		}],
		"format": {
			"size": "0",
			"bit_rate": "0",
		},
	}}

	info.bitrate == 0
}

test_fallback_defaults_when_empty if {
	info := video with input as {"media_info": {
		"streams": [],
		"format": {"size": "0"},
	}}

	info.width == 0
	info.height == 0
	info.codec == "unknown"
	info.fps == 0
	info.bitrate == 0
	info.bpp == 0
	info.size == 0
}

test_codec_canonicalization_h264 if {
	# h264 aliases should map to h264
	c1 := video.codec with input as {"media_info": {"streams": [{"codec_type": "video", "codec_name": "h264"}]}}
	c1 == "h264"

	c2 := video.codec with input as {"media_info": {"streams": [{"codec_type": "video", "codec_name": "h.264"}]}}
	c2 == "h264"

	c3 := video.codec with input as {"media_info": {"streams": [{"codec_type": "video", "codec_name": "avc"}]}}
	c3 == "h264"

	c4 := video.codec with input as {"media_info": {"streams": [{"codec_type": "video", "codec_name": "avc1"}]}}
	c4 == "h264"
}

test_codec_canonicalization_hevc if {
	# hevc/h265 aliases should map to hevc
	c6 := video.codec with input as {"media_info": {"streams": [{"codec_type": "video", "codec_name": "h265"}]}}
	c6 == "hevc"

	c7 := video.codec with input as {"media_info": {"streams": [{"codec_type": "video", "codec_name": "hevc"}]}}
	c7 == "hevc"
}

test_codec_canonicalization_vc1 if {
	# vc1/vc-1 aliases should map to vc1
	c8 := video.codec with input as {"media_info": {"streams": [{
		"codec_type": "video",
		"codec_name": "vc1",
	}]}}
	c8 == "vc1"

	c9 := video.codec with input as {"media_info": {"streams": [{
		"codec_type": "video",
		"codec_name": "vc-1",
	}]}}
	c9 == "vc1"

	c11 := video.codec with input as {"media_info": {"streams": [{
		"codec_type": "video",
		"codec_name": "wmv3",
	}]}}
	c11 == "vc1"
}

test_codec_canonicalization_other if {
	# vp8 should resolve as-is
	c10 := video.codec with input as {"media_info": {"streams": [{
		"codec_type": "video",
		"codec_name": "vp8",
	}]}}
	c10 == "vp8"

	# Other codecs should remain as-is
	c5 := video.codec with input as {"media_info": {"streams": [{
		"codec_type": "video",
		"codec_name": "mpeg2video",
	}]}}
	c5 == "mpeg2video"
}

test_target_codec_canonicalization if {
	# target_codec canonicalization checks
	t1 := video.target_codec with input as {"target_codec": "h264"}
	t1 == "h264"

	t2 := video.target_codec with input as {"target_codec": "AVC"}
	t2 == "h264"

	t3 := video.target_codec with input as {"target_codec": "h265"}
	t3 == "hevc"

	t4 := video.target_codec with input as {"target_codec": "HEVC"}
	t4 == "hevc"

	t5 := video.target_codec with input as {"target_codec": "vp9"}
	t5 == "vp9"
}

test_is_invalid_stream if {
	# Zero height
	video.is_invalid_stream with input as {"media_info": {
		"streams": [{"codec_type": "video", "codec_name": "h264", "height": 0}],
		"format": {"size": "0"},
	}}

	# Negative height
	video.is_invalid_stream with input as {"media_info": {
		"streams": [{"codec_type": "video", "codec_name": "h264", "height": -10}],
		"format": {"size": "0"},
	}}

	# Missing height
	video.is_invalid_stream with input as {"media_info": {
		"streams": [{"codec_type": "video", "codec_name": "h264"}],
		"format": {"size": "0"},
	}}

	# Unknown codec
	video.is_invalid_stream with input as {"media_info": {
		"streams": [{"codec_type": "video", "codec_name": "unknown", "height": 1080}],
		"format": {"size": "0"},
	}}

	# Missing codec
	video.is_invalid_stream with input as {"media_info": {
		"streams": [{"codec_type": "video", "height": 1080}],
		"format": {"size": "0"},
	}}

	# Valid stream should NOT be invalid
	not video.is_invalid_stream with input as {"media_info": {
		"streams": [{"codec_type": "video", "codec_name": "h264", "height": 1080}],
		"format": {"size": "0"},
	}}
}

test_matching_tier if {
	# 4K tier
	video.matching_tier == "4K" with input as {"media_info": {
		"streams": [{"codec_type": "video", "height": 2160}],
		"format": {"size": "0"},
	}}

	# 1080P tier
	video.matching_tier == "1080P" with input as {"media_info": {
		"streams": [{"codec_type": "video", "height": 1080}],
		"format": {"size": "0"},
	}}

	# 720P tier
	video.matching_tier == "720P" with input as {"media_info": {
		"streams": [{"codec_type": "video", "height": 720}],
		"format": {"size": "0"},
	}}

	# SD tier
	video.matching_tier == "SD" with input as {"media_info": {
		"streams": [{"codec_type": "video", "height": 480}],
		"format": {"size": "0"},
	}}
}

test_scale_height if {
	video.scale_height == 1080 with input as {"media_info": {"streams": [{"codec_type": "video", "height": 2160}]}}

	video.scale_height == 0 with input as {"media_info": {"streams": [{"codec_type": "video", "height": 1080}]}}
}

test_video_encoder_defaults if {
	video.encoder == "software" with input as {}
	video.quality == 24 with input as {}
	video.target_codec == "hevc" with input as {}
}

test_video_encoder_custom if {
	video.encoder == "hardware" with input as {"encoder": "hardware"}
	video.quality == 18 with input as {"quality": 18}
	video.target_codec == "h264" with input as {"target_codec": "h264"}
	video.args == [] with input as {"target_codec": "h264"}

	video.target_codec == "hevc" with input as {"target_codec": "hevc"}
	video.args == ["-c:v", "libx265", "-crf", "24", "-pix_fmt", "yuv420p10le"] with input as {"target_codec": "hevc", "encoder": "software"}

	video.target_codec == "av1" with input as {"target_codec": "av1"}
	video.args == ["-c:v", "libsvtav1", "-crf", "24"] with input as {"target_codec": "av1", "encoder": "software"}
	video.args == ["-c:v", "av1_vaapi", "-q:v", "24", "-vf", "scale_vaapi=format=p010"] with input as {"target_codec": "av1", "encoder": "hardware"}
}

test_video_error_unsupported_target_codec if {
	expected_err := "Unsupported target_codec: h264. Supported codecs are {\"av1\", \"hevc\"}"
	video.error[expected_err] with input as {"target_codec": "h264"}
	count(video.error) == 0 with input as {"target_codec": "HEVC"}
	count(video.error) == 0 with input as {"target_codec": "AV1"}
}

test_video_args_software if {
	video.args == ["-c:v", "libx265", "-crf", "24", "-pix_fmt", "yuv420p10le"] with input as {"encoder": "software"}
	video.pre_input_args == [] with input as {"encoder": "software"}
}

test_video_args_hardware if {
	video.args == ["-c:v", "hevc_vaapi", "-profile:v", "main10", "-q:v", "18", "-vf", "scale_vaapi=format=p010"] with input as {"encoder": "hardware", "quality": 18}
	expected := ["-hwaccel", "vaapi", "-hwaccel_device", "/dev/dri/renderD128", "-hwaccel_output_format", "vaapi"]
	video.pre_input_args == expected with input as {"encoder": "hardware"}
}

test_video_args_software_4k if {
	video.args == ["-c:v", "libx265", "-crf", "24", "-pix_fmt", "yuv420p10le", "-vf", "scale=-2:1080"] with input as {
		"encoder": "software",
		"media_info": {"streams": [{"codec_type": "video", "height": 2160}]},
	}
}

test_video_args_hardware_4k if {
	video.args == ["-c:v", "hevc_vaapi", "-profile:v", "main10", "-q:v", "18", "-vf", "scale_vaapi=w=-2:h=1080:format=p010"] with input as {
		"encoder": "hardware",
		"quality": 18,
		"media_info": {"streams": [{"codec_type": "video", "height": 2160}]},
	}
}

test_video_args_copy_identical_codec if {
	video.args == ["-c:v", "copy"] with input as {
		"target_codec": "h264",
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "h264", "height": 1080}]},
	}
	video.pre_input_args == [] with input as {
		"target_codec": "h264",
		"encoder": "hardware",
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "h264", "height": 1080}]},
	}

	# Also verify identical hevc to hevc copy (which matches both helper rules)
	video.args == ["-c:v", "copy"] with input as {
		"target_codec": "hevc",
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "hevc", "height": 1080}]},
	}
}

test_video_args_copy_equivalent_hevc if {
	video.args == ["-c:v", "copy"] with input as {
		"target_codec": "h265",
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "hevc", "height": 1080}]},
	}
}

test_video_args_copy_equivalent_h265 if {
	video.args == ["-c:v", "copy"] with input as {
		"target_codec": "hevc",
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "h265", "height": 1080}]},
	}
}

test_video_args_no_copy_when_scaling if {
	video.args == ["-c:v", "hevc_vaapi", "-profile:v", "main10", "-q:v", "24", "-vf", "scale_vaapi=w=-2:h=1080:format=p010"] with input as {
		"target_codec": "h265",
		"encoder": "hardware",
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "hevc", "height": 2160}]},
	}
}
