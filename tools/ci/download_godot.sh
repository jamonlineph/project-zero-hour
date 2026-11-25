#!/usr/bin/env bash
# Downloads the official Godot build (and, with --templates, its export
# templates) into the repo root as ./godot-bin. Used by CI; also works on any
# Linux x86_64 machine. Version comes from $GODOT_VERSION (default below).
set -euo pipefail
cd "$(dirname "$0")/../.."
VERSION="${GODOT_VERSION:-4.7.2}"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"

curl -fsSL -o godot.zip "${BASE}/Godot_v${VERSION}-stable_linux.x86_64.zip"
unzip -q -o godot.zip
mv "Godot_v${VERSION}-stable_linux.x86_64" godot-bin
chmod +x godot-bin
rm godot.zip

if [[ "${1:-}" == "--templates" ]]; then
  DEST="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
  curl -fsSL -o templates.tpz "${BASE}/Godot_v${VERSION}-stable_export_templates.tpz"
  mkdir -p "$DEST"
  unzip -q -o templates.tpz -d templates_tmp
  mv templates_tmp/templates/* "$DEST/"
  rm -rf templates_tmp templates.tpz
  echo "Export templates installed in $DEST"
fi
