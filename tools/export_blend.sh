#!/usr/bin/env bash
# Exports hand-made art_source/<category>/<id>.blend files to game assets (P2-15).
# Usage: tools/export_blend.sh [--only ID ...] [--check] [--no-icons] [--sheets]
# Set BLENDER=/path/to/blender if it isn't on PATH. See blender/export_blend.py.
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-blender}"
if ! command -v "$BLENDER" >/dev/null 2>&1; then
  echo "Blender not found. Install Blender 5.x and set BLENDER=/path/to/blender" >&2
  exit 2
fi
"$BLENDER" -b --factory-startup -P blender/export_blend.py -- "$@"
echo "Next: run tools/run_tests.sh (it re-imports the new files into Godot)."
