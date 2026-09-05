#!/bin/sh
set -eu

INPUT_FILEPATH="${1:-}"
OUTPUT_FILEPATH="${2:-}"

if [ -z "$INPUT_FILEPATH" ] || [ -z "$OUTPUT_FILEPATH" ]; then
  echo "Usage: $0 <input_filepath> <output_filepath>" >&2
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

# Guard: must be a regular file, not a directory or symlink to one
if [ ! -f "$INPUT" ]; then
  echo "Skipping: input path is not a regular file: $INPUT"
  exit 0
fi

REAL_INPUT=$(realpath "$INPUT")
REAL_OUTPUT=$(realpath "$OUTPUT" 2>/dev/null || echo "$OUTPUT")

if [ "$REAL_INPUT" != "$REAL_OUTPUT" ]; then
  echo "Deleting original input file: $INPUT"
  DELETED=false
  for i in 1 2 3; do
    echo "Deletion attempt $i of 3..."
    if [ ! -f "$INPUT" ]; then
      echo "Successfully verified original file deletion."
      DELETED=true
      break
    fi
    rm -f "$INPUT" || true
    sync
    if [ ! -f "$INPUT" ]; then
      echo "Successfully verified original file deletion."
      DELETED=true
      break
    fi
    echo "Warning: File still detected after attempt $i. Retrying after delay..." >&2
    sleep 10
  done
  if [ "$DELETED" = "false" ]; then
    echo "Error: Failed to delete original file after 3 attempts." >&2
    exit 1
  fi
else
  echo "Skipping deletion: output overwrote the original file."
fi
