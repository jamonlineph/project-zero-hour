"""Build placeholder 3D models (.glb) and 2D sprites (icons, sprite sheets).

Run headless from the repo root (or use tools/build_assets.sh / .ps1):

    blender -b --factory-startup -P blender/build_assets.py -- [options]

Options (after the --):
    --only ID [ID ...]   build only these asset ids
    --no-icons           skip icon rendering (much faster)
    --sheets             also render 8-direction sprite sheets
    --engine NAME        CYCLES (default, works everywhere) or BLENDER_EEVEE
    --samples N          render samples for Cycles (default 32)

Reads blender/specs/placeholders.json and writes:
    game/assets/models/<category>/<id>.glb
    game/assets/icons/<category>/<id>.png              (256x256 build icon)
    game/assets/sprites/<category>/<id>_8dir.png       (with --sheets)
and records every output in ASSET_MANIFEST.csv.
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sf_common as common  # noqa: E402
from sf_generators import ARCHETYPES  # noqa: E402

REPO = os.path.dirname(HERE)
SPEC_PATH = os.path.join(HERE, "specs", "placeholders.json")
GAME = os.path.join(REPO, "game")
MANIFEST = os.path.join(REPO, "ASSET_MANIFEST.csv")
ICON_SIZE = 256
SHEET_FRAME = 128


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="build_assets.py")
    parser.add_argument("--only", nargs="*", default=None)
    parser.add_argument("--no-icons", action="store_true")
    parser.add_argument("--sheets", action="store_true")
    parser.add_argument("--engine", default="CYCLES")
    parser.add_argument("--samples", type=int, default=32)
    return parser.parse_args(argv)


def manifest_row(rel_path, spec_id):
    return {
        "path": rel_path,
        "author": "Signal Front contributors",
        "source": "blender/build_assets.py (procedural, spec: %s)" % spec_id,
        "license": "CC-BY-SA-4.0",
        "generated_by": "script",
        "notes": "placeholder",
    }


def build_one(spec, palette, args):
    common.reset_scene()
    ARCHETYPES[spec["archetype"]](spec, palette)
    tris = common.triangle_count(common.asset_objects())
    category = spec["category"]
    rows = []

    glb_rel = "game/assets/models/%s/%s.glb" % (category, spec["id"])
    common.export_glb(os.path.join(REPO, glb_rel))
    rows.append(manifest_row(glb_rel, spec["id"]))

    if not args.no_icons or args.sheets:
        common.add_lights()
    if not args.no_icons:
        common.setup_render(ICON_SIZE, args.engine, args.samples)
        common.place_camera(azimuth_deg=-35, elevation_deg=30)
        icon_rel = "game/assets/icons/%s/%s.png" % (category, spec["id"])
        common.render_to(os.path.join(REPO, icon_rel))
        rows.append(manifest_row(icon_rel, spec["id"]))
    if args.sheets:
        common.setup_render(SHEET_FRAME, args.engine, max(8, args.samples // 2))
        frames = []
        for i in range(8):
            common.place_camera(azimuth_deg=i * 45, elevation_deg=35)
            frame = os.path.join(REPO, "build", "frames", "%s_%d.png" % (spec["id"], i))
            common.render_to(frame)
            frames.append(frame)
        sheet_rel = "game/assets/sprites/%s/%s_8dir.png" % (category, spec["id"])
        os.makedirs(os.path.dirname(os.path.join(REPO, sheet_rel)), exist_ok=True)
        common.stitch_horizontal(frames, os.path.join(REPO, sheet_rel))
        rows.append(manifest_row(sheet_rel, spec["id"]))

    budget = spec.get("tri_budget")
    warn = "  (over budget %d!)" % budget if budget and tris > budget else ""
    print("[build_assets] %-24s %6d triangles%s" % (spec["id"], tris, warn))
    return rows


def main():
    args = parse_args()
    with open(SPEC_PATH, encoding="utf-8") as f:
        data = json.load(f)
    palette = {"factions": data["factions"], "team_color_preview": data["team_color_preview"]}
    specs = data["assets"]
    if args.only:
        wanted = set(args.only)
        unknown = wanted - {s["id"] for s in specs}
        if unknown:
            print("[build_assets] unknown ids: %s" % ", ".join(sorted(unknown)))
            sys.exit(2)
        specs = [s for s in specs if s["id"] in wanted]
    rows = []
    for spec in specs:
        rows.extend(build_one(spec, palette, args))
    common.update_manifest(MANIFEST, rows)
    print("[build_assets] done: %d assets, %d files" % (len(specs), len(rows)))


if __name__ == "__main__":
    main()
