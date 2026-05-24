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

test_video_encoder_defaults if {
	video.encoder == "software" with input as {}
	video.quality == 24 with input as {}
}

test_video_encoder_custom if {
	video.encoder == "hardware" with input as {"encoder": "hardware"}
	video.quality == 18 with input as {"quality": 18}
}

test_video_args_software if {
	video.args == ["-c:v", "libx265", "-crf", "24"] with input as {"encoder": "software"}
	video.pre_input_args == [] with input as {"encoder": "software"}
}

test_video_args_hardware if {
	video.args == ["-c:v", "hevc_vaapi", "-q:v", "18"] with input as {"encoder": "hardware", "quality": 18}
	expected := ["-hwaccel", "vaapi", "-hwaccel_device", "/dev/dri/renderD128", "-hwaccel_output_format", "vaapi"]
	video.pre_input_args == expected with input as {"encoder": "hardware"}
}

test_video_args_software_4k if {
	video.args == ["-c:v", "libx265", "-crf", "24", "-vf", "scale=-2:1080"] with input as {
		"encoder": "software",
		"media_info": {"streams": [{"codec_type": "video", "height": 2160}]},
	}
}

test_video_args_hardware_4k if {
	video.args == ["-c:v", "hevc_vaapi", "-q:v", "18", "-vf", "scale_vaapi=w=-2:h=1080"] with input as {
		"encoder": "hardware",
		"quality": 18,
		"media_info": {"streams": [{"codec_type": "video", "height": 2160}]},
	}
}
