# Maps and modes

## Map format (P1-30)

- A map is a folder: `game/data/maps/<id>/`. It holds:
  - `map.json`: size, players, start positions, supply sites, neutral buildings, triggers
  - `height.png`: 16-bit heightmap
  - `splat.png`: terrain texture weights
  - an optional `props.json`
- Sizes: 256×256 m (1v1), 384×384 m (2v2), 512×512 m (4 players).
- The sim gets an integer passability grid (2 m cells) and integer heights. The view builds a terrain mesh and decorations from the same files.

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
