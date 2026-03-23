#!/bin/bash
# Copy live hiking data into the repo's data/ directory.
# Run this before pushing so that Cowork (or any env without
# access to ~/Library/Application Support/Hiking) has fresh data.

set -euo pipefail

SRC_DIR="$HOME/Library/Application Support/Hiking"
DEST_DIR="$(cd "$(dirname "$0")/data" && pwd)"

for file in hike_history.json trails.json; do
  if [ -f "$SRC_DIR/$file" ]; then
    cp "$SRC_DIR/$file" "$DEST_DIR/$file"
    echo "Copied $file"
  else
    echo "Warning: $SRC_DIR/$file not found, skipping" >&2
  fi
done
