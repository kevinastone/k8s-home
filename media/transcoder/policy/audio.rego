# regal ignore:directory-package-mismatch
package policy.audio

import rego.v1

compatible_codecs := {"aac", "ac3", "eac3", "mp3"}

default codec := "none"

codec := name if {
	audio_streams := [s | some s in input.media_info.streams; s.codec_type == "audio"]
	count(audio_streams) > 0
	name := audio_streams[0].codec_name
}

default is_copying := false

is_copying if {
	codec == "none"
}

is_copying if {
	codec in compatible_codecs
}

default args := ["-c:a", "copy"]

args := [] if {
	codec == "none"
}

args := ["-c:a", "aac", "-b:a", "192k"] if {
	not is_copying
}
