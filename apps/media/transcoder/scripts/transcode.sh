#!/bin/bash
set -o pipefail

# These are expected to be passed as environment variables
# FILEPATH
# OUTPUT_FILEPATH
# TRANSCODE_PARAMS (JSON string containing parameters, e.g. quality)
# ENCODER (optional: 'hardware' or 'software')

if [ -z "$FILEPATH" ]; then
  echo "Error: No filepath provided."
  exit 1
fi

# Default values
ENCODER_TYPE="hardware"
QUALITY="24"

if [ -n "${TRANSCODE_PARAMS:-}" ]; then
  if echo "$TRANSCODE_PARAMS" | jq empty 2>/dev/null; then
    QUALITY=$(echo "$TRANSCODE_PARAMS" | jq -r '.quality // "24"')
  else
    echo "Warning: Invalid TRANSCODE_PARAMS JSON. Using default quality." >&2
  fi
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--encoder)
      if [[ -n "$2" && "$2" != -* ]]; then
        ENCODER_TYPE="$2"
        shift 2
      else
        echo "Error: Argument for $1 is missing." >&2
        exit 1
      fi
      ;;
    --encoder=*)
      ENCODER_TYPE="${1#*=}"
      shift
      ;;
    -s|--software)
      ENCODER_TYPE="software"
      shift
      ;;
    -h|--hardware)
      ENCODER_TYPE="hardware"
      shift
      ;;
    *)
      # Positional arguments or unknown flags are ignored
      shift
      ;;
  esac
done

# If ENCODER env var is set, use it (acts as a default or override depending on usage)
if [ -n "$ENCODER" ]; then
  ENCODER_TYPE="$ENCODER"
fi

# Normalize ENCODER_TYPE to lowercase
ENCODER_TYPE=$(echo "$ENCODER_TYPE" | tr '[:upper:]' '[:lower:]')

if [ "$ENCODER_TYPE" != "hardware" ] && [ "$ENCODER_TYPE" != "software" ]; then
  echo "Error: Invalid encoder type '$ENCODER_TYPE'. Must be 'hardware' or 'software'." >&2
  exit 1
fi

echo "Received transcoding request for: $FILEPATH"
echo "Encoder type: $ENCODER_TYPE"

# Normalize input filepath (always relative to /media)
INPUT_FILE="/media/${FILEPATH#/}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File $INPUT_FILE not found on PVC."
  exit 1
fi

if [ -z "$OUTPUT_FILEPATH" ]; then
  echo "Error: OUTPUT_FILEPATH is not resolved."
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

# Determine audio settings directly from OPA policy arguments
AUDIO_ARGS=()

if [ -n "${TRANSCODE_PARAMS:-}" ] && echo "$TRANSCODE_PARAMS" | jq empty 2>/dev/null; then
  # Load the audio arguments array directly from OPA policy output
  readarray -t AUDIO_ARGS < <(echo "$TRANSCODE_PARAMS" | jq -r '.audio_args[] // empty')
else
  # Default to copy if TRANSCODE_PARAMS is missing or invalid
  AUDIO_ARGS=(-c:a copy)
fi

echo "Total duration (s): $TOTAL_DURATION"
echo "Starting ffmpeg transcode: $INPUT_FILE -> $TEMP_OUTPUT_FILE (temp)"

if [ "$ENCODER_TYPE" = "hardware" ]; then
  # Pick the highest render device available (e.g., renderD129 over renderD128)
  # This commonly bypasses ASPEED BMC display adapters in homelab servers.
  RENDER_DEVICE=$(ls /dev/dri/renderD* 2>/dev/null | sort -r | head -n 1)
  if [ -z "$RENDER_DEVICE" ]; then
    RENDER_DEVICE="/dev/dri/renderD128"
  fi
  echo "Selected render device: $RENDER_DEVICE"

  PRE_INPUT_ARGS=(
    -hwaccel vaapi
    -hwaccel_device "$RENDER_DEVICE"
    -hwaccel_output_format vaapi
  )
  VIDEO_ARGS=(
    -c:v hevc_vaapi
    -q:v "$QUALITY"
  )
else
  PRE_INPUT_ARGS=()
  VIDEO_ARGS=(
    -c:v libx265
    -crf "$QUALITY"
  )
fi

ffmpeg \
  -hide_banner \
  -nostdin \
  -y \
  "${PRE_INPUT_ARGS[@]}" \
  -i "$INPUT_FILE" \
  "${VIDEO_ARGS[@]}" \
  "${AUDIO_ARGS[@]}" \
  -progress >(/scripts/argo-ffmpeg-progress.sh "$TOTAL_DURATION" "$ARGO_PROGRESS_FILE") \
  -stats_period 5 \
  "$TEMP_OUTPUT_FILE" 2>&1 | tr '\r' '\n'


if [ $? -eq 0 ]; then
  echo "Transcode completed successfully! Moving file to destination..."
  mkdir -p $(dirname "$OUTPUT_FILE")
  mv "$TEMP_OUTPUT_FILE" "$OUTPUT_FILE"
  echo "$OUTPUT_FILE" > /tmp/transcoded_filepath.txt

else
  echo "Transcode failed."
  exit 1
fi

