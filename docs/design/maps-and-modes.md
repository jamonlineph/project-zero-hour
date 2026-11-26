# Maps and modes

## Map format (P1-30)

- A map is a folder: `game/data/maps/<id>/`, listed in `game/data/index.json` as `res://data/maps/<id>/map.json`. The folder name is the map id.
- `map.json` holds:
  - `width_m`, `height_m`; `obstacles_m` (blocked rectangles `[x, y, w, h]` in meters); `start_positions_m`; `supply_sites_m` (`[x, y, credits]`)
  - `height` (the height file, normally `height.r16`) and `height_scale_cm` (the height that the file's maximum value 65535 means)
  - `max_step_cm` (default 100): a cell more than this above one of its four neighbors is an impassable cliff edge. Only the upper cell is blocked, so the ground below a cliff stays open.
  - `water_level_cm` (optional): cells lower than this are deep water and impassable
  - `terrain_gen` (optional): hills and raised rocks that `tools/make_heightmap.py` turns into `height.r16`
- `height.r16`: raw 16-bit little-endian heights, one sample per 2 m cell, row by row from the map's (0, 0) corner. Raw bytes rather than a PNG, because Godot re-encodes imported images (to 8-bit textures); raw data is read exactly the same on every platform, which the deterministic sim needs.
- The sim gets integer heights (`SimMap.height_at`) and the passability grid; `TerrainView` builds the ground mesh from the same heights, so what you see is what the sim uses.
- Later: `splat.png` (terrain texture weights), `props.json` (decorations), neutral buildings and triggers.
- Sizes: 256×256 m (1v1), 384×384 m (2v2), 512×512 m (4 players). The sandbox is 128×128 m.

## Map design rules

- Each base starts with 1 safe supply site and a natural expansion.
- 2–4 contested supply sites, plus neutral buildings that make the middle worth fighting for.
- At least two attack paths into every base. No unreachable areas.
- Garrisonable civilian buildings and bridges in the middle create tactical choices.
- 1v1 maps must be mirror-fair. Check them with AI-vs-AI runs: neither start position may win more than 55% of the time.
- Biomes for 1.0: temperate farmland, desert town, winter forest.

## Modes

| Mode | Description | Phase |
|---|---|---|
| Sandbox | Developer scene (current) | 0 |
| Skirmish | You against 1–3 AI players; choose faction, color, team, difficulty, starting credits | 1 |
| Multiplayer | LAN (direct) and online (relay); 1v1 to 2v2, then up to 4 players; replays saved automatically | 3 |
| Gauntlet | Beat a ladder of 7 original AI commanders. Each has a personality (for example "Artillery Grinder", "Drone Swarmer") and fights on its own map | 4 |
| Operations | Short scripted missions per faction with objectives and briefings; original story set in a fictional 2026 crisis | 4 (may slip past 1.0) |

## Victory conditions

- Default: destroy all enemy buildings and builders.
- Options: destroy the HQ only; hold the center for a set time.
