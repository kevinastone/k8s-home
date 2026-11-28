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

	# 2:1 Aspect ratio (any width)
	resolution_rules.is_vr({"display_aspect_ratio": "2:1", "width": 1920})
	resolution_rules.is_vr({"display_aspect_ratio": "2:1", "width": 3840})
	resolution_rules.is_vr({"display_aspect_ratio": "2:1", "width": "2160"})

	# 1:1 Aspect ratio (requires massive width >= 3840)
	resolution_rules.is_vr({"display_aspect_ratio": "1:1", "width": 3840})
	not resolution_rules.is_vr({"display_aspect_ratio": "1:1", "width": 1080})
	not resolution_rules.is_vr({"display_aspect_ratio": "1:1", "width": 3839})

	# Fails if aspect ratio is not 2:1 or 1:1
	not resolution_rules.is_vr({"display_aspect_ratio": "16:9", "width": 3840})
	not resolution_rules.is_vr({"display_aspect_ratio": "2.2:1", "width": 2200})

	# Fallback aspect ratio computation when display_aspect_ratio is missing or invalid
	resolution_rules.is_vr({"width": 3840, "height": 1920}) # computed 2:1
	resolution_rules.is_vr({"width": 1920, "height": 960}) # computed 2:1, small width
	resolution_rules.is_vr({"width": 3840, "height": 3840}) # computed 1:1, massive width
	not resolution_rules.is_vr({"width": 1920, "height": 1920}) # computed 1:1, too small
	resolution_rules.is_vr({"display_aspect_ratio": "N/A", "width": 3840, "height": 1920})
	not resolution_rules.is_vr({"width": 3840, "height": 2160})
}
