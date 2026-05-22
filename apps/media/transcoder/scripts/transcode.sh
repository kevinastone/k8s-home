#!/bin/bash
set -o pipefail

# These are expected to be passed as environment variables
# FILEPATH
# OUTPUT_FILEPATH
# QUALITY
# ENCODER (optional: 'hardware' or 'software')

if [ -z "$FILEPATH" ]; then
  echo "Error: No filepath provided."
  exit 1
fi

# Default values
ENCODER_TYPE="hardware"

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

# Ensure the output file uses a compatible container (e.g., .mp4) if it currently uses an incompatible one
EXT="${OUTPUT_FILE##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
if [ "$EXT_LOWER" != "mp4" ] && [ "$EXT_LOWER" != "mkv" ]; then
  OUTPUT_FILE="${OUTPUT_FILE%.*}.mp4"
fi

TEMP_OUTPUT_FILE="/temp/$(basename "$OUTPUT_FILE")"

TOTAL_FRAMES=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nokey=1:noprint_wrappers=1 "$INPUT_FILE" 2>/dev/null)
if [ -z "$TOTAL_FRAMES" ] || [ "$TOTAL_FRAMES" == "N/A" ]; then
  TOTAL_FRAMES=0
fi

# Query the audio codec of the first audio stream to ensure compatibility with MP4
AUDIO_CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nokey=1:noprint_wrappers=1 "$INPUT_FILE" 2>/dev/null | head -n 1)

if [ -z "$AUDIO_CODEC" ]; then
  # No audio stream present
  AUDIO_ARGS=()
elif [[ "$AUDIO_CODEC" == "aac" || "$AUDIO_CODEC" == "ac3" || "$AUDIO_CODEC" == "eac3" || "$AUDIO_CODEC" == "mp3" ]]; then
  # Natively supported and highly compatible MP4 audio codecs - safe to copy
  AUDIO_ARGS=(-c:a copy)
else
  # Legacy, high-definition, or incompatible audio codecs (wmav2, pcm, flac, vorbis, dts, truehd, etc.) - transcode to AAC
  echo "Audio codec '$AUDIO_CODEC' is not natively compatible/optimal for MP4. Transcoding to AAC..."
  AUDIO_ARGS=(-c:a aac -b:a 192k)
fi

echo "Total frames: $TOTAL_FRAMES"
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
  -progress >(/scripts/argo-ffmpeg-progress.sh "$TOTAL_FRAMES" "$ARGO_PROGRESS_FILE") \
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

