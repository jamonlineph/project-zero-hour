# Blender pipeline

Scripts that turn short JSON specs into game assets, headless, with no clicking needed:

- **3D models** (`.glb`, glTF binary) for Godot: `game/assets/models/<category>/<id>.glb`
- **Build icons** (256×256 PNG with transparency): `game/assets/icons/<category>/<id>.png`
- **8-direction sprite sheets** (optional, 8 × 128 px frames): `game/assets/sprites/<category>/<id>_8dir.png`

Every output is recorded in `ASSET_MANIFEST.csv`.

## Run it

```bash
tools/build_assets.sh                  # everything in specs/placeholders.json
tools/build_assets.sh --only us_mbt    # one asset
tools/build_assets.sh --no-icons       # models only (seconds)
tools/build_assets.sh --sheets         # also render sprite sheets
```

Set `BLENDER=/path/to/blender` if Blender isn't on your PATH. Tested with Blender 5.3.0, where all 7 assets with icons take about 10 seconds on a CPU.

## Files

| File | Purpose |
|---|---|
| `build_assets.py` | Entry point: reads specs, builds, exports, renders, updates the manifest |
| `sf_generators.py` | One generator per archetype: `tracked`, `wheeled`, `infantry`, `drone`, `building` |
| `sf_common.py` | Shapes, materials, glTF export, camera/lights, sprite-sheet stitching, manifest |
| `specs/placeholders.json` | Asset specs: id, category, archetype, faction, sizes in meters, options |

## Add a placeholder asset

1. Add an entry to `specs/placeholders.json`, for example `{"id": "cn_mbt", "category": "units", "archetype": "tracked", "faction": "cn", "length": 7.2, "width": 3.4, "height": 2.3}`.
2. Run `tools/build_assets.sh --only cn_mbt`.
3. Point the unit's JSON (`game/data/units/cn_mbt.json`) at the model and icon.
4. Run `tools/run_tests.sh` and `python3 tools/check_repo.py`.

## Replace a placeholder with real art

Hand-made models live in `art_source/<category>/<id>.blend`. Export them with the same conventions (see [docs/04-art-pipeline.md](../docs/04-art-pipeline.md)):
- 1 unit = 1 meter
- ground at z = 0
- the front faces −Y
- a material named `team_color`
- empties named `muzzle_0`, `fx_exhaust` and so on for effects

Backlog task P2-15 adds a script that exports and renders icons from `.blend` files the same way.
