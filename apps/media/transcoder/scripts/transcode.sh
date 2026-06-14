#!/bin/bash
set -euo pipefail

# These are expected to be passed as environment variables
# FILEPATH
# OUTPUT_FILEPATH
# TRANSCODE_PARAMS (JSON string containing parameters, e.g. video_args, pre_input_args, audio_args)

if [ -z "${FILEPATH:-}" ]; then
  echo "Error: No filepath provided." >&2
  exit 1
fi

if [ -z "${OUTPUT_FILEPATH:-}" ]; then
  echo "Error: OUTPUT_FILEPATH is not resolved." >&2
  exit 1
fi

if [ -z "${TRANSCODE_PARAMS:-}" ] || ! echo "$TRANSCODE_PARAMS" | jq empty 2>/dev/null; then
  echo "Error: TRANSCODE_PARAMS is missing or invalid JSON." >&2
  exit 1
fi

echo "Received transcoding request for: $FILEPATH"

# Normalize input filepath (always relative to /media)
INPUT_FILE="/media/${FILEPATH#/}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File $INPUT_FILE not found on PVC." >&2
  exit 1
fi

OUTPUT_FILE="/media/${OUTPUT_FILEPATH#/}"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_OUTPUT_FILE="/temp/$(basename "$OUTPUT_FILE")"

TOTAL_DURATION=$(ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 "$INPUT_FILE" 2>/dev/null)
if [ -z "$TOTAL_DURATION" ] || [ "$TOTAL_DURATION" = "N/A" ]; then
  TOTAL_DURATION=0
fi

echo "Total duration (s): $TOTAL_DURATION"
echo "Starting ffmpeg transcode: $INPUT_FILE -> $TEMP_OUTPUT_FILE (temp)"

# Load arguments directly from OPA policy evaluation output
readarray -t PRE_INPUT_ARGS < <(echo "$TRANSCODE_PARAMS" | jq -r '.pre_input_args[] // empty')
readarray -t VIDEO_ARGS < <(echo "$TRANSCODE_PARAMS" | jq -r '.video_args[] // empty')
readarray -t AUDIO_ARGS < <(echo "$TRANSCODE_PARAMS" | jq -r '.audio_args[] // empty')

# Disable set -e temporarily to check ffmpeg's exit code
set +e
ffmpeg \
  -hide_banner \
  -nostdin \
  -y \
  "${PRE_INPUT_ARGS[@]}" \
  -i "$INPUT_FILE" \
  "${VIDEO_ARGS[@]}" \
  "${AUDIO_ARGS[@]}" \
  -progress >(argo-ffmpeg-progress "$TOTAL_DURATION" "$ARGO_PROGRESS_FILE") \
  -stats_period 5 \
  "$TEMP_OUTPUT_FILE" 2>&1 | stdbuf --output=L tr '\r' '\n'
FFMPEG_EXIT_CODE=$?
set -e

if [ $FFMPEG_EXIT_CODE -eq 0 ]; then
  echo "Transcode completed successfully! Moving file to destination..."
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  mv "$TEMP_OUTPUT_FILE" "$OUTPUT_FILE"
  echo "$OUTPUT_FILE" > /tmp/transcoded_filepath.txt
else
  echo "Transcode failed." >&2
  exit 1
fi
