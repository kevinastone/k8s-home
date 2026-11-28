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

test_scale_height if {
	# 4K non-VR should scale down to 1080
	input_4k_non_vr := {"media_info": {"streams": [{
		"codec_type": "video",
		"height": 2160,
	}]}}
	video.scale_height == 1080 with input as input_4k_non_vr

	# 1080P non-VR should not scale
	input_1080p := {"media_info": {"streams": [{
		"codec_type": "video",
		"height": 1080,
	}]}}
	video.scale_height == 0 with input as input_1080p

	# 4K VR should NOT scale down
	input_4k_vr := {"media_info": {"streams": [{
		"codec_type": "video",
		"height": 2160,
		"side_data_type": "Spherical Mapping",
	}]}}
	video.scale_height == 0 with input as input_4k_vr
}

test_video_integration_args_software if {
	video.args == ["-c:v", "libx265", "-crf", "24", "-pix_fmt", "yuv420p10le"] with input as {
		"encoder": "software",
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "h264", "height": 1080}]},
	}
}

test_video_integration_args_hardware if {
	expected := [
		"-c:v", "hevc_vaapi", "-profile:v", "main10", "-q:v", "18",
		"-vf", "scale_vaapi=format=p010",
	]
	video.args == expected with input as {
		"encoder": "hardware",
		"quality": 18,
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "h264", "height": 1080}]},
	}
}

test_video_args_copy_identical_codec if {
	video.args == ["-c:v", "copy"] with input as {
		"target_codec": "hevc",
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "hevc", "height": 1080}]},
	}
	video.pre_input_args == [] with input as {
		"target_codec": "hevc",
		"encoder": "hardware",
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
	expected := [
		"-c:v", "hevc_vaapi", "-profile:v", "main10", "-q:v", "24",
		"-vf", "scale_vaapi=w=-2:h=1080:format=p010",
	]
	video.args == expected with input as {
		"target_codec": "h265",
		"encoder": "hardware",
		"media_info": {"streams": [{"codec_type": "video", "codec_name": "hevc", "height": 2160}]},
	}
}

test_video_is_vr if {
	# Standard is not VR
	input_standard := {"media_info": {"streams": [{
		"codec_type": "video",
		"codec_name": "h264",
		"width": 1920,
		"height": 1080,
	}]}}
	not video.is_vr with input as input_standard

	# VR by side data
	input_vr_side_data := {"media_info": {"streams": [{
		"codec_type": "video",
		"codec_name": "h264",
		"side_data_type": "Spherical Mapping",
	}]}}
	video.is_vr with input as input_vr_side_data
}
