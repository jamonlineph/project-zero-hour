#!/usr/bin/env bash
# Regenerates game/tests/replays/*.json after an intended change to sim rules
# or game data. Explain the change in your commit message.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path game --import >/dev/null
"$GODOT" --headless --path game --script res://tests/tools/make_golden_replays.gd
