#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' does not exist." >&2
  exit 1
fi

echo "Building CUE dashboards in '$TARGET_DIR'..."
found=0
while IFS= read -r -d $'\0' cue_file; do
  found=1
  dir=$(dirname "$cue_file")
  base=$(basename "$cue_file" .cue)
  target="$dir/$base.json"
  echo "  Exporting $cue_file -> $target"
  cue export "$cue_file" -e out --out json >"$target"
done < <(find "$TARGET_DIR" -type f -not -path "*/cue.mod/*" -path "*/dashboards/*.cue" -print0)

if [ "$found" -eq 0 ]; then
  echo "No .cue files found in '$TARGET_DIR'."
else
  echo "Done."
fi
