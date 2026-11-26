#!/usr/bin/env bash
# Performance harness (P1-33): sim ms per tick and view sync time for fixed
# scenarios, compared with game/tests/perf/perf_baseline.json (fails on a
# regression of more than 20%, after normalizing for machine speed).
# Usage: tools/run_perf.sh [--update-baseline]   (set GODOT=/path/to/godot if needed)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "Godot not found. Install Godot 4.7.x and set GODOT=/path/to/godot" >&2
  exit 2
fi

"$GODOT" --headless --path game --script res://tests/perf/run_perf.gd -- "$@"
