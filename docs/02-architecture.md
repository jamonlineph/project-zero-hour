# Architecture

## 1. Overview

```
 touch / mouse / keyboard / gamepad
              │
      input controllers (src/input)          selection = local UI state
              │  SimCommand (ints only)
              ▼
      SimRunner (src/main) ── lockstep scheduler: decides WHEN a tick may run
              │  queue_command(), step()
              ▼
      SimWorld (src/sim) ─── deterministic state + systems, fixed 15 ticks/s
              │  read-only
              ▼
  GameView / HUD / audio (src/view, src/ui) ── interpolated 3D presentation
```

**The one big idea:** the game state changes only inside `SimWorld.step()`, and only as a result of its previous state plus the commands for that tick. Same seed + same commands = same game, on every device. That gives us:
- **Replays for free:** the seed plus the command log.
- **Lockstep multiplayer:** players exchange only commands, not state.
- **Desync detection:** players compare `state_hash()`.
- **Fast headless tests and AI-vs-AI balance runs.**

## 2. Folder layout (`game/`)

| Folder | Contents | May use floats/Nodes? |
|---|---|---|
| `src/sim/` | `SimWorld`, entities, components, systems, `Fx`, `SimRng`, `SimHash`, `SimCommand` | **No** |
| `src/data/` | `ContentDb` and typed defs (`UnitDef` and so on) built from JSON | At load time only, converted to ints |
| `src/main/` | `main.gd` (scene wiring), `SimRunner` (fixed tick + scheduling) | Yes |
| `src/view/` | `GameView`, `UnitView`, `RtsCamera`, `TeamColors`, effects | Yes, read-only access to the sim |
| `src/input/` | `InputActions`, `SelectionController` (and later build placement, hotkeys) | Yes; produces commands |
| `src/ui/` | HUD, menus, overlays | Yes |
| `src/ai/` | Skirmish AI: reads the sim, issues SimCommands through the runner | **No** (same rules as the sim: it runs on every machine) |
| `data/` | JSON content plus `index.json` | — |
| `assets/` | `.glb` models, `.png` icons and sprites, audio (provenance lives in the root `ASSET_MANIFEST.csv`) | — |
| `tests/` | `run_tests.gd`, `smoke_main.gd`, `unit/test_*.gd` | Tests may use anything |

## 3. Simulation rules (determinism)

Code under `src/sim/` must obey all of these. Breaking any of them causes desyncs that are very hard to find later.

1. **Integers only.** Positions, speeds, distances and angles are fixed-point ints through `Fx` (16.16: the real value × 65536). No `float`, `Vector2`, `Vector3`, `Transform3D`, `Basis` or `Quaternion`. `Vector2i` is allowed only as a pair of ints whose values fit in 32 bits.
2. **No engine randomness or time.** Use `world.rng` (`SimRng`, xorshift32). Never call `randi()`, `randf()`, `RandomNumberGenerator`, `Time.*`, `OS.*` or `Engine.*`.
3. **No Nodes, scenes, signals, physics or navigation servers.** The sim is plain `RefCounted` classes.
4. **Canonical order.** Iterate entities through `world.entity_ids` (ascending id). Commands within a tick are applied sorted by `(player_id, seq)`. When the order of a Dictionary or of a search result could vary, sort it first.
5. **Input only through commands.** Nothing outside the sim mutates sim state. View code reads it.
6. **Integer math semantics.** `/` on ints truncates toward zero, and `>>` floors. Both behave the same on every CPU. Keep values within `Fx.MAX_ABS` before multiplying two fixed values.
7. **Hash what matters.** Every new piece of state is added to the entity or component `write_hash()`, so desync checks see it.

### Units of measure

| Quantity | In the sim | In data JSON |
|---|---|---|
| Position, radius, range | fixed-point meters | centimeters (`radius_cm`, `range_cm`) |
| Speed | fixed-point meters per tick | centimeters per second (`speed_cm_per_s`) |
| Time | ticks (15 per second) | milliseconds (`reload_ms`, `build_time_ms`) |
| Angles, facing | binary angle units, 4096 per turn; 0 = +X, 1024 = +Y | degrees (`turn_rate_deg_per_s`) |
| Health, cost, damage | plain ints | plain ints |
| Map size, obstacles | `SimMap` cells of 2 m (`SimMap.CELL`) | whole meters (`width_m`, `obstacles_m`) |

The loader (`ContentDb`) converts data units into sim units with integer math.

### Coordinates

