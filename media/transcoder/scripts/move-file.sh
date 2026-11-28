#!/bin/sh
set -eu

INPUT_FILEPATH="${1:-}"
OUTPUT_FILEPATH="${2:-}"
REPLACE_ORIGINAL="${3:-false}"

if [ -z "$INPUT_FILEPATH" ] || [ -z "$OUTPUT_FILEPATH" ]; then
  echo "Usage: $0 <input_filepath> <output_filepath> [replace_original]" >&2
  exit 1
fi

INPUT_FILE="$INPUT_FILEPATH"
if [ "${INPUT_FILE#/media/}" != "$INPUT_FILE" ]; then
  INPUT="$INPUT_FILE"
else
  INPUT="/media/${INPUT_FILE#/}"
fi

OUTPUT_FILE="$OUTPUT_FILEPATH"
if [ "${OUTPUT_FILE#/media/}" != "$OUTPUT_FILE" ]; then
  OUTPUT="$OUTPUT_FILE"
else
  OUTPUT="/media/${OUTPUT_FILE#/}"
fi

if [ ! -f "$INPUT" ]; then
  echo "Error: Input file not found: $INPUT" >&2
  exit 1
fi

# Make sure target directory exists
mkdir -p "$(dirname "$OUTPUT")"

REAL_INPUT=$(realpath "$INPUT")
REAL_OUTPUT=$(realpath "$OUTPUT" 2>/dev/null || echo "$OUTPUT")

if [ "$REAL_INPUT" = "$REAL_OUTPUT" ]; then
  echo "Input and output files are the same: $INPUT. No move or copy required."
  exit 0
fi

if [ "$REPLACE_ORIGINAL" = "true" ]; then
  echo "Moving $INPUT to $OUTPUT"
  mv "$INPUT" "$OUTPUT"
else
  echo "Copying $INPUT to $OUTPUT"
  cp "$INPUT" "$OUTPUT"
fi
