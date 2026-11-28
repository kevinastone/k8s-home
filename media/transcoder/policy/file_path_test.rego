# regal ignore:opa-fmt
# regal ignore:directory-package-mismatch
package policy.file.path_test

import rego.v1

import data.policy.file.path as filepath

test_basename if {
	filepath.basename("path/to/file.txt") == "file.txt"
	filepath.basename("file.txt") == "file.txt"
}

test_extension if {
	filepath.extension("path/to/file.txt") == "txt"
	filepath.extension("file.TXT") == "txt"
}

test_error_on_missing_input_extension if {
	filepath.error["No file extension found in input filepath"] with input as {
		"filepath": "movie",
		"output_filepath": "",
	}
}

test_error_on_missing_output_extension if {
	filepath.error["No file extension found in resolved output filepath: custom/path"] with input as {
		"filepath": "movie.mkv",
		"output_filepath": "custom/path",
	}
}

test_final_output_filepath_default if {
	filepath.final_output_filepath == "incoming/movie.mkv" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "",
	}
}

test_final_output_filepath_directory if {
	filepath.final_output_filepath == "Output/movie.mkv" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "Output/",
	}
}

test_final_output_filepath_incompatible_container if {
	filepath.final_output_filepath == "incoming/movie.mp4" with input as {
		"filepath": "incoming/movie.avi",
		"output_filepath": "",
	}
}

test_final_output_filepath_directory_incompatible_container if {
	filepath.final_output_filepath == "Output/movie.mp4" with input as {
		"filepath": "incoming/movie.avi",
		"output_filepath": "Output/",
	}
}

test_final_output_filepath_custom_compatible if {
	filepath.final_output_filepath == "custom/path.mp4" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "custom/path.mp4",
	}
}

test_final_output_filepath_custom_incompatible if {
	filepath.final_output_filepath == "custom/path.mp4" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "custom/path.wmv",
	}
}

test_final_output_filepath_no_extension if {
	filepath.final_output_filepath == "" with input as {
		"filepath": "incoming/movie.mkv",
		"output_filepath": "custom/path",
	}
}
