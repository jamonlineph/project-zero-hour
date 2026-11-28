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

## Factions (`factions/`, P3-02a, P3-12a)

| File | What |
|---|---|
| `uae_base.png` | A UAE base on Desert Crossroads at 1:40, computer vs computer (`--watch=desert_crossroads --side=ae --enemy=kp`) |
| `uae_icons.png` | UAE build icons: 8x8 fighting vehicle, desert raider, tank, special forces, HQ, drone industry complex |
| `eu_base.png` | An EU base on Frostwood at 2:00, computer vs computer (`--watch=frostwood --side=eu --enemy=ae`, P3-12a) |
| `eu_icons.png` | EU build icons: tank, 8x8 carrier, truck howitzer, combat medics, MALE recon drone, vehicle works |

## Maps and biomes (`maps/`, P3-23a)

| File | What |
|---|---|
| `desert_crossroads_mesas.png` | Desert Crossroads: the west base and the sandstone mesas between the bases (`--watch=desert_crossroads --camera=96,180,90 --reveal`) |
| `desert_crossroads_oasis.png` | Desert Crossroads: the oasis town round its pond (`--camera=128,96,90`) |
| `frostwood_forest_lake.png` | Frostwood: pine forests, the village and the frozen lake (`--watch=frostwood --camera=128,120,170 --reveal`) |
| `frostwood_village.png` | Frostwood: the logging village between the northern bases (`--camera=128,80,90`) |

## Features (`features/`)

| File | What |
|---|---|
| `garrisoned_town_house.png` | Riverside, 0:49: North Korea's computer player holds an east-bank town house (red flag) (P3-05) |

## Infantry animations (`infantry/`, P2-16)

| File | What |
|---|---|
| `animation_poses.png` | The 9 shared animations on the rifle squad, rendered in Blender |
| `in_game_closeup.png` | Soldiers in a Riverside match: North Korean squads idle by the HQ, American soldiers aiming and running (enlarged crop) |

## UI art pass (`ui/`, P2-17)

| File | What |
|---|---|
| `main_menu.png` | Main menu in the new theme (Inter font, framed buttons, amber title); since P3-02a with "You" and "Enemy" side by side |
| `hud_engineer_selected.png` | In-game HUD with an engineer selected: framed top bar, minimap and selection panel, command grid with icons, costs and hotkey tags (`--select=us_engineer`) |
| `pause_menu.png`, `settings.png`, `commander_panel.png` | Overlays (`--open=pause`, `--open=settings`, `--open=commander`) |
| `load_game.png` | The load screen with two saves (P3-22, `--open=load`) |

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
