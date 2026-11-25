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

The loader (`ContentDb`) converts data units into sim units with integer math.

### Coordinates

Sim `(x, y)` maps to Godot `(x, 0, y)`, so sim Y is Godot +Z. The map runs from `(0, 0)` to `(map_width, map_height)`. Terrain height (from P1-30) is a separate integer heightmap. Models face +Z in Godot (`Vector3.MODEL_FRONT`), which is −Y in Blender.

### Entities, components, systems

- `SimEntity` holds the common fields: id, player, `def_id`, position, radius, hp.
- Optional **components** add capabilities: `mover` now; later weapon, producer, harvester, garrison, power, vision, drone and others.
- **Systems** are static functions over all entities that have a component, for example `MovementSystem.step(world)`.
- `SimWorld.step()` runs them in a fixed order:

1. Save `prev_x`, `prev_y` and `prev_facing` (for view interpolation).
2. Apply this tick's commands.
3. Movement: turn toward the heading, then move (later: pathing, then avoidance).
4. *(planned)* Targeting → weapons fire → projectiles → damage → deaths.
5. *(planned)* Production, construction, economy, power.
6. *(planned)* Vision and fog.
7. `tick += 1`

Keep this list in sync with the code whenever you add a system.

### Commands

`SimCommand` has these fields: `tick`, `player_id`, `seq`, `type`, `entity_ids`, `target_x/target_y` (later: `target_entity`, `def_id`, `flags`).
- The sim **validates** every command. It ignores entities that don't exist or don't belong to the player, and orders the player isn't allowed to give.
- Commands **serialize** with `to_dict()` and `from_dict()` for replays and networking. Every number is an int.

## 4. Replays and lockstep multiplayer (designed now, built in P1-20/21 and P3)

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
  - Turns to face its movement (view-only; sim facing arrives with P1-02).
- **Later:**
  - Health bars and veterancy pips.
  - Turret and barrel aiming through named nodes (`turret`, `barrel`, `muzzle_0`).
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

A save is a snapshot of `SimWorld` (all ints and strings) plus the command log since the last snapshot. Saves are versioned and include the content hash.

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
