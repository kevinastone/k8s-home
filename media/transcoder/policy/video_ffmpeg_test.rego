# regal ignore:directory-package-mismatch
package policy.video.ffmpeg_rules_test

import rego.v1

import data.policy.video.ffmpeg_rules as ffmpeg

test_ffmpeg_config_defaults if {
	ffmpeg.encoder == "software" with input as {}
	ffmpeg.quality == 24 with input as {}
	ffmpeg.target_codec == "hevc" with input as {}
}

test_ffmpeg_config_custom if {
	ffmpeg.encoder == "hardware" with input as {"encoder": "hardware"}
	ffmpeg.quality == 18 with input as {"quality": 18}
	ffmpeg.target_codec == "h264" with input as {"target_codec": "h264"}
	ffmpeg.target_codec == "hevc" with input as {"target_codec": "hevc"}
	ffmpeg.target_codec == "av1" with input as {"target_codec": "av1"}
}

test_ffmpeg_error_unsupported_target_codec if {
	expected_err := "Unsupported target_codec: h264. Supported codecs are {\"av1\", \"hevc\"}"
	ffmpeg.error[expected_err] with input as {"target_codec": "h264"}
	count(ffmpeg.error) == 0 with input as {"target_codec": "HEVC"}
	count(ffmpeg.error) == 0 with input as {"target_codec": "AV1"}
}

test_ffmpeg_is_equivalent_codec if {
	ffmpeg.is_equivalent_codec("hevc") == true with input as {"target_codec": "hevc"}
	ffmpeg.is_equivalent_codec("av1") == false with input as {"target_codec": "hevc"}
}

test_ffmpeg_is_copying if {
	ffmpeg.is_copying("hevc", 0) == true with input as {"target_codec": "hevc"}
	ffmpeg.is_copying("hevc", 1080) == false with input as {"target_codec": "hevc"}
	ffmpeg.is_copying("av1", 0) == false with input as {"target_codec": "hevc"}
}

test_ffmpeg_args_software if {
	expected := ["-c:v", "libx265", "-crf", "24", "-pix_fmt", "yuv420p10le"]
	ffmpeg.args(false, 0) == expected with input as {"encoder": "software"}
	ffmpeg.pre_input_args(false) == [] with input as {"encoder": "software"}
}

test_ffmpeg_args_hardware if {
	expected_args := [
		"-c:v", "hevc_vaapi", "-profile:v", "main10", "-q:v", "18",
		"-vf", "scale_vaapi=format=p010",
	]
	ffmpeg.args(false, 0) == expected_args with input as {"encoder": "hardware", "quality": 18}
	expected := ["-hwaccel", "vaapi", "-hwaccel_device", "/dev/dri/renderD128", "-hwaccel_output_format", "vaapi"]
	ffmpeg.pre_input_args(false) == expected with input as {"encoder": "hardware"}
}

test_ffmpeg_args_software_4k if {
	expected := ["-c:v", "libx265", "-crf", "24", "-pix_fmt", "yuv420p10le", "-vf", "scale=-2:1080"]
	ffmpeg.args(false, 1080) == expected with input as {"encoder": "software"}
}

test_ffmpeg_args_hardware_4k if {
	expected := [
		"-c:v", "hevc_vaapi", "-profile:v", "main10", "-q:v", "18",
		"-vf", "scale_vaapi=w=-2:h=1080:format=p010",
	]
	ffmpeg.args(false, 1080) == expected with input as {"encoder": "hardware", "quality": 18}
}

test_ffmpeg_args_copy_identical_codec if {
	ffmpeg.args(true, 0) == ["-c:v", "copy"] with input as {"target_codec": "hevc"}
	ffmpeg.pre_input_args(true) == [] with input as {"encoder": "hardware"}
}
