#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <video_file>" >&2
    exit 1
fi

FILE="$1"

# Output raw JSON from ffprobe directly
ffprobe -v quiet -print_format json -show_format -show_streams "$FILE"
