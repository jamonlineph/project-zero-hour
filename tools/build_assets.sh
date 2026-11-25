#!/usr/bin/env bash
# Generates placeholder models and renders icons/sprites with Blender (headless).
# Usage: tools/build_assets.sh [--only ID ...] [--no-icons] [--sheets]
# Set BLENDER=/path/to/blender if it isn't on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-blender}"

if ! command -v "$BLENDER" >/dev/null 2>&1; then
  echo "Blender not found. Install Blender 5.x and set BLENDER=/path/to/blender" >&2
  exit 2
fi

"$BLENDER" -b --factory-startup -P blender/build_assets.py -- "$@"
echo "Next: run tools/run_tests.sh (it re-imports the new files into Godot)."