Sim `(x, y)` maps to Godot `(x, 0, y)`, so sim Y is Godot +Z. The map runs from `(0, 0)` to `(map_width, map_height)`. `world.map` (`SimMap`) divides it into 2 m cells with a terrain-blocked layer and a building-footprint layer; cell `(cx, cy)` covers `[cx·2 m, (cx+1)·2 m)`. A building placed at a point gets the footprint centered nearest to it (`SimWorld.footprint_origin`); a point exactly between two choices goes toward the middle of the map, so mirrored maps give mirrored bases. Terrain height (from P1-30) is a separate integer heightmap. Models face +Z in Godot (`Vector3.MODEL_FRONT`), which is −Y in Blender.

### Entities, components, systems

- `SimEntity` holds the common fields: id, player, `def_id`, position, radius, hp.
- Optional **components** add capabilities: `mover` now; later weapon, producer, harvester, garrison, power, vision, drone and others.
- **Systems** are static functions over all entities that have a component, for example `MovementSystem.step(world)`.
- `SimWorld.step()` runs them in a fixed order:

1. Clear `events`; save `prev_x`, `prev_y` and `prev_facing` (for view interpolation).
2. Apply this tick's commands (`WorldCommands`, by player then sequence number).
2b. Orders: carry out MOVE / ATTACK / ATTACK_MOVE / HOLD / GUARD / PATROL (`OrderSystem`; GUARD and PATROL commands are applied by `UnitCommands`), then garrisons: units entering, occupants kept at their building, units coming out of destroyed buildings (`GarrisonSystem`, P3-05).
2b'. Drones: endurance, return to the launcher at 20%, recharge when docked, crash at 0 (`DroneSystem`). Flying movers get straight-line paths and are skipped by separation.
2b''. Jamming (`JammingSystem`): rebuilds the list of active jammers; enemy drones inside a field lose control and drift; spoofed drones fly to their spoofed point. Guided shots into a hostile field lose lock half the time (`CombatSystem`, via `SimWorld.jam_level`).
2b'''. Kill chain (`KillChainSystem`): rebuilds the list of active spotters (jammed or spoofed drones don't spot). `needs_spotter` weapons fire beyond their owner's own sight only at targets a spotter sees (`SimWorld.is_spotted`); guided kill-chain shots lose guidance in flight when the target stops being spotted.
2b''''. Strikes (`StrikeSystem`): missiles and strike jets launched by powers fly as entities; on arrival they deliver their payload (missiles end, jets fly back off the map).
2b'''''. Decoys (`DecoySystem`): enemy teams see through a decoy when one of their units comes within 15 m or a recon drone flies within 12 m; seen-through decoys are ignored by targeting.
2c. Base and economy: `PowerSystem`, the UAE sovereign fund (`FundSystem`, P3-02b: interest once a minute), `ConstructionSystem`, `ProductionSystem`, research (`Upgrades.step`, P2-05), `GatherSystem`.
3. Pathing: plan routes for movers that need one (`PathingSystem`, at most 8 searches per tick; group followers copy their leader's route).
4. Movement: turn toward the current waypoint, then move along the path.
5. Separation: push overlapping units apart without entering blocked cells (`SeparationSystem`).
5b. Vision: every 3 ticks, rebuild each team's visible cells (`SimVision`).
6. Combat (then `ProtectionSystem` recharges active protection, P2-06): rebuild the spatial index (`SpatialIndex`: 16 m buckets, plus a copy split by team so `query_enemies` never walks friendly units), then swarm launches (`LaunchSystem`, P3-02c: launchers with a visible ground enemy in range launch their drones), then crushing (`CrushSystem`, P3-07: moving tanks hurt enemy infantry touching their front), then targeting → firing → projectiles → damage (`CombatSystem`).
6b. Veterancy self-repair (`VeterancySystem`), then defeat/victory checks (`VictorySystem`); remove the dead.
7. `tick += 1`

Keep this list in sync with the code whenever you add a system.

`SimWorld` itself holds the state, the step order and small public helpers. The bulk of the work sits in helper scripts next to it (P2-11d): `WorldCommands` (applying commands), `WorldSpawn` (building entities from definitions), `WorldPlacement` (footprints and approach cells), `WorldDamage` (damage, deaths and experience) and `SpatialIndex` (area searches). On the data side, `ContentDb` loads the index and keeps the shared JSON helpers; `UnitLoader`, `MapLoader` and `PowerLoader` load units and weapons, maps, and powers, strikes and upgrades.

### Commands

`SimCommand` has these fields: `tick`, `player_id`, `seq`, `type`, `entity_ids`, `target_x/target_y` (later: `target_entity`, `def_id`, `flags`).
- The sim **validates** every command. It ignores entities that don't exist or don't belong to the player, and orders the player isn't allowed to give.
- Commands **serialize** with `to_dict()` and `from_dict()` for replays and networking. Every number is an int.

## 4. Replays and lockstep multiplayer (replays and the local scheduler built in P1-20/21; networking in P3)

- **Replay file:** game version, content hash, seed, map, players, and the command log. Playing it back runs the same sim.
- **Lockstep:** each client sends its commands for tick `T + delay`.
  - Tick `T` runs only once every player's commands (possibly an empty list) for `T` have arrived.
  - Input delay adapts to latency: 2–6 ticks (133–400 ms) on mobile networks.
- **Desync detection:** every 15 ticks, clients exchange `state_hash()`. On a mismatch, both save a replay plus a state dump for debugging.
- **Transport:**
  - A small relay server, because phones are almost always behind NAT.
  - LAN games use direct UDP.
  - We'll use Godot's ENet or WebSocket peers.
- **Cheating:** lockstep can't hide information, so map hacks are possible. Accept this for an open-source game and focus on fairness through server-side replay checks for ranked play later.

## 5. The view

- **`GameView`:** one `UnitView` per entity. It creates and frees them as entities appear and disappear, and interpolates between `prev` and current positions using `SimRunner.alpha`.
- **`UnitView`:**
  - Loads the `.glb` from the unit's data. If the model doesn't exist yet, it falls back to a placeholder shape.
  - Recolors materials named `team_color`.
  - Draws the sim facing, interpolated between ticks.
  - Health bar (when damaged or selected) and veterancy pips (`UnitStatus`).
  - Turret and barrel aiming through named nodes (`turret`, `barrel`); shots flash at `muzzle_0`.
  - Destroyed vehicles and buildings leave a dark wreck that sinks away after 20 s.
- **Fog of war (`FogOfWar`):** copies the local team's visible and explored layers into a small texture (one texel per 8 m vision cell). Terrain materials made by `FogOfWar.make_material()` darken under it. Enemy views are hidden outside vision; neutral entities appear once their ground is explored.
- **Later:**
  - Effects through pooled particles.
  - `MultiMeshInstance3D` for infantry and drones when counts are high.
  - Imported LODs (automatic) and distance-based impostor sprites if needed for low-end phones.
- **Camera:** `RtsCamera` is a focus point plus an orbiting `Camera3D` at a fixed pitch, with zoom and rotation, clamped to the map.

## 6. Input and UI

- Input controllers turn device events into **intents**: select, order, pan, zoom. They change local selection or submit `SimCommand`s through `SimRunner.submit()`.
- Touch and mouse are first-class equals. See [design/controls-and-ui.md](design/controls-and-ui.md).
- UI uses Godot `Control` nodes with anchors and containers, so it reflows when a Googlebook window is resized.

## 7. Content data

- JSON files under `game/data/` (`units/` now; `weapons/`, `buildings/`, `factions/`, `maps/`, `damage_matrix.json` later).
- Every file is listed in `data/index.json`, because exported games can't list folders reliably.
- **Export note:** the Android and desktop export presets must include `data/*` as non-resource files (P0-11).
- `ContentDb` validates required fields, checks that numbers are whole, converts to sim units, and reports all errors at once.
- **Content hash** (P1-20): a hash of all loaded data, included in replays and the multiplayer handshake, so different data can't play together.

## 8. Saving and loading (P3)

A save (P3-22, `SaveGame`) is the match's replay (scenario, seed, content hash, every command so far) plus the state hash at the moment of saving. Loading (`SaveLoader`) rebuilds the match and fast-forwards: human players' recorded commands are fed back, AI players think again (deterministic, so they reach the same plans), and the final state hash must match. Nothing can be forgotten this way; the cost is loading time for long matches. Saves are versioned (`save_format`). A true snapshot format can replace this later if loading is too slow on phones.

## 9. Performance budgets

These are summarized here; details are in [05-platforms.md](05-platforms.md).

| Budget | Target |
|---|---|
| Sim | ≤ 8 ms per tick with 300 entities on a mid-range phone |
| Frame rate | 60 fps target, 30 fps floor on low-end devices |
| Draw calls | < 300 |
| Triangles on screen | < 300k |
| Memory | < 1.5 GB |

## 10. How to add a sim feature (checklist)

1. Write or extend the design in `docs/design/` if the behavior isn't specified.
2. Add data fields (JSON) and loader support (`ContentDb` and the def class), with validation.
3. Add a **component** class in `src/sim/components/`, with `write_hash()`.
4. Add a **system** in `src/sim/systems/` and call it from `SimWorld.step()` in the documented order. Update section 3 of this doc.
5. If players trigger it, add a **command type** with validation.
6. Add **tests**: behavior tests, plus a determinism test if randomness or ordering is involved.
7. Add the **view** side (read-only) and the **input/UI** side (commands).
8. Update `tasks/BACKLOG.md` and `tasks/PROGRESS.md`.
