#!/usr/bin/env bash
# Checks blender/export_blend.py on generated fixtures in a temp folder (P2-15).
# Needs Blender (set BLENDER=/path/to/blender). Never touches game/assets.
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-blender}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "test_export_blend: FAIL: $*" >&2; exit 1; }

"$BLENDER" -b --factory-startup -P blender/tests/make_test_blends.py -- "$TMP/art_source" >/dev/null

# 1. --check flags the bad files and changes nothing.
if "$BLENDER" -b --factory-startup -P blender/export_blend.py -- --check \
    --source "$TMP/art_source" --out "$TMP/out" > "$TMP/check.log" 2>&1; then
  fail "--check passed although three fixtures are broken"
fi
grep -q "test_no_provenance .*SKIPPED: missing provenance" "$TMP/check.log" || fail "missing provenance not reported"
grep -q "test_bad_license .*SKIPPED: license All rights reserved" "$TMP/check.log" || fail "bad license not reported"
grep -q "test_no_team_color .*ERROR: no surface uses a material named exactly 'team_color'" "$TMP/check.log" || fail "missing team_color not reported"
grep -q "us_mbt .*ok" "$TMP/check.log" || fail "the good fixture did not pass the check"
[ ! -e "$TMP/out/game" ] || fail "--check wrote files"

# 2. Exporting the good file writes the model, the icon and manifest rows.
"$BLENDER" -b --factory-startup -P blender/export_blend.py -- --only us_mbt --samples 4 \
    --source "$TMP/art_source" --out "$TMP/out" > "$TMP/export.log" 2>&1 || fail "export failed: $(tail -5 "$TMP/export.log")"
[ -s "$TMP/out/game/assets/models/units/us_mbt.glb" ] || fail "no .glb written"
[ -s "$TMP/out/game/assets/icons/units/us_mbt.png" ] || fail "no icon written"
grep -q "^game/assets/models/units/us_mbt.glb,Test Artist,test fixture,CC-BY-4.0,hand-made," "$TMP/out/ASSET_MANIFEST.csv" \
  || fail "manifest row for the model is wrong"
python3 - "$TMP/out/game/assets/models/units/us_mbt.glb" <<'PY' || fail "the exported model has no team_color material or has a camera/light"
import json, struct, sys
data = open(sys.argv[1], "rb").read()
length = struct.unpack("<I", data[12:16])[0]
gltf = json.loads(data[20:20 + length])
assert any(m.get("name") == "team_color" for m in gltf.get("materials", []))
assert not gltf.get("cameras") and "KHR_lights_punctual" not in gltf.get("extensionsUsed", [])
PY
echo "test_export_blend: ok"
