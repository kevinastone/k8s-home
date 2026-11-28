# regal ignore:directory-package-mismatch,prefer-snake-case,opa-fmt
package policy.file.size_test

import rego.v1

import data.policy.file.size as file_size

test_byte_sizes if {
	file_size.B == 1
	file_size.KB == 1024
	file_size.MB == 1048576
	file_size.GB == 1073741824
	file_size.TB == 1099511627776
}

test_format_bytes_bytes if {
	file_size.format_bytes(500) == "500 Bytes"
	file_size.format_bytes(0) == "0 Bytes"
}

test_format_bytes_kb if {
	file_size.format_bytes(1500) == "1.46 KB"
	file_size.format_bytes(2500) == "2.44 KB"
}

test_format_bytes_mb if {
	file_size.format_bytes(1500000) == "1.43 MB"
	file_size.format_bytes(3000000) == "2.86 MB"
}

test_format_bytes_gb if {
	file_size.format_bytes(1500000000) == "1.40 GB"
	file_size.format_bytes(4000000000) == "3.73 GB"
}

test_format_bytes_exact_multiples if {
	file_size.format_bytes(500 * file_size.MB) == "500.00 MB"
	file_size.format_bytes(2 * file_size.GB) == "2.00 GB"
	file_size.format_bytes(10 * file_size.KB) == "10.00 KB"
}
