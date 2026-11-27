# Screenshots

Captured on a machine without a GPU, through a virtual display and software OpenGL (see "Screenshots without a screen" in [../08-testing-and-qa.md](../08-testing-and-qa.md)). They use the Compatibility renderer, so lighting can differ slightly from phones.

| File | What |
|---|---|
| `main_menu.png` | Main menu |
| `skirmish_start.png` | Start of a skirmish against the computer (United States side) |
| `ai_duel.png` | Computer vs computer, a few minutes in |
| `sandbox_terrain.png` | The sandbox with terrain heights (P1-30) |
| `riverside_town.png` | Riverside (P2-12): the town on both banks of the river (`--watch=riverside --camera=128,128,90 --reveal`) |
| `riverside_bridge.png` | Riverside: the north bridge (`--camera=128,72,45`) |

## Gameplay phases (`gameplay_phases/`, 2026-11-27)

One computer-vs-computer match on Riverside, seen from North Korea's side (`--watch=riverside --side=kp --director --reveal --seed=1020 --speed=3`, recorded with Godot's movie writer; see `docs/08-testing-and-qa.md`). The video itself is not in the repo (27 MB); rebuild it with that command.

| File | Phase |
|---|---|
| `00_blender_models.png` | The art pipeline's start: every slice model built by `blender/build_assets.py`, lined up in Blender (America on top, North Korea below) |
| `01_main_menu.png` | Main menu with the map choice |
| `02_opening.png` | 0:05, opening: HQ, engineer and a supply truck (America's base) |
| `03_base_building.png` | 1:15, base building: power plants, barracks, vehicle plant |
| `04_army_gathers.png` | 3:15, the army gathers at the rally point |
| `05_river_crossing.png` | 3:45, crossing at the north bridge |
| `06_battle_at_the_river.png` | 4:30, a rocket barrage over the river |
| `07_assault_on_enemy_base.png` | 6:00, assault on America's base; the minimap reads "SIGNAL LOST" from America's cyberattack |
| `08_victory.png` | 7:23, victory screen |

All placeholder art: Blender grey-box models from `blender/build_assets.py`.
