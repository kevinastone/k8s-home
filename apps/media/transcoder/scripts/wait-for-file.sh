#!/bin/sh
set -eu

FILEPATH="${1:-}"
if [ -z "$FILEPATH" ]; then
  echo "Usage: $0 <filepath>" >&2
  exit 1
fi

INPUT_FILE="/media/${FILEPATH#/}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File $INPUT_FILE not found on PVC." >&2
  exit 1
fi

echo "Waiting for file to stabilize: $INPUT_FILE"
prev_size=-1
stable_count=0
required_stable_checks=3
check_interval=10

while true; do
  # Force NFS/SMB attribute cache invalidation by attempting a touch
  touch -c "$INPUT_FILE" 2>/dev/null || true

  curr_size=$(stat -c %s "$INPUT_FILE" 2>/dev/null || stat -f %z "$INPUT_FILE" 2>/dev/null || wc -c < "$INPUT_FILE")
  if [ -z "$curr_size" ]; then
    echo "Error: Could not determine size of $INPUT_FILE" >&2
    exit 1
  fi

  if [ "$prev_size" -eq -1 ]; then
    echo "Initial size check: $curr_size bytes"
  else
    echo "Current size: $curr_size bytes (previous: $prev_size bytes)"
  fi

  if [ "$curr_size" -eq "$prev_size" ] && [ "$curr_size" -gt 0 ]; then
    stable_count=$((stable_count + 1))
    echo "Size has been stable for $stable_count consecutive check(s)."
    if [ "$stable_count" -ge "$required_stable_checks" ]; then
      echo "File size stabilized at $curr_size bytes."
      break
    fi
  else
    if [ "$prev_size" -ne -1 ] && [ "$curr_size" -ne "$prev_size" ]; then
      echo "Size changed. Resetting stability counter."
    fi
    stable_count=0
  fi

  prev_size=$curr_size
  sleep $check_interval
done
