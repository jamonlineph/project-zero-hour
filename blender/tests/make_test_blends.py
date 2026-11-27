"""Makes .blend fixtures for tools/test_export_blend.sh (P2-15).

    blender -b --factory-startup -P blender/tests/make_test_blends.py -- OUT_DIR

Writes OUT_DIR/units/<id>.blend (+ .json provenance) built from the
placeholder generator: a good one, one without provenance, one with a
license that isn't allowed, and one without a team_color material.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402

import sf_common as common  # noqa: E402
from sf_generators import ARCHETYPES  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1]
with open(os.path.join(HERE, "specs", "placeholders.json"), encoding="utf-8") as f:
    DATA = json.load(f)
PALETTE = {"factions": DATA["factions"], "team_color_preview": DATA["team_color_preview"]}
SPEC = next(s for s in DATA["assets"] if s["id"] == "us_mbt")


def make(asset_id, meta, strip_team_color=False):
    common.reset_scene()
    ARCHETYPES[SPEC["archetype"]](SPEC, PALETTE)
    if strip_team_color:
        plain = common.get_material("hull_plain", (0.5, 0.5, 0.45, 1.0))
        for obj in common.asset_objects():
            for slot in getattr(obj, "material_slots", []):
                if slot.material is not None and slot.material.name == "team_color":
                    slot.material = plain
    # An artist's own camera and light, which the exporter must ignore.
    bpy.ops.object.camera_add(location=(10, -10, 8))
    bpy.ops.object.light_add(type="POINT", location=(0, 0, 10))
    folder = os.path.join(OUT, "units")
    os.makedirs(folder, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder, asset_id + ".blend"))
    if meta is not None:
        with open(os.path.join(folder, asset_id + ".json"), "w", encoding="utf-8") as f:
            json.dump(meta, f)


GOOD = {"author": "Test Artist", "license": "CC-BY-4.0", "source": "test fixture"}
make("us_mbt", GOOD)
make("test_no_provenance", None)
make("test_bad_license", {"author": "Test Artist", "license": "All rights reserved"})
make("test_no_team_color", GOOD, strip_team_color=True)
print("[make_test_blends] wrote fixtures to %s" % OUT)
