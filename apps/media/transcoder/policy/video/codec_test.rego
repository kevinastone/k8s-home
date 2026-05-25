# regal ignore:directory-package-mismatch
package policy.video.codec_rules_test

import rego.v1

import data.policy.video.codec_rules

test_codec_canonicalization if {
	codec_rules.canonicalize("h264") == "h264"
	codec_rules.canonicalize("h.264") == "h264"
	codec_rules.canonicalize("avc") == "h264"
	codec_rules.canonicalize("avc1") == "h264"
	codec_rules.canonicalize("h265") == "hevc"
	codec_rules.canonicalize("hevc") == "hevc"
	codec_rules.canonicalize("vc1") == "vc1"
	codec_rules.canonicalize("vc-1") == "vc1"
	codec_rules.canonicalize("wmv3") == "vc1"
	codec_rules.canonicalize("vp8") == "vp8"
	codec_rules.canonicalize("mpeg2video") == "mpeg2video"
}
