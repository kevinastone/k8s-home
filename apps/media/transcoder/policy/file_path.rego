# regal ignore:directory-package-mismatch
package policy.file.path

import rego.v1

# Errors
error contains "No file extension found in input filepath" if {
	input.filepath != ""
	not contains(basename(input.filepath), ".")
}

error contains $"No file extension found in resolved output filepath: {dir_resolved_output}" if {
	input.filepath != ""
	not contains(basename(dir_resolved_output), ".")
}

# Helpers
basename(path) := parts[count(parts) - 1] if {
	parts := split(path, "/")
}

extension(path) := ext if {
	name := basename(path)
	contains(name, ".")
	parts := split(name, ".")
	ext := lower(parts[count(parts) - 1])
}

initial_output := input.output_filepath if {
	input.output_filepath != ""
} else := input.filepath

dir_resolved_output := concat("", [initial_output, basename(input.filepath)]) if {
	endswith(initial_output, "/")
} else := initial_output

default final_output_filepath := ""

final_output_filepath := resolved_output_path if {
	input.filepath
}

resolved_output_path := dir_resolved_output if {
	extension(dir_resolved_output) in {"mp4", "mkv"}
} else := regex.replace(dir_resolved_output, `\.[^.]+$`, ".mp4") if {
	contains(basename(dir_resolved_output), ".")
}
