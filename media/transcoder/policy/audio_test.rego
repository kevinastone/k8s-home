# regal ignore:opa-fmt
# regal ignore:directory-package-mismatch
package policy.audio_test

import rego.v1

import data.policy.audio

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

test_audio_codec_detection if {
	audio.codec == "aac" with input as raw_audio("aac")
}

test_audio_args_default if {
	audio.args == [] with input as {}
}

test_audio_args_copy if {
	audio.args == ["-c:a", "copy"] with input as raw_audio("aac")
}

test_audio_args_transcode if {
	audio.args == ["-c:a", "aac", "-b:a", "192k"] with input as raw_audio("flac")
}

test_audio_args_no_audio if {
	audio.args == [] with input as {"media_info": {
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

test_audio_args_fallback if {
	audio.args == ["-c:a", "copy"] with input as raw_audio("mp3")
}
