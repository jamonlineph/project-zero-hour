"""Export hand-made .blend models to game assets (P2-15).

Run headless from the repo root (or use tools/export_blend.sh / .ps1):

    blender -b --factory-startup -P blender/export_blend.py -- [options]

Options (after the --):
    --only ID [ID ...]   export only these asset ids
    --no-icons           skip icon rendering
    --sheets             also render 8-direction sprite sheets
    --check              only check the files against the conventions
    --engine NAME        CYCLES (default) or BLENDER_EEVEE
    --samples N          render samples for Cycles (default 32)
    --source DIR         where the .blend files are (default art_source/)
    --out DIR            repo root to write into (default: this repo); for tests

For every art_source/<category>/<id>.blend (category: units, buildings or
props) it reads the provenance file next to it, art_source/<category>/<id>.json:

    {"author": "Jane Doe", "license": "CC-BY-SA-4.0", "source": "made in Blender 5.3"}

checks the conventions in docs/04-art-pipeline.md, then writes the same
outputs as build_assets.py, rendered with the same lights, camera and size:
    game/assets/models/<category>/<id>.glb
    game/assets/icons/<category>/<id>.png
    game/assets/sprites/<category>/<id>_8dir.png   (with --sheets)
and records them in ASSET_MANIFEST.csv with the artist's author and license.
The .blend file itself is never changed.
"""

import argparse
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402

import sf_common as common  # noqa: E402

