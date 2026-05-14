#!/bin/bash
set -o pipefail

# These are expected to be passed as environment variables
# FILEPATH
# OUTPUT_FILEPATH
# QUALITY

if [ -z "$FILEPATH" ]; then
  echo "Error: No filepath provided."
  exit 1
fi

echo "Received transcoding request for: $FILEPATH"

# Handle both relative paths (MQTT) and absolute paths (File Watcher)
if [[ "$FILEPATH" == /media/* ]]; then
  INPUT_FILE="$FILEPATH"
else
  INPUT_FILE="/media/$FILEPATH"
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File $INPUT_FILE not found on PVC."
  exit 1
fi

if [ -z "$OUTPUT_FILEPATH" ]; then
  OUTPUT_FILE="$INPUT_FILE"
else
  if [[ "$OUTPUT_FILEPATH" == /media/* ]]; then
    OUTPUT_FILE="$OUTPUT_FILEPATH"
  else
    OUTPUT_FILE="/media/$OUTPUT_FILEPATH"
  fi

  # Ensure output directory exists
  mkdir -p "$(dirname "$OUTPUT_FILE")"

  # If output path is a directory (ends in / or exists as dir), append filename
  if [[ "$OUTPUT_FILE" == */ ]] || [ -d "$OUTPUT_FILE" ]; then
    mkdir -p "$OUTPUT_FILE"
    OUTPUT_FILE="${OUTPUT_FILE%/}/$(basename "$INPUT_FILE")"
  fi
fi
TEMP_OUTPUT_FILE="/temp/$(basename "$OUTPUT_FILE")"

# Pick the highest render device available (e.g., renderD129 over renderD128)
# This commonly bypasses ASPEED BMC display adapters in homelab servers.
RENDER_DEVICE=$(ls /dev/dri/renderD* 2>/dev/null | sort -r | head -n 1)
if [ -z "$RENDER_DEVICE" ]; then
  RENDER_DEVICE="/dev/dri/renderD128"
fi

TOTAL_FRAMES=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nokey=1:noprint_wrappers=1 "$INPUT_FILE" 2>/dev/null)
if [ -z "$TOTAL_FRAMES" ] || [ "$TOTAL_FRAMES" == "N/A" ]; then
  TOTAL_FRAMES=0
fi

echo "Selected render device: $RENDER_DEVICE"
echo "Total frames: $TOTAL_FRAMES"

echo "Starting ffmpeg transcode: $INPUT_FILE -> $TEMP_OUTPUT_FILE (temp)"
ffmpeg \
  -hide_banner \
  -nostdin \
  -y \
  -hwaccel vaapi \
  -hwaccel_device "$RENDER_DEVICE" \
  -hwaccel_output_format vaapi \
  -i "$INPUT_FILE" \
  -c:v hevc_vaapi \
  -q:v "$QUALITY" \
  -c:a copy \
  -progress /dev/stdout \
  -stats_period 5 \
  -nostats \
  "$TEMP_OUTPUT_FILE" 2>&1 | while read -r line; do
    echo "$line"
    if [[ "$line" == frame=* ]]; then
      FRAME="${line#frame=}"
      FRAME="${FRAME// /}"
      if [ -n "$ARGO_PROGRESS_FILE" ] && [ "$TOTAL_FRAMES" -gt 0 ]; then
        echo "$FRAME/$TOTAL_FRAMES" > "$ARGO_PROGRESS_FILE"
      fi
    fi
  done

if [ $? -eq 0 ]; then
  echo "Transcode completed successfully! Moving file to destination..."
  mkdir -p $(dirname "$OUTPUT_FILE")
  mv "$TEMP_OUTPUT_FILE" "$OUTPUT_FILE"
  echo "$OUTPUT_FILE" > /tmp/transcoded_filepath.txt
else
  echo "Transcode failed."
  exit 1
fi
