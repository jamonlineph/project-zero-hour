#!/usr/bin/env bash
# Runs the headless Godot test suite: unit tests, then the main-scene smoke test.
# Usage: tools/run_tests.sh            (set GODOT=/path/to/godot if it isn't on PATH)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "Godot not found. Install Godot 4.7.x and set GODOT=/path/to/godot" >&2
  exit 2
fi

echo "== Importing assets (needed once after new files are added)"
"$GODOT" --headless --path game --import

echo "== Unit tests"
"$GODOT" --headless --path game --script res://tests/run_tests.gd

echo "== Smoke test (main scene)"
"$GODOT" --headless --path game --script res://tests/smoke_main.gd

echo "== Smoke test (menus)"
"$GODOT" --headless --path game --script res://tests/smoke_menu.gd

echo "== Smoke test (LAN lockstep)"
"$GODOT" --headless --path game --script res://tests/smoke_lan.gd

echo "== All tests passed"
