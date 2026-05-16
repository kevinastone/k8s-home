#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <video_file>" >&2
    exit 1
fi

FILE="$1"

# Verify jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first." >&2
    exit 1
fi


# Output raw JSON from ffprobe and pipe it into jq
ffprobe -v quiet -print_format json -show_format -show_streams "$FILE" | jq -r '
  def calc_fps:
    split("/") |
    (.[0] | tonumber) as $num |
    (.[1] | tonumber) as $den |
    if $den == 0 then 0 else $num / $den end;

  first(.streams[] | select(.codec_type == "video")) as $v
  | $v.width as $w
  | $v.height as $h
  | $v.codec_name as $codec
  | ($v.r_frame_rate | calc_fps) as $fps
  | (([$v.bit_rate, .format.bit_rate] | map(select(. != null and . != "N/A" and (tonumber > 1))) | first) // 0 | tonumber) as $br
  | .format.size | tonumber as $size
  | ($br / ($w * $h * $fps)) as $bpp
  | {
      width: $w,
      height: $h,
      size: $size,
      fps: $fps,
      bitrate: $br,
      bpp: $bpp,
      codec: $codec
    }
'
