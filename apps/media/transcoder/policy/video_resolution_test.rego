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