REPO = os.path.dirname(HERE)
SPEC_PATH = os.path.join(HERE, "specs", "placeholders.json")
CATEGORIES = ("units", "buildings", "props")
ALLOWED_LICENSES = {"CC-BY-SA-4.0", "CC-BY-4.0", "CC0-1.0", "OFL-1.1"}
ICON_SIZE = 256
SHEET_FRAME = 128
GROUND_TOLERANCE_M = 0.05


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="export_blend.py")
    parser.add_argument("--only", nargs="*", default=None)
    parser.add_argument("--no-icons", action="store_true")
    parser.add_argument("--sheets", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--engine", default="CYCLES")
    parser.add_argument("--samples", type=int, default=32)
    parser.add_argument("--source", default=os.path.join(REPO, "art_source"))
    parser.add_argument("--out", default=REPO)
    return parser.parse_args(argv)


def find_sources(source_dir, only):
    """[(category, id, blend_path)] for every .blend under source_dir."""
    found = []
    for category in CATEGORIES:
        for path in sorted(glob.glob(os.path.join(source_dir, category, "*.blend"))):
            asset_id = os.path.splitext(os.path.basename(path))[0]
            if only is None or asset_id in only:
                found.append((category, asset_id, path))
    return found


def read_provenance(blend_path):
    """The provenance dict next to the .blend, or (None, reason)."""
    meta_path = os.path.splitext(blend_path)[0] + ".json"
    if not os.path.exists(meta_path):
        return None, "missing provenance file %s" % os.path.basename(meta_path)
    with open(meta_path, encoding="utf-8") as f:
        meta = json.load(f)
    for key in ("author", "license"):
        if not str(meta.get(key, "")).strip():
            return None, "provenance file needs '%s'" % key
    if meta["license"] not in ALLOWED_LICENSES:
        return None, "license %s is not allowed (%s)" % (meta["license"], ", ".join(sorted(ALLOWED_LICENSES)))
    return meta, ""


def tri_budgets():
    """Triangle budgets from the placeholder specs, by id."""
    with open(SPEC_PATH, encoding="utf-8") as f:
        data = json.load(f)
    return {s["id"]: s.get("tri_budget") for s in data["assets"] if s.get("tri_budget")}


def check_conventions(asset_id, budget):
    """(problems, warnings) for the open file."""
    problems = []
    warnings = []
    meshes = [o for o in common.asset_objects() if o.type == "MESH"]
    if not meshes:
        problems.append("no mesh objects")
        return problems, warnings
    has_team = any(slot.material is not None and slot.material.name == "team_color"
                   for o in meshes for slot in o.material_slots)
    if not has_team:
        problems.append("no surface uses a material named exactly 'team_color'")
    for o in meshes:
        for slot in o.material_slots:
            mat = slot.material
            if mat is not None and mat.use_nodes and mat.node_tree is not None:
                kinds = {n.type for n in mat.node_tree.nodes}
                if "BSDF_PRINCIPLED" not in kinds:
                    warnings.append("material %s has no Principled BSDF (glTF exports only that)" % mat.name)
    lowest = min((o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices)
    if abs(lowest) > GROUND_TOLERANCE_M:
        warnings.append("lowest point is at z = %.2f m; the ground is z = 0" % lowest)
    tris = common.triangle_count(meshes)
    if budget and tris > budget:
        warnings.append("%d triangles, over the %d budget" % (tris, budget))
    return problems, warnings


def manifest_row(rel_path, meta, asset_id):
    return {
        "path": rel_path,
        "author": meta["author"],
        "source": meta.get("source") or "art_source/%s.blend" % asset_id,
        "license": meta["license"],
        "generated_by": "hand-made",
        "notes": "exported by blender/export_blend.py",
    }


def prepare_render_scene():
    """Removes the file's own lights and cameras (only in memory), so every
    icon gets the same lighting as the placeholders."""
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.scene.camera = None
    common.add_lights()


def export_one(category, asset_id, blend_path, meta, args):
    out = args.out
    rows = []
    glb_rel = "game/assets/models/%s/%s.glb" % (category, asset_id)
    common.export_glb(os.path.join(out, glb_rel))
    rows.append(manifest_row(glb_rel, meta, asset_id))
    if args.no_icons and not args.sheets:
        return rows
    prepare_render_scene()
    if not args.no_icons:
        common.setup_render(ICON_SIZE, args.engine, args.samples)
        common.place_camera(azimuth_deg=-35, elevation_deg=30)
        icon_rel = "game/assets/icons/%s/%s.png" % (category, asset_id)
        common.render_to(os.path.join(out, icon_rel))
        rows.append(manifest_row(icon_rel, meta, asset_id))
    if args.sheets:
        common.setup_render(SHEET_FRAME, args.engine, max(8, args.samples // 2))
        frames = []
        for i in range(8):
            common.place_camera(azimuth_deg=i * 45, elevation_deg=35)
            frame = os.path.join(out, "build", "frames", "%s_%d.png" % (asset_id, i))
            common.render_to(frame)
            frames.append(frame)
        sheet_rel = "game/assets/sprites/%s/%s_8dir.png" % (category, asset_id)
        os.makedirs(os.path.dirname(os.path.join(out, sheet_rel)), exist_ok=True)
        common.stitch_horizontal(frames, os.path.join(out, sheet_rel))
        rows.append(manifest_row(sheet_rel, meta, asset_id))
    return rows


def main():
    args = parse_args()
    sources = find_sources(args.source, set(args.only) if args.only else None)
    if not sources:
        print("[export_blend] no .blend files under %s" % args.source)
        return
    budgets = tri_budgets()
    rows = []
    failed = []
    for category, asset_id, path in sources:
        meta, reason = read_provenance(path)
        if meta is None:
            print("[export_blend] %-24s SKIPPED: %s" % (asset_id, reason))
            failed.append(asset_id)
            continue
        bpy.ops.wm.open_mainfile(filepath=path)
        problems, warnings = check_conventions(asset_id, budgets.get(asset_id))
        for w in warnings:
            print("[export_blend] %-24s warning: %s" % (asset_id, w))
        if problems:
            for p in problems:
                print("[export_blend] %-24s ERROR: %s" % (asset_id, p))
            failed.append(asset_id)
            continue
        if args.check:
            print("[export_blend] %-24s ok" % asset_id)
            continue
        rows.extend(export_one(category, asset_id, path, meta, args))
        print("[export_blend] %-24s exported (%s)" % (asset_id, category))
    if rows:
        common.update_manifest(os.path.join(args.out, "ASSET_MANIFEST.csv"), rows)
    print("[export_blend] done: %d exported, %d failed, %d files" % (
        len(sources) - len(failed) if not args.check else 0, len(failed), len(rows)))
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
