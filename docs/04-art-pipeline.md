# Art pipeline: Blender to Godot

## Tools

- **Blender 5.x** (scripts tested with 5.3.0) for models, rendered icons and sprite sheets.
- **Godot 4.7** imports `.glb` (glTF 2.0 binary) automatically. Commit the `.import` files Godot creates next to each asset; never commit `game/.godot/`.

## The game is 3D. Blender also makes the 2D sprites.

Units and buildings are low-poly 3D models, so the camera can zoom and rotate and terrain can have height. Blender renders every 2D image from those same models:

| Output | Size | Where it's used |
|---|---|---|
| Build icon | 256×256 PNG, transparent | Build menus, production queue, selection panel |
| 8-direction sprite sheet | 8 frames × 128 px | Minimap and far-zoom impostors on low-end phones (optional) |
| Portrait (later) | 512×512 | Commander powers, unit info cards |

`tools/build_assets.sh` does all of this headless (see [blender/README.md](../blender/README.md)).

## Art direction: clean stylized realism

- **Readable silhouettes** at RTS zoom. Exaggerate guns, turrets and rotors by about 20–40%, and infantry by about 30%.
- **Muted military bodies with strong team-color panels.** Each model has a `team_color` material on parts visible from above: turret sides, roofs, vests, the band around buildings.
- **Simple surfaces:** flat colors or small gradient textures with baked ambient occlusion. Avoid noisy detail that turns to mush on a phone.
- **One key light from the top left** in icons, to match the in-game sun direction.
- **Faction looks:**

| Faction | Shapes | Colors |
|---|---|---|
| US | Angular, sensor domes, antennas | Sand and olive |
| China | Smooth slab armor | Grey-green with subtle digital pattern |
| Russia | Boxy, cages and add-on armor | Dark green |
| Irregulars | Mismatched panels, improvised mounts | Tan, rust and civilian colors |

## Conventions (scripts and humans both follow these)

| Rule | Value |
|---|---|
| Scale | 1 Blender unit = 1 meter. Ground is z = 0. Origin = footprint center. |
| Facing | The model's **front faces −Y** in Blender, which becomes **+Z** in Godot (`Vector3.MODEL_FRONT`). |
| Team color | A material named exactly `team_color`. Godot recolors it per player (`TeamColors.apply`). |
| Moving parts | Separate objects named `turret`, `barrel`, `rotor_main`, `wheel_l0` and so on, parented in a hierarchy (turret → hull). Put each part's origin at its pivot: the game turns `turret` about its vertical axis and tilts `barrel` about its X axis from their rest pose (`set_origin` in `sf_common.py` does this for generated models). |
| Effect points | Empties named `muzzle_0`, `muzzle_1`, `fx_exhaust`, `fx_smoke` |
| Materials | Principled BSDF only (that's what glTF exports). Base color, roughness, metallic, optional normal map. Colors in `blender/specs/placeholders.json` are sRGB (as picked in an image editor); `sf_common.get_material` converts them to linear. |
| File names | `<faction>_<role>[_<variant>]`: `us_mbt`, `ru_ew_vehicle`, `cn_command_hq` |
| Paths | `game/assets/models/<units|buildings|props>/<id>.glb`, `game/assets/icons/<category>/<id>.png`, `game/assets/sprites/<category>/<id>_8dir.png` |

## Mobile budgets

| Asset | Triangles (LOD0) | Texture |
|---|---|---|
| Infantry squad (3–4 figures) | 1,500–3,200 | 256² shared atlas |
| Drone | 300–800 | 256² |
| Light vehicle | 800–2,000 | 512² |
| Tank / heavy vehicle | 1,500–3,000 | 512² |
| Helicopter / aircraft | 1,500–3,000 | 512² |
| Building | 1,000–5,000 | 1024² |
| Superweapon building | ≤ 6,000 | 1024² |

- Godot generates lower-detail LODs on import automatically.
- Textures compress to ASTC/ETC2 for mobile (`import_etc2_astc=true` in the project).
- Each asset should have one material plus `team_color`.

## Placeholder generator options

`blender/sf_generators.py` has one function per archetype. Options go in the asset's spec line.

| Archetype | Options |
|---|---|
| `tracked` | `length`, `width`, `height`; `turret` (false for engineers), `turret_scale`, `turret_offset`, `barrel_length` (0 = none), `barrel_radius`; `aps`, `cage`; `extras`: `dozer_blade`, `crane`, `antennas`, `rear_door`; `turret_extras`: `missile_box`, `sight` |
| `wheeled` | `length`, `width`, `height`, `axles`; `cargo`: `crates`, `armored`, `launcher`, `pods`, `laser`, `ew`; `extras` as for tracked |
| `infantry` | `figures`, `scale`; `weapon`: `rifle`, `launcher`, `drone_case` |
| `drone` | `size`; `wing` (true = small fixed-wing instead of a quadcopter) |
| `building` | `width`, `depth`, `height`; `style`: `block` (default), `bunker`, `trench`, `sam`; `details` for blocks: `mast`, `vents`, `garage`, `reactor`, `stacks`, `tanks`, `pad`, `dish`, `flag` |

Every model needs at least one `team_color` surface; the smoke test checks this. Drones are modeled at ground level, and the view lifts them 6 m.

## Workflow for one asset

1. **Spec:** add it to `blender/specs/placeholders.json` (size, archetype, options).
2. **Placeholder:** `tools/build_assets.sh --only <id>`. The generator builds a grey-box model, its icon and its manifest row.
3. **Hook it up:** point `game/data/units/<id>.json` → `visual.model` and `visual.icon` at the outputs. Run the tests.
4. **Final art:** an artist makes `art_source/<category>/<id>.blend` following the conventions above. Backlog P2-15 adds an export script for `.blend` files that writes the same outputs.
5. **Animation:**
   - Vehicles animate in Godot code (turret yaw, barrel pitch, wheels, rotors).
   - Infantry need a shared skeleton and a shared animation set: idle, walk, run, aim, fire, prone, two death variants, enter-building.
   - Source the animations from CC0 packs or animate them by hand (P2-16). Record every source in the manifest.
6. **Provenance:** every output file gets a row in `ASSET_MANIFEST.csv`. The script adds rows for generated files; add rows yourself for hand-made or third-party files.
7. **Check in the game:** run the sandbox and look at it at real zoom levels, on a phone if you can.

## Sources of art that are OK

- Original work by contributors (license CC BY-SA 4.0).
- CC0 packs (for example Kenney or Quaternius), logged with their source URL.
- CC BY 4.0 assets, logged with attribution.
- AI-generated assets only under the rules in [06-legal-and-licensing.md](06-legal-and-licensing.md): disclose the tool, check its terms allow this license, never prompt with "in the style of" an existing game or artist, and have a human review the result.

**Never use:** files from game installs or mods, ripped models, Mixamo or other assets whose terms forbid redistribution in an open repository, or real company logos.
