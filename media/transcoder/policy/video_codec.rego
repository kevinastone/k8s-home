# regal ignore:directory-package-mismatch
package policy.video.codec_rules

import rego.v1

codecs := {
	"h264": {"h264", "h.264", "avc", "avc1"},
	"hevc": {"h265", "hevc"},
	"vc1": {"vc1", "vc-1", "wmv3"},
}

codec_normalization[variant] := canonical if {
	some canonical, variants in codecs
	some variant in variants
}

canonicalize(c) := object.get(codec_normalization, c, c)
