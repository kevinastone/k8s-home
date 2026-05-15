#!/bin/bash
# argo-ffmpeg-progress — reads ffmpeg's -progress stream from stdin and
# writes Argo-compatible progress (frame/total) to a progress file.
#
# Usage:  ffmpeg [...] -progress >(argo-ffmpeg-progress <total_frames> <progress_file>) [...]
#
# Arguments:
#   $1  – total frame count from ffprobe
#   $2  – path to write progress updates (e.g. Argo's progress file)

TOTAL_FRAMES="${1:-0}"
PROGRESS_FILE="$2"

while read -r line; do
  if [[ "$line" == frame=* ]]; then
    FRAME="${line#frame=}"
    FRAME="${FRAME// /}"
    if [ -n "$PROGRESS_FILE" ] && [ "$TOTAL_FRAMES" -gt 0 ]; then
      echo "$FRAME/$TOTAL_FRAMES" > "$PROGRESS_FILE"
    fi
  fi
done
