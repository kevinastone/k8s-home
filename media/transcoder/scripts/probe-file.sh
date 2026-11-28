#!/bin/bash
set -euo pipefail

FILEPATH="${1:-}"
if [ -z "$FILEPATH" ]; then
  echo "Usage: $0 <filepath>" >&2
  exit 1
fi

INPUT_FILE="/media/${FILEPATH#/}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File $INPUT_FILE not found on PVC." >&2
  jq -n '{"streams": [], "format": {"size": "0"}}' >/tmp/media-info.json
else
  echo "Probing file: $INPUT_FILE"
  if ! ffprobe -v quiet -print_format json -show_format -show_streams "$INPUT_FILE" >/tmp/media-info.json; then
    echo "Warning: ffprobe failed. Writing fallback JSON." >&2
    jq -n '{"streams": [], "format": {"size": "0"}}' >/tmp/media-info.json
  fi
fi
