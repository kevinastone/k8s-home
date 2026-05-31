# regal ignore:directory-package-mismatch
package policy.video.resolution_rules_test

import rego.v1

import data.policy.video.resolution_rules

test_resolution if {
	resolution_rules.resolution(2160) == "4K"
	resolution_rules.resolution(1080) == "1080P"
	resolution_rules.resolution(720) == "720P"
	resolution_rules.resolution(480) == "SD"
}

test_is_vr if {
	# Standard video
	not resolution_rules.is_vr({"width": 1920, "height": 1080})

	# Explicit side-data string metadata
	resolution_rules.is_vr({"side_data_type": "Spherical Mapping"})
	resolution_rules.is_vr({"side_data_type": "Spherical"})

	# Explicit side-data list metadata
	resolution_rules.is_vr({"side_data_list": [{"side_data_type": "Spherical Mapping"}]})

	# 2:1 Aspect ratio with massive width (VR 360)
	resolution_rules.is_vr({"display_aspect_ratio": "2:1", "width": 3840})
	resolution_rules.is_vr({"display_aspect_ratio": "2:1", "width": 4096})

	# As a string width
	resolution_rules.is_vr({"display_aspect_ratio": "2:1", "width": "3840"})

	# 1:1 Aspect ratio with massive width (Stereo VR)
	resolution_rules.is_vr({"display_aspect_ratio": "1:1", "width": 3840})

	# Fails if width is too small
	not resolution_rules.is_vr({"display_aspect_ratio": "2:1", "width": 1920})
	not resolution_rules.is_vr({"display_aspect_ratio": "1:1", "width": 3839})

	# Fails if aspect ratio is not 2:1 or 1:1 even if width is large
	not resolution_rules.is_vr({"display_aspect_ratio": "16:9", "width": 3840})
}
