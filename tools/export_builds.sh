#!/usr/bin/env bash
# Exports every preset in game/export_presets.cfg into build/.
# Needs Godot (GODOT=...), its export templates, and for Android: JAVA_HOME
# (JDK 17), ANDROID_HOME (Android SDK with build-tools) and a debug keystore
# given through GODOT_ANDROID_KEYSTORE_DEBUG_PATH/_USER/_PASSWORD.
# See docs/05-platforms.md. Usage: tools/export_builds.sh [PresetName ...]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PRESETS=("$@")
if [[ ${#PRESETS[@]} -eq 0 ]]; then
  PRESETS=("Android" "Linux" "Windows")
fi

mkdir -p build/android build/linux build/windows
"$GODOT" --headless --path game --import

declare -A OUT=(
  [Android]="../build/android/project-zero-hour-debug.apk"
  [Linux]="../build/linux/project-zero-hour.x86_64"
  [Windows]="../build/windows/project-zero-hour.exe"
)
for preset in "${PRESETS[@]}"; do
  echo "== Exporting $preset"
  "$GODOT" --headless --path game --export-debug "$preset" "${OUT[$preset]}"
  test -s "build/${OUT[$preset]#../build/}" || { echo "Export of $preset produced no file" >&2; exit 1; }
done
ls -la build/*/
