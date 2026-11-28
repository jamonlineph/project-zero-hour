# Backlog

**How to use this file:** follow [AGENTS.md](../AGENTS.md) section 4. Take the first ⬜ task in the current phase whose dependencies ("Needs") are ✅. Mark it 🔄 with your tool name and date while you work, then ✅ when done. ⛔ means blocked, with the reason on the status line.

Every task has:
- **Goal:** what it achieves
- **Do:** steps and hints
- **Accept:** the acceptance criteria
- **Files:** where the work happens
- **Needs:** dependencies

Split big tasks into `P1-04a`, `P1-04b`, … before starting.

**Current phase: 0 (foundations), with device-free Phase 1 sim tasks allowed while the owner's device checks (P0-12, P0-13, P0-15) are pending.**

---

## Phase 0: Foundations

### P0-01 · Repo, plan docs and agent instructions — ✅ 2026-11-25 (Claude Code)
- **Accept:** `AGENTS.md`, tool pointer files, `docs/` (vision, roadmap, architecture, standards, pipelines, design, ADRs), `tasks/` exist and agree with each other.

### P0-02 · Deterministic sim core — ✅ 2026-11-25 (Claude Code)
- **Accept:**
  - `Fx` (16.16), `SimRng` (xorshift32), `SimHash`, `SimEntity` + `SimMover`, `MovementSystem`, `SimCommand` (move/stop, dict round trip), `SimWorld` (fixed tick, canonical command order, ownership validation, formation offsets).
  - Unit tests and determinism tests pass.

### P0-03 · Sandbox scene with camera, selection and orders — ✅ 2026-11-25 (Claude Code)
- **Accept:**
  - `main.tscn` spawns US vs RU placeholder units.
  - `RtsCamera` handles keys, wheel, middle-drag, edge pan and gestures.
  - `SelectionController` handles mouse (click, box, shift, double-click, right-click move, S stop) and touch (tap, tap-move, drag-pan, long-press box, double-tap type, pinch/twist/two-finger pan).
  - The HUD shows a status line.
  - The smoke test passes.

### P0-04 · Headless tests and smoke test — ✅ 2026-11-25 (Claude Code)
- **Accept:**
  - `tools/run_tests.sh` / `.ps1` import, run unit tests (script errors count as failures), then run the main-scene smoke test.
  - The smoke test checks that Blender models load with team colors.

### P0-05 · Blender placeholder pipeline — ✅ 2026-11-25 (Claude Code)
- **Accept:**
  - `tools/build_assets.sh` generates 7 placeholder `.glb` models, 256 px icons and optional 8-direction sprite sheets.
  - It updates `ASSET_MANIFEST.csv`.
  - Tested with Blender 5.3.0.

### P0-06 · Repo checks and CI workflow — ✅ 2026-11-25 (Claude Code)
- **Accept:**
  - `tools/check_repo.py` (banned file types, provenance, file size) passes.
  - `.github/workflows/ci.yml` runs the repo checks and the Godot tests on push and PR.
- **Note:** not yet run on GitHub (see P0-08).

### P0-07 · Publish the repo on GitHub — ✅ 2026-11-25 (owner + Claude Code: jamonlineph/project-zero-hour)
- **Goal:** the repo lives on GitHub so every AI tool can clone it.
- **Do (owner):**
  1. Create an **empty** repository (no README, license or .gitignore), private or public.
  2. Push this repo to it, or ask Claude Code in the original session to push.
  3. Set the default branch to `main`.
- **Accept:** `main` on GitHub matches the local history.

### P0-08 · First green CI run — ✅ 2026-11-25 (Claude Code: run 1 on main passed both jobs)
- **Needs:** P0-07
- **Do:**
  - Open the Actions tab and check that both jobs pass.
  - If the Godot download URL changed, fix `.github/workflows/ci.yml`.
  - If a job fails, reproduce it with `tools/run_tests.sh` and fix it.
- **Accept:** both CI jobs are green on `main`. Add a CI badge to `README.md`.

### P0-09 · GitHub housekeeping — 🔄 2026-11-25 (Claude Code: labels + issue templates done; branch protection needs the owner, steps in docs/07-ai-workflow.md)
- **Needs:** P0-08
- **Do:**
  - Protect `main` so CI must pass before merging (owner clicks; agent writes the steps).
  - Add issue templates (bug, task) under `.github/ISSUE_TEMPLATE/`.
  - Add labels: phase-0…5, sim, view, input, ui, art, audio, docs, good-first-task.
- **Accept:** templates committed; protection steps documented in `docs/07-ai-workflow.md`.

### P0-10 · Pick the final name — ⬜ (needs the owner's decision)
- **Do:**
  - The agent proposes 8 original names and, for each, checks:
    - existing games and Play Store apps with similar names
    - US and EU trademark databases (public search pages)
    - domain availability
  - The agent records its findings in `tasks/QUESTIONS.md`.
  - The owner picks one.
- **Accept:** the name is recorded in `docs/00-vision.md`. The project name in `game/project.godot` and README is updated (the folder and repo can keep the codename).

### P0-11 · Android export preset — 🔄 2026-11-25 (Claude Code: preset + CI debug APK; Gradle/AAB moved to P2-19)
- **Do:**
  - Write `game/export_presets.cfg` with an Android preset, following [docs/05-platforms.md](../docs/05-platforms.md):
    - Gradle build
    - `arm64-v8a` and `x86_64`
    - target SDK 36
    - non-resource include filter `data/*`
    - landscape orientation, resizable
    - app category game
  - Write exact owner steps in `docs/05-platforms.md`: install the Android SDK and JDK 17, Godot export templates, set the paths in Editor Settings, create a debug keystore.
  - No passwords or keystores in the repo.
- **Accept:** the preset exists. An agent with the SDK installed can export a debug APK headless with `godot --headless --path game --export-debug "Android" ../build/project-zero-hour-debug.apk`.

### P0-12 · Run on a real Android phone — ⬜ (owner + agent)
- **Needs:** P0-11
- **Do:**
  - Install the debug APK (USB, `adb install`, or by downloading it).
  - Test every touch gesture in `docs/design/controls-and-ui.md`.
  - Note the FPS shown in the HUD.
- **Accept:**
  - Sandbox runs. Every implemented touch gesture works.
  - Problems are logged as new tasks. Results are in `tasks/PROGRESS.md`.

### P0-13 · Googlebook check — ⬜ (owner + agent)
- **Needs:** P0-11
- **Do:**
  - On a Googlebook, or the Android Studio desktop emulator: resize the window during play, use the trackpad (tap, two-finger scroll, pinch), mouse and keyboard keys.
  - Confirm the HUD reflows and edge panning works.
- **Accept:** results are recorded and issues are filed as tasks.

### P0-14 · Desktop exports and build artifacts — 🔄 2026-11-25 (Claude Code: Linux + Windows presets, CI artifacts, release on v* tags; macOS still to do)
- **Do:**
  - Add Windows, Linux and macOS presets to `export_presets.cfg`.
  - Add a CI job that exports Linux and Windows builds on tags `v*` and uploads them as release artifacts. It must download the export templates matching `GODOT_VERSION`.
- **Accept:** pushing tag `v0.0.1` produces downloadable desktop builds.

### P0-15 · Visual check of the sandbox — ⬜ (needs a machine with a screen)
- **Goal:** The first session could only test headless, so check what the scene looks like.
- **Do:**
  - Run the game on a desktop. Check that:
    - the camera framing at the start shows both armies' approach
    - models face their direction of travel (front = +Z)
    - team colors appear on turret panels, vests and building bands
    - the selection rings are visible
    - the box-select overlay draws in the right place at different window sizes
  - Fix anything wrong.
  - Take a screenshot with the in-game F12 key (add it) and put it at `docs/img/sandbox.png` for the README.
- **Accept:** a screenshot is in the README; any fixes are covered by the smoke test where possible.

---

## Phase 1: Core RTS systems (placeholder art)

### P1-01 · Fixed-point angles and trigonometry — ✅ 2026-11-25 (Claude Code)
- **Goal:** angles in the sim without floats.
- **Do:**
  - Binary angles with 4096 units per turn.
  - `tools/gen_trig_table.py` generates `game/src/sim/trig_table.gd`: a constant quarter-wave sine table in Fx, 1025 entries.
  - `Fx.sin_a`, `Fx.cos_a`, `Fx.atan2_a(dy, dx)` (integer, error < 1 angle unit), `Fx.angle_diff`.
- **Accept:** tests compare against Python reference values for 64 sample angles; maximum errors are documented.
- **Files:** `game/src/sim/fx.gd`, `trig_table.gd`, `tools/gen_trig_table.py`, `game/tests/unit/test_fx_trig.gd`.

### P1-02 · Facing and turn rate — ✅ 2026-11-25 (Claude Code)
- **Needs:** P1-01
- **Do:**
  - `SimEntity.facing` (binary angle).
  - `SimMover.turn_rate` (data: `turn_rate_deg_per_s`).
  - Units turn toward their heading before moving faster than 25% speed. Infantry turn instantly.
  - The view uses sim facing (remove the view-only facing).
- **Accept:** tests for turn direction, arrival and no overshoot; determinism test still green.

### P1-03 · Map grid and passability — ✅ 2026-11-25 (Claude Code)
- **Do:**
  - `SimMap`: 2 m cells, passable flags, a building footprint layer, integer height (flat for now).
  - A temporary test map with rock obstacles, shared by the sandbox and tests.
- **Accept:**
  - Tests for cell lookups, footprint block/unblock, and conversion from world (Fx) to cell.
  - The sandbox rocks become sim obstacles (the view reads them from the map).

### P1-04 · Grid pathfinding — ✅ 2026-11-25 (Claude Code; the speed target is not met yet, see P1-04b)
- **Needs:** P1-03
- **Do:**
  - A* on the grid, 8 directions, no corner cutting, deterministic tie-breaking (f, then h, then cell index).
  - Path smoothing by line of sight.
  - A per-tick budget for searches, with queued requests.
  - `SimMover` follows waypoints.
- **Accept:**
  - Tests: around a wall, unreachable target (go to the nearest reachable cell), identical paths across runs.
  - Performance test: 50 paths per second on a 256×256 m map within 2 ms per tick on desktop.

### P1-04b · Faster pathfinding — ✅ 2026-11-26 (Claude Code: JPS + JPS+ tables; 2.4 ms worst, 0.09 ms typical on desktop)
- **Needs:** P1-04
- **Why:** measured in P1-04 (GDScript, desktop, Godot 4.7.2):
  - About 1 ms per typical 20–60 m search.
  - About 22 ms per worst-case search (corner to corner through a maze of walls on a 256 m map, ~1,800 cells expanded).
  - The P1-04 target was 50 searches per second within 2 ms per tick. Phones are 3–5× slower than desktops.
  - Until this lands, `PathingSystem.MAX_SEARCHES_PER_TICK` is 3.
- **Do:** pick one, measure, and record the result:
  - **(a)** Jump Point Search on the same grid (same rules: no corner cutting, deterministic tie-breaks).
  - **(b)** Move `Pathfinder._search` to a C++ GDExtension. Per ADR 0004 this needs a new ADR and must keep the integer rules and the same results.

  Also add a per-tick expansion budget so a single worst-case search is spread over several ticks.
- **Accept:**
  - `test_pathfinder` passes unchanged.
  - The worst-case search is under 3 ms on desktop.
  - A tick with 3 typical searches stays under 2 ms on desktop.
  - Numbers are recorded in PROGRESS.

### P1-05 · Group movement — ✅ 2026-11-26 (Claude Code: leader path shared by followers; layout kept within 12 m, grid otherwise; no flow field needed yet)
- **Needs:** P1-04
- **Do:**
  - Groups keep their relative layout: one path for the group, slot offsets.
  - Units arriving at the destination fan out.
  - Large groups (more than 12) may use a flow field.
- **Accept:** tests show units end in distinct slots near the target and don't stack.

### P1-06 · Separation and collision — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-04
- **Do:**
  - A deterministic separation pass using a spatial hash; pairs processed in sorted id order.
  - Buildings block movement.
  - Moving units nudge idle allies aside.
- **Accept:** tests: two units never overlap by more than 10% of their radius after 30 ticks; determinism test.

### P1-07 · Health, damage and death — ✅ 2026-11-26 (Claude Code)
- **Do:**
  - `SimWorld.apply_damage()`. Units die at hp ≤ 0 and are removed at the end of the tick.
  - `world.events` per tick (`died`, `fired`, `hit`) for the view and audio. The view must not mutate them.
  - Wreck props live in the view only.
- **Accept:** tests for death, removal order and events; the view removes dead units (smoke test extended).

### P1-08 · Weapons v1 — ✅ 2026-11-26 (Claude Code: splash hits enemies only; weapons act as turrets)
- **Needs:** P1-07, P1-09
- **Do:**
  - `game/data/weapons/*.json` (fields in [docs/design/combat.md](../docs/design/combat.md)) and a `SimWeapon` component.
  - Deterministic auto-targeting.
  - Reload timers.
  - Instant-hit and projectile entities (ballistic, guided) with travel time and splash.
- **Accept:** tests for range, reload, splash falloff, a target dying mid-flight, and determinism.

### P1-09 · Damage matrix and armor classes — ✅ 2026-11-26 (Claude Code)
- **Do:** `game/data/damage_matrix.json` with the values from `combat.md`. The loader validates that every pair exists. Damage goes through the matrix.
- **Accept:** tests for several pairs, and for a missing pair producing an error.

### P1-10 · Attack orders — ✅ 2026-11-26 (Claude Code: attack, attack-move, hold, stop; guard and the touch command bar moved to P1-24)
- **Needs:** P1-08
- **Do:**
  - Commands: attack target, attack-move, hold position, guard.
  - Input: A + click, H, G, and right-click on an enemy = attack.
  - Touch: a command bar placeholder.
- **Accept:** tests for each command; the smoke test orders an attack and sees damage.

### P1-11 · Vision and fog of war — ✅ 2026-11-26 (Claude Code: 8 m vision cells, teams share vision; enemy units hidden in the view; fog rendering is P1-27)
- **Needs:** P1-03
- **Do:**
  - A per-player visibility grid (visible, explored) updated every 3 ticks, with vision radius from data.
  - Targeting only hits visible enemies (except kill-chain rules later).
- **Accept:** tests for visibility, shared allied vision and the targeting restriction; determinism test.

### P1-12 · Buildings and construction — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-03, P1-07
- **Do:**
  - `game/data/buildings/*.json`. A builder component.
  - A place-building command that checks footprint, cost and prerequisites.
  - Construction progress, with several builders working together.
  - Sell for a 50% refund. Repair.
- **Accept:** tests for each rule. Sandbox: the player can build a barracks with the engineer, using a temporary debug key until P1-26.

### P1-13 · Production queues and rally points — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-12
- **Do:** queue up to 9 items, build time from data, cancel with a refund, rally point command, units spawn at the exit cell.
- **Accept:** tests for queue order, timing, cancel and rally.

### P1-14 · Tech prerequisites — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-12
- **Do:**
  - `requires` lists in data (buildings and later rank).
  - Validation in commands.
  - `ContentDb` checks that references exist.
- **Accept:** tests; data errors are reported clearly.

### P1-15 · Supply economy — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-12
- **Do:**
  - Supply sites (map data).
  - The gatherer loop as a state machine (go, load, return, unload).
  - Drop-off buildings and player credits; costs charged and refunded.
- **Accept:** tests for income, a depleted site, and gatherer retargeting; 10-minute determinism run.

### P1-16 · Power — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-12
- **Do:** `power` in building data; low-power effects (slower production; powered defenses off).
- **Accept:** tests.

### P1-17 · Veterancy — ✅ 2026-11-26 (Claude Code: pips in the view come with P1-22)
- **Needs:** P1-08
- **Do:** XP from cost-weighted damage, three ranks with bonuses (see [combat.md](../docs/design/combat.md)), and pips in the view.
- **Accept:** tests.

### P1-18 · Commander XP and rank — ✅ 2026-11-26 (Claude Code: thresholds in game/data/rules.json, to tune)
- **Needs:** P1-08
- **Do:** per-player XP and ranks 1–5 with the [commander.md](../docs/design/commander.md) pacing; HUD shows the rank. No powers yet.
- **Accept:** tests.

### P1-19 · Victory and defeat — ✅ 2026-11-26 (Claude Code: simple banner; full end screen with P1-32)
- **Needs:** P1-12
- **Do:** default rule (all buildings and builders destroyed), plus match-end events and an end screen.
- **Accept:** tests for both outcomes and for simultaneous elimination.

### P1-20 · Replays and golden replay tests — ✅ 2026-11-26 (Claude Code: F9 saves a replay; playback UI comes with P1-32)
- **Needs:** P1-08
- **Do:**
  - Replay file format: game version, content hash, seed, map, players, command log.
  - Save every match to `user://replays/`, with a playback mode.
  - `game/tests/replays/` with expected hashes; the test runner verifies them.
  - A regeneration tool.
- **Accept:** 3 golden replays pass; documented in `docs/08-testing-and-qa.md`.

### P1-21 · Lockstep scheduler (local) — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-20
- **Do:**
  - Refactor `SimRunner`: commands collect into per-tick batches per player, and tick T runs only when every player's batch for T exists (local players and AI fill theirs immediately).
  - Log a state hash every 15 ticks.
- **Accept:** tests with two simulated players and delayed batches.

### P1-22 · Unit views v2 — ✅ 2026-11-26 (Claude Code: smoke-tested headless; the screenshot from a machine with a screen is still owed, see P0-15)
- **Needs:** P1-02, P1-07
- **Do:**
  - Health bars (only when damaged or selected).
  - Veterancy pips.
  - Turret and barrel aiming using node names (`turret`, `barrel`).
  - Muzzle points (`muzzle_0`).
  - A death effect and a wreck.
- **Accept:** smoke test extended; screenshot in PROGRESS from a machine with a screen.

### P1-23 · Desktop controls complete — ✅ 2026-11-26 (Claude Code: control groups, Space+drag, bookmarks, hover and cursors; cursor images not yet seen on a screen)
- **Do:**
  - Control groups (Ctrl+1–9, 1–9, double-tap to jump).
  - Space + drag pan.
  - Camera bookmarks (F5–F8).
  - Hover highlight; cursor states for move and attack.
- **Accept:** behavior matches [controls-and-ui.md](../docs/design/controls-and-ui.md); tests where possible (controller-level).

### P1-24 · Touch controls complete — ✅ 2026-11-26 (Claude Code: touch bar, box mode, long-press radial menu; driven in the smoke test, not yet tried on a phone; guard and patrol split into P1-24b)
- **Do:**
  - Command bar (attack-move, stop, hold).
  - Group buttons (tap to select, long-press to assign).
  - Box-select toggle.
  - Long-press radial menu.
  - Deselect button.
- **Accept:** on a phone, every action in the touch table works; documented in PROGRESS.

### P1-24b · Guard and patrol orders — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-10, P1-24
- **Do:**
  - Sim: a GUARD order (stay near a unit or building, attack enemies that come close, return) and a PATROL order (move back and forth between two points, attack-moving).
  - Keys: G for guard (then click the target), and a "Patrol" entry in the radial menu and the command grid.
- **Accept:** tests for both orders, including determinism; docs/design/controls-and-ui.md updated.

### P1-25 · HUD v1 — ✅ 2026-11-26 (Claude Code: not yet checked on a real screen; phone tabs/collapsing come with P1-24)
- **Needs:** P1-13, P1-15, P1-16
- **Do:**
  - Credits, power and rank bar.
  - Selection panel with icons.
  - 3×4 build menu from data, with the grid hotkeys.
  - Production queue display.
  - A minimap drawn from sim data.
  - The phone, tablet and laptop layouts from `controls-and-ui.md`.
- **Accept:** works at 1280×720, 2400×1080 (phone) and in a resized window.

### P1-26 · Building placement UI — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-12, P1-25
- **Do:** a ghost preview with valid/invalid tint. On touch: place the ghost, drag to adjust, then confirm or cancel buttons.
- **Accept:** works with mouse and touch; tests for the validity rules (sim side).

### P1-27 · Fog rendering — ✅ 2026-11-26 (Claude Code: terrain shader plus minimap; smoke test checks hidden enemies and the fog texture)
- **Needs:** P1-11
- **Do:**
  - Feed the visibility grid to a texture and a terrain shader: black for unexplored, darkened for explored.
  - Hide enemy units outside vision.
  - Apply fog to the minimap.
- **Accept:** visual check plus a smoke test that enemy views are hidden when not visible.

### P1-28 · Effects v1 — ✅ 2026-11-26 (Claude Code: pooled particles and tracers; `effects_50` perf scenario; frame time on a phone not measured yet)
- **Needs:** P1-07
- **Do:** pooled `GPUParticles3D` for muzzle flash, tracer, explosion, smoke and death, within the mobile budget.
- **Accept:** no frame drop below budget in the performance harness with 50 explosions per second.

### P1-29 · Audio v1 — ✅ 2026-11-26 (Claude Code: 11 synthesized placeholder sounds from `tools/gen_sounds.py`; no music yet)
- **Needs:** P1-07
- **Do:**
  - Audio buses (master, sfx, ui, voice, music).
  - Pooled 3D players.
  - CC0 or original placeholder sounds for weapons, explosions and selection; log them in the manifest.
- **Accept:** sounds play on events; volume settings work.

### P1-30 · Terrain and map format v1 — ✅ 2026-11-26 (Claude Code: map folders with raw 16-bit heights, cliffs and water in the sim, terrain mesh in the view; splat textures and props come later)
- **Needs:** P1-03
- **Do:**
  - Map folder format ([maps-and-modes.md](../docs/design/maps-and-modes.md)).
  - Heightmap → terrain mesh (view) and integer heights/passability (sim).
  - One test map.
  - The sandbox loads it.
- **Accept:** tests for the loader; the view terrain matches sim heights.

### P1-30b · "material is null" errors under software OpenGL — ✅ 2026-11-28 (Claude Code: 72 → 0 errors in the 3,300-frame run; a real-GPU check is still for the owner)
- **Seen:** rendering an `ai_duel` match for about 3:40 of game time with the Compatibility renderer on Mesa llvmpipe (Xvfb) logs 24–48 `Parameter "material" is null` errors (from `material_casts_shadows`, `material_is_animated`, `material_get_instance_shader_parameters`, `material_update_dependency`, in that order). They start soon after the first vehicle wrecks and right after new unit views are created. The game keeps running; nothing visibly breaks. Not seen in the first 1,500 frames.
- **Reproduce:** `xvfb-run -a godot --rendering-driver opengl3 --path game -- --scenario=ai_duel --screenshot=/tmp/x.png --screenshot-frames=3300`, then grep the output.
- **Suspects:** a material override or surface override material (wreck darkening in `UnitView.become_wreck`, team-color duplicates in `TeamColors.apply`, `UnitStatus` materials) reaching the renderer before it exists or after it was freed.
- **Accept:** the run above logs no such errors; check it on a real GPU too (Mobile renderer).
- **Found (bisect, 3,300 frames each):** all effects off → 72 errors (particles are not it); no wreck darkening → 0; no team-color duplicates → 0. The errors came from the two together: `UnitView.become_wreck` set `material_override` on meshes whose surfaces held team-color duplicates (`TeamColors.apply`). The wreck look now swaps each surface's material instead (`set_surface_override_material`), which releases the duplicates cleanly → 0 errors. `smoke_main.gd` checks that wreck parts use no `material_override`.

### P1-31 · Skirmish AI v0 — ✅ 2026-11-26 (Claude Code: AI duel ends at about 5:00 game time; play it with `godot --path game -- --scenario=skirmish_vs_ai`)
- **Needs:** P1-13, P1-15, P1-10
- **Do:**
  - AI player in the sim using `SimRng` and commands only.
  - Build order from `game/data/ai/*.json`.
  - Gather, produce and attack in waves.
- **Accept:** a headless AI-vs-AI match reaches victory within 30 minutes of game time, with no errors, deterministically.

### P1-32 · Main menu, skirmish setup, pause — ✅ 2026-11-26 (Claude Code: one map and normal AI for now; more choices arrive with P2-11/P2-12)
- **Do:** scene flow: menu → setup (faction, color, AI, map, credits) → match → end screen → menu. Pause menu.
- **Accept:** smoke test drives the flow headless.

### P1-33 · Performance harness — ✅ 2026-11-26 (Claude Code: battle, march and view scenarios; CI gate on normalized medians; optimizations cut the sim from 34–79 ms to about 9–12 ms per tick on desktop, see P1-33b)
- **Do:**
  - `game/tests/perf/` scenes that spawn N units moving and fighting.
  - Record sim ms per tick and frame time.
  - CI fails on more than 20% regression against `perf_baseline.json`.
- **Accept:** baseline committed; documented.

### P1-33b · Sim within the phone budget at 300 units — ⛔ (waiting on Q-7 and a phone measurement)
- **Needs:** P1-33, P0-12
- **Do:**
  - Measure `tools/run_perf.sh` numbers on a mid-range phone (an export with the perf scenes, or the phone test from P1-37).
  - If over 8 ms per tick: follow the owner's answer to Q-7 (C++ GDExtension for separation and movement through a new ADR, or rule and scale changes).
- **Accept:** ≤ 8 ms per tick at 300 entities on the mid-range test phone; golden replays unchanged unless the owner approved a rule change.

### P1-34 · Placeholder art for the vertical-slice roster — ✅ 2026-11-26 (Claude Code: 35 models and icons; special abilities such as jamming, transport and endurance come with Phase 2)
- **Do:**
  - Add specs and data for every unit and building in [vertical-slice.md](../docs/design/vertical-slice.md).
  - Add archetypes if needed: a launcher truck, a helicopter for later.
  - Build them and hook them into `game/data`.
- **Accept:** all slice IDs have a model, an icon and a data file; tests pass.

### P1-35 · Settings — ✅ 2026-11-26 (Claude Code: from the main and pause menus; volumes take effect once P1-29 adds the audio buses)
- **Do:**
  - Settings: render scale, fps cap (30/60/unlimited), shadows, UI scale, key rebinding, edge-pan toggle, battery-saver preset.
  - Saved in `user://settings.cfg`.
- **Accept:** settings persist and apply live.

### P1-36 · Low-end renderer fallback — ⛔ code done 2026-11-26 (Claude Code); waiting on a low-end phone test (owner)
- **Do:**
  - Detect weak or Vulkan-less devices and use the Compatibility renderer.
  - A low-quality preset.
  - Test on a low-end phone.
- **Accept:** runs at 30 fps or better on the low-end test device.

### P1-37 · Cross-device determinism check — ⛔ code done 2026-11-26 (Claude Code); waiting on a phone run (owner, P0-12)
- **Needs:** P1-20, P0-12
- **Do:** a debug menu entry plays a golden replay and shows the final hash. Compare a phone (ARM) with a desktop (x86).
- **Accept:** identical hashes, recorded in PROGRESS.

### P1-EXIT · Phase 1 exit check — ⬜ (owner)
- **Accept:** a full 1v1 skirmish against AI v0 on a mid-range phone; 30 fps or better with 300 units; golden replays and the cross-device hash match.

---

## Phase 2: Vertical slice (America vs North Korea)

*Started 2026-11-26 at the owner's request, in parallel with the Phase 1 device checks (P1-EXIT).*

### P2-01 · Drone endurance and return to launcher — ✅ 2026-11-26 (Claude Code: drones also fly now: straight paths over any terrain)
- **Needs:** P1-08, P1-04
- **Accept:** drones have `endurance_s`, return at 20%, and crash at 0; tests.

### P2-02 · Counter-drone weapons — ✅ 2026-11-26 (Claude Code: microwave and airburst gun exist as weapon data for the Phase 3 rosters)
- **Needs:** P2-01
- **Accept:** laser (single target, unlimited ammo), microwave (cone area) and gun variants follow `combat.md`; tests.

### P2-03 · Jamming fields and spoofing — ✅ 2026-11-26 (Claude Code)
- **Needs:** P2-01
- **Accept:** fields affect drones and guided weapons as specified; fiber-optic immunity; spoofing uses `SimRng`; tests, including determinism.

### P2-04 · Kill chain — ✅ 2026-11-26 (Claude Code: recon drones spot; sniper and recon teams and satellite passes join when they exist)
- **Needs:** P1-11
- **Accept:** `needs_spotter` weapons fire beyond their own vision only at spotted targets; losing the spotter breaks guided shots; tests.

### P2-05 · Upgrades system — ✅ 2026-11-26 (Claude Code)
- **Needs:** P1-14
- **Accept:** global and per-unit upgrades from data; models show upgrade attachments by node name; tests.

### P2-06 · Active protection and cage armor — ✅ 2026-11-26 (Claude Code)
- **Needs:** P2-05
- **Accept:** charges, interception chance, reload; cage reduces drone damage for the first N hits; tests.

### P2-07 · Interceptable strikes — ✅ 2026-11-26 (Claude Code: strikes are launched by commander powers in P2-09)
- **Needs:** P1-08
- **Accept:** missiles and strike aircraft are entities; air-defense sites spend interceptor stock; tests.

### P2-08 · Decoys — ✅ 2026-11-26 (Claude Code: North Korea's decoy tank; deployed by its commander power in P2-09)
- **Needs:** P1-11
- **Accept:** enemies see decoys as real units until close or scouted; decoys die in one hit; tests.

### P2-09a · Commander powers in the sim — ✅ 2026-11-26 (Claude Code: power data, points, every rank 1–3 power for America and North Korea, plus North Korea's rank-5 decoys)

### P2-09b · Power bar and commander tree UI — ✅ 2026-11-26 (Claude Code: the bar may crowd the F1 help text on small screens; P2-17 UI pass)
- **Needs:** P2-09a
- **Accept:** a power bar (mouse and touch) with cooldowns; a commander panel to spend points; targeted powers aim with a click or tap; the minimap goes dark while blinded by a cyberattack.

### P2-09 · Commander power tree (ranks 1–3, America and North Korea) — ✅ 2026-11-26 (done as P2-09a and P2-09b)
- **Needs:** P1-18, P2-07
- **Accept:** a tree from data; spend points; power bar UI (mouse and touch); every rank 1–3 power from `commander.md` works; tests.

### P2-10 · Slice content data — ✅ 2026-11-26 (Claude Code: a test keeps data and doc in sync)
- **Needs:** P1-34
- **Accept:** all slice units and buildings have final first-pass numbers from `vertical-slice.md` in JSON; `ContentDb` validates them.

### P2-11 · Skirmish AI v1 — ✅ 2026-11-26 (Claude Code: results logged with `tests/tools/ai_matches.gd`; found a west-side advantage, see P2-11b)
- **Needs:** P1-31, P2-09
- **Accept:** easy and normal difficulty for America and North Korea; counter-building; uses powers; AI-vs-AI results logged.

### P2-11b · Find and remove the west-side advantage — ✅ 2026-11-26 (Claude Code: on Twin Ridge each side won 20 of 40; see P2-11c for faction balance)
- **Seen (2026-11-26, `ai_matches.gd`, normal vs normal on the sandbox map):** player 1 (west) won 8 of 8 as America and 6 of 6 when the factions were swapped (North Korea west), so it is a side bias, not faction balance. Making fire simultaneous within a tick (a real fairness fix, done in P2-11) did not change it.
- **Suspects:** the sandbox map is not mirrored (rocks, one contested supply site at x 86 instead of 88, the ridge centered at x 65); the AI's building-spot search tries east first, which is toward the front for the west player and toward the map edge for the east player; player 1's AI thinks one tick earlier.
- **Do:** test each suspect with `godot --headless --path game --script res://tests/tools/ai_matches.gd -- 10 normal normal [swap]`; fix the cause; P2-12's mirror-fair map will be judged with the same tool.
- **Accept:** on a mirrored map, neither side wins more than 55% of 40 runs.

### P2-11c · Faction balance: North Korea beats America in AI-vs-AI — ✅ 2026-11-27 (Claude Code: America won 18 and North Korea 20 of the 40 canonical runs; over 120 runs America 58%, east side 53%)
- **Seen (2026-11-26, Twin Ridge, normal vs normal, 40 runs):** North Korea won all 40, from either side. Side fairness is fine (P2-11b); this is balance or AI play.
- **Suspects:** America's preset spends on rocket artillery that needs spotters and on recon drones the AI doesn't use well; North Korea's cheaper squads, cage armor and Reserve Call-Up snowball; America's composite armor arrives later than North Korea's reactive armor.
- **Do:** try one change at a time and measure with `ai_matches.gd` (20 runs each way); prefer AI preset fixes before changing unit numbers (those must stay in sync with `vertical-slice.md`, see P2-10).
- **Accept:** neither faction wins more than 60% of 40 normal-vs-normal runs on Twin Ridge; final tuning comes from human playtests (P2-20).
- **Found:** the US AI never built recon drones (unarmed units weren't counted in its army), so its spotter-guided rocket artillery had no spotters; the AI also didn't count queued units and kept queueing the same type. Mirror matches (same faction on both sides) then showed two side biases: buildings with an odd width snapped 2 m east of the mirror point, and the AI had no randomness, so every seed replayed nearly the same game and tiny order effects decided all of them.
- **Fixed:** spotters join the army; queued units count; both AIs think on the same tick; footprint snapping and exit-cell ties go toward the map middle (mirror-fair); the AI has its own seeded rng (wave size ±1, first attack ±15 s, unit-mix and target noise). Tests: `test_fairness.gd`.

### P2-11e · Faction balance on Riverside — ✅ 2026-11-27 (Claude Code: Riverside North Korea 23 – America 17; Twin Ridge America 23 – North Korea 17; see P2-12b for a possible side effect)
- **Seen (2026-11-27, Riverside, normal vs normal, `ai_matches.gd ... map=riverside stats`):** sides are even, but North Korea won 29 of 39 runs, then 68 of 80 after the recon-drone cap. Matches last about 11 minutes (Twin Ridge: 5).
- **Found so far:** America's vehicle depot almost never builds. Its most-needed unit is usually rocket artillery (1300 credits); the depot waits to afford it while the barracks spend the credits first, so in 8 games America built 1 rocket artillery and 16 tanks against North Korea's 39 tanks (over 20 later games: 1 rocket artillery, 74 tanks against 147). Recon drones are still lost and replaced about 33 times a game even with at most 2 alive; check whether they crash at the end of their endurance while following attack-moves. North Korea's units cost 10–20% less, so its plant gets through more often.
- **Do:** make the AI save for its most-needed unit (choose for every idle factory first, then buy in order of need and stop when the top choice is unaffordable); then re-measure. Also check Reserve Call-Up (3 free squads every 3 minutes) over long games.
- **Accept:** neither faction wins more than 60% of 40 Riverside runs, and Twin Ridge stays within 60% too.
- **Done so far (2026-11-27):** factories save for the most-needed unit (`AiProduction`); recon drones stay over the army instead of leading it; America's preset attacks with the same wave as North Korea's (7 units, from 200 s). Powers are not the cause: with powers off for both, North Korea still won 16 of 19.
- **Measured:** Riverside 40 runs: North Korea 26, America 14 (65%); Twin Ridge 40 runs: 20–20. Every North Korean unit is 8–20% more cost-efficient on paper (hp × dps / cost²); cheaper American units (tank 900, squad 225, anti-tank team 375) gave 65% in a 20-run test. In the same 40 Riverside runs the west won 26 (player 1 is always west in these runs), so a player-order bias was checked with same-faction mirror matches on Riverside: west 21, east 18 over 39 (54%), so there is no side bias; the 65% was noise on top of the faction gap.
- **Cause found:** America's rocket artillery needs a spotter to fire beyond its own sight, and the AI's 2 recon drones hovered over the army's center. Tests (20 runs each): rockets without the spotter rule → America 13–7; unguided rockets with the rule (immune to jamming) → North Korea 15–5; so the spotter rule, not jamming, held America back. Cheaper American units broke Twin Ridge (America 30–10) and were rejected; no artillery for either side still left North Korea at 12–7.
- **Fix:** the AI's spotters fly 30 m ahead of the army toward its target while attacking (forward observers), and America's preset keeps 3 instead of 2 (`max_spotters`). 40 runs each: Riverside North Korea 23, America 17 (57.5%); Twin Ridge America 23, North Korea 17 (57.5%).

### P2-12b · Check Riverside side fairness with the new AI — ✅ 2026-11-27 (Claude Code: cause was the move formation always filling west to east; now it fills from the side facing the destination. Mirror runs west 43, east 35 over 78 (55%), from 100 of 157 (64%) before)
- **Seen (2026-11-27):** with the P2-11e AI, faction matches on Riverside went to the west 29 of 40 (65% and 72% in two batches), while same-faction mirror matches with the earlier AI were even (west 21, east 18). Player 1 is always west in `ai_matches.gd`.
- **Do:** run 40+ mirror matches per faction with the current AI (`ai_matches.gd` can't do mirrors yet; add a `mirror` option); if the west still wins more than 55%, find the cause as in P2-11b (mirror diffs) before changing the map.
- **Accept:** mirror and swapped faction runs both within 55% for either side.
- **Found:** a `mirror=<faction>` option and a `flip` option (player 1 in the east) in `ai_matches.gd`. Before the fix: mirror runs west 52 of 77, flipped west 48 of 80. Paths were symmetric (both sides use the same bridge), so the cause was elsewhere: `Formation.grid_offsets` filled the grid west to east for every move order, so a westward army formed up differently from an eastward one. `WorldCommands.move` now flips the grid toward the destination; `test_mirrored_groups_get_mirrored_formations` checks it. Golden replays and the determinism hash were regenerated (new hash 545746504).
- **After (20 runs per batch):** mirror America 10–9 (one draw), mirror North Korea 12–8, flipped America west 12–7, flipped North Korea west 9–11: west 43, east 35 (55%, inside the noise for 78 games).
- **Faction runs after the fix** (40, America against North Korea, both ways round): west 18, east 22; North Korea 26–14 (65%), against 23–17 in P2-11e. See P2-11f.

### P2-11f · Riverside faction balance after the formation fix — ⬜
- **Seen (2026-11-27):** after P2-12b, 40 Riverside runs went North Korea 26, America 14 (65%); P2-11e had 23–17. Over both batches North Korea won 49 of 80 (61%).
- **Also seen:** Desert Crossroads (40 runs) east 25, west 15, and North Korea 15–5 in faction games; Frostwood America 13–7 with even sides.
- **Do:** after P3-07 (crushing changes tank-versus-infantry fights), run 80 faction matches on Riverside and 40 on Twin Ridge and the new maps, and 40 more mirror matches on Desert Crossroads; if one faction wins more than 58% overall, find which unit pairing decides it (as in P2-11e) before touching prices.
- **Accept:** each faction within 42–58% over 80 Riverside runs, and no map beyond 60%.
- **2026-11-28 (Claude Code):** stats over 12 runs: both sides spend about the same, but North Korea builds far more tanks (108 vs 66 in 6 runs) while America answers North Korean infantry only with IFVs, which the tanks eat. North Korea also counters infantry with howitzers (splash). America's preset now counters infantry with IFVs and rocket artillery. Paired on the same 40 seeds: North Korea 25–15 before, 22–18 after (55%). Crushing changed no winner in 20 paired seeds.
- **Unarmed support (2026-11-28):** the AI only counted armed units and spotters as army, so it never counted medics, swarm trucks or jammers and kept building them (an EU AI had 10 medics by 5:00; the UAE overbuilt 1,300-credit swarm trucks). Everything built that moves now counts; unarmed support travels in the middle of the army.
- **Group speed (2026-11-28):** a mixed group now moves at its slowest ground member's pace (`SimMover.group_speed`, set by group move orders), so fast units no longer arrive alone. Same 20 seeds: America 8–12 before, 12–8 after. Still to do: 80-run check on all maps.

### P2-11d · Split `sim_world.gd` — ✅ 2026-11-27 (Claude Code: sim_world.gd 346 lines, content_db.gd 412; golden replays and the determinism hash unchanged)
- **Seen (2026-11-27):** `game/src/sim/sim_world.gd` is about 790 lines, almost twice the 400-line guideline.
- **Do:** move cohesive parts (spawning, placement and footprints, the spatial queries) into helper scripts without changing behavior; golden replays must stay unchanged.
- **Accept:** each file under about 400 lines; all tests pass with no replay regeneration.
- **Also:** `game/src/data/content_db.gd` is about 710 lines; split its loaders the same way.

### P2-12 · Map "Riverside" — ✅ 2026-11-27 (Claude Code: west 42, east 38 of 80 runs; North Korea dominates there, see P2-11e)
- **Needs:** P1-30
- **Accept:** a map per `vertical-slice.md` that is fair in AI-vs-AI runs (neither side wins more than 55% of 40 runs).
- **Result:** first 40 runs: west 22, east 17, 1 unfinished (56%, inside a 40-run sample's ±8% noise); after the AI's recon-drone cap and stall fix, 80 runs: west 42, east 38 (52.5%). Every skirmish map is an exact mirror (`test_maps.gd`).

### P2-13 · Final art: US slice set — ⬜ (artist or agent + owner review)
- **Needs:** P2-15
- **Accept:** each US slice asset follows `04-art-pipeline.md`; icons rendered; manifest updated. Split into one task per asset if needed.

### P2-14 · Final art: North Korea slice set — ⬜
- **Needs:** P2-15
- **Accept:** as P2-13.

### P2-15 · Export script for hand-made `.blend` files — ✅ 2026-11-27 (Claude Code: `tools/export_blend.sh`, provenance sidecar per file, self-test `tools/test_export_blend.sh`)
- **Accept:** `blender/export_blend.py` exports `art_source/**/<id>.blend` to `.glb` and renders icons and sheets with the same settings as the placeholders, then updates the manifest.

### P2-16 · Infantry skeleton and animations — ✅ 2026-11-27 (Claude Code: shared `squad_rig` with 9 generated animations in every infantry model; `InfantryAnimator` drives an AnimationTree from sim state; poses in `docs/screenshots/infantry/`)
- **Accept:** a shared rig plus an animation set (idle, walk, run, aim, fire, prone, 2 deaths, enter building) from CC0 or original sources; a Godot `AnimationTree` hooks them to sim states.

### P2-17 · UI art pass — ✅ 2026-11-27 (Claude Code: `UiTheme` with the OFL font Inter, framed panels and buttons, bigger command-grid buttons with icons and hotkey tags; screenshots in `docs/screenshots/ui/`)
- **Accept:** a Godot `Theme`, an OFL font, framed icons, readable at phone size.

### P2-18 · Audio pass — ✅ 2026-11-27 (Claude Code: 9 new generated effects, alerts wired to sim events, an original generated music track; all CC BY-SA, in the manifest)
- **Accept:** weapons, explosions, UI, acknowledgements, one music track; all in the manifest.

### P2-19 · Google Play internal testing — ⬜ (owner + agent)
- **Needs:** P0-11
- **Accept:**
  - A Gradle-build Android preset exports an AAB (`--install-android-build-template`), targeting SDK 36.
  - The owner has a Play developer account and the app is created with Play App Signing.
  - The first AAB is uploaded by hand.
  - A CI job uploads later builds to the internal track using repository secrets the owner sets up. No keys in the repo.

### P2-20 · Playtest program — ⬜ (owner)
- **Accept:** 5 or more testers, a feedback form, and bugs triaged into the backlog.

### P2-EXIT · Vertical slice exit check — ⬜ (owner)
- **Accept:** see [vertical-slice.md](../docs/design/vertical-slice.md).

---

## Phase 3: Production (epics: break into tasks before starting)

| ID | Epic |
|---|---|
| P3-01 | Complete America and North Korea rosters ([units-and-buildings.md](../docs/design/units-and-buildings.md)) — 🔄 2026-11-28 (Claude Code): anti-air vehicles for all four factions (`shorad`, guided anti-air missiles, from the vehicle factory; the AI counters aircraft with them); sniper team and infiltrators came with P3-09. Still to do: light vehicles, transport and fighter aircraft (P3-04b), the remaining buildings (tech, radar, close-in defense) |
| P3-02 | UAE faction: roster, mechanics (procurement, sovereign fund, swarm drones, desert raiders), art, AI preset — 🔄 split 2026-11-27 (Claude Code): **P3-02a** ✅ playable base roster (11 units, 8 buildings, weapons, 3 upgrades, rank 1/3/5 powers that use existing power kinds, placeholder art, `ae_default` AI preset, any-faction-vs-any skirmish menu); **P3-02b** ✅ sovereign fund (3% of unspent credits a minute, at most 300; `ae_unlock_fund` doubles the cap; `FundSystem`, `test_fund.gd`); **P3-02c** ✅ swarm-drone truck (`SimLauncher`, `LaunchSystem`: 5 drones at a visible ground enemy within 90 m every 40 s; `test_swarm.gd`); **P3-02d** ⬜ desert raiders' off-road speed (needs road/terrain types; until then raiders are simply fast); **P3-02e** ✅ procurement (2026-11-28, Claude Code: the Defense Procurement Office orders top-tier units at +30%, a cargo flight drops each off 30 s later and can be shot down; the "Emergency procurement" power (rank 1) halves the next wait; the UAE AI builds and uses both; `test_procurement.gd`); **P3-02f** 🔄 special-forces abilities ✅ (`AbilityDef`, USE_ABILITY, `AbilitySystem`: "Call Strike" and "Disable Building", HUD buttons, AI use; `test_abilities.gd`); the "Laser shield" power ⬜; **P3-02g** 🔄 balance the UAE with AI runs (2026-11-28: the real cause of its losses was a missing free truck on its logistics hub; after that fix the UAE won 74%, so its earlier buffs were rolled back in steps. Riverside, 20 runs against North Korea and America each: 74% → 20% → 35% → 55% (20 runs, 2026-11-28, before helicopters). Measure again with 40+ runs on all maps) |
| P3-03 | Superweapons for all factions, with countdowns and counterplay — ✅ v1 2026-11-28 (Claude Code): one building per faction (rank 3, limit 1) with a `superweapon` ability (4-minute charge, interceptable strikes anywhere), countdowns for everyone (`SuperweaponTimers`), "Launch" button, AI builds and fires them; `BuildingLoader` split out of `ContentDb`; `test_superweapons.gd`. Later: warning sounds and a target marker for the victim, a power-cut pause of the charge |
| P3-04 | Aircraft and airbases (ammo, rearming, helicopters) — 🔄 split 2026-11-28 (Claude Code): **P3-04a** ✅ attack helicopters (America, UAE, EU) and airbases, weapon `ammo`, `SimAircraft` + `AirSystem` (fly home empty, rearm, repair), small arms and autocannons can hit aircraft, AI builds an airbase and one helicopter; `test_aircraft.gd`; **P3-04b** 🔄 jets ✅ 2026-11-28 (Claude Code: `jet` aircraft fly home when their order is done and nothing is left to shoot, hold fire while parked; America's stealth fighter, the UAE and EU fighters, North Korea's strike jet and hardened airstrip; empty ammo weapons drop their targets; AI presets build them; `test_jets.gd`); left: strafing passes instead of hovering, transport helicopters (with P3-06) |
| P3-05 | Garrisoning buildings, and clearing them — ✅ v1 2026-11-27 (Claude Code): `GarrisonSystem`, GARRISON/UNLOAD commands, town houses as neutral buildings, bunkers and trenches hold 2, thermobaric clearing, right-click to enter, "Exit all", house flags, AI holds town houses; `test_garrison.gd`. Later: a garrison indicator on the minimap, transports (P3-06) |
| P3-06 | Transports and firing ports — ✅ v1 2026-11-28 (Claude Code): garrisons extended to own ground vehicles: IFVs (all factions) and the EU carrier hold 2 squads, passengers ride along, fire from inside, can't be shot, UNLOAD next to it, thrown out hurt when it dies; "Unload" button; `test_transports.gd`. Later: transport helicopters (with P3-04b), the AI using transports (P3-13c) |
| P3-07 | Crushing — ✅ 2026-11-27 (Claude Code): `CrushSystem`; main battle tanks (`"crusher": true`) run down enemy infantry touching their front while they move (100% max hp per second, `crush_percent_per_s`, damage type `crush` in the matrix); `test_crushing.gd`. Light obstacles wait for map props (P3-23d) |
| P3-08 | Neutral capturable buildings — ✅ 2026-11-28, split (Claude Code): **P3-08a** ✅ (`CaptureSystem`, `IncomeSystem`, CAPTURE command, building heal auras, `neutral_buildings` on Riverside, Desert Crossroads and Frostwood, AI `AiTactics.capture`, recolor on capture; `test_capture.gd`) capturing (infantry stand next to it for a few seconds; enemies can take it back), oil field (income), solar farm (power), field hospital (heals infantry), data center (sight), placed on the skirmish maps, AI captures; **P3-08b** ✅ rail depot (vehicles 25% faster) and cell tower (kill-chain spotter, 80 m), on all three big maps |
| P3-09 | Stealth and detection — ✅ v1 2026-11-28 (Claude Code): `StealthSystem` (detectors, 6 m proximity, 3 s after firing), targeting and view honor it; North Korea's infiltration team (stealthy, Sabotage = disable ability) and America's sniper team (45 m detection, spotter); recon drones detect at 30 m; `test_stealth.gd`. Not yet in the AI's unit mixes |
| P3-10 | Mines, trenches and obstacles — 🔄 2026-11-28 (Claude Code): **P3-10a** ✅ North Korea's minefield (walkable, stealthy, goes off once under an enemy ground unit; `MineSystem`; buildings can be `walkable`; `test_mines.gd`); **P3-10b** ⬜ tank obstacles (block vehicles, not infantry: passability per armor class), AI laying mines |
| P3-11 | Bridges (destructible, repairable) — ✅ v1 2026-11-28 (Claude Code): map decks are neutral walkable `bridge` buildings; only attack orders hit them; at 0 hp they collapse (units on the deck fall, the deck's cells are claimed so nothing crosses), and any side's builders repair them for free, reopening at 50% (`BridgeSystem`, `BridgeModel`, `test_bridges.gd`). Later: the AI doesn't blow or repair bridges yet |
| P3-12 | EU faction — 🔄 split 2026-11-28 (Claude Code): **P3-12a** ✅ playable base roster (13 units incl. combat medics and a patrol fighter, 8 buildings, 7 weapons, 3 upgrades, 5 powers incl. the new `repair_area` and `cyber_defense` kinds, healing auras (`HealSystem`), placeholder art, `eu_default` AI preset with medics kept in the middle of the army; `test_eu.gd`); **P3-12b** ✅ battlegroup doctrine (2026-11-28, Claude Code: three exclusive rank-1 doctrine powers (power `group`), each unlocks one unit and grants a passive upgrade (`grants_upgrade`, upgrades marked `granted`); the AI skips units it hasn't unlocked; `test_doctrines.gd`. Left: the rank-3 unlock for a second doctrine unit, and the air-assault helicopter drop, both after air transports); **P3-12c** ✅ interoperability (2026-11-28, Claude Code: `InteropSystem` once a second: an armed EU unit with 3+ armed unit types of its own within 25 m reloads 10% faster, 20% with `eu_unlock_interop` (rank 5; 15% made the EU win 75% against America); numbers in `rules.json`; selection panel hint; `test_interop.gd`); **P3-12d** 🔄 balance the EU with AI runs (2026-11-28: 85% after the free-truck fix → 80% → 60% after trimming health, medics (3%/s → 2%/s) and its range edge (tank 52 → 50 m, missiles 48 → 45 m); the tank is now 1,100 hp → 70% (20 runs); then the tank costs 1,150 and rifles 275. Measure again with 40+ runs on all maps) (old row: EU faction: roster, battlegroup doctrines, interoperability, field repair, art, AI preset) |
| P3-13 | AI v2: all factions, hard difficulty, personalities — 🔄 split 2026-11-28 (Claude Code): **P3-13a** ✅ "Hard" computer (no cheating on sight or income: thinks every 10 ticks instead of 15, runs 2 more trucks, attacks 30 s sooner with a slightly smaller first wave); Riverside, America and North Korea both ways, 20 runs: hard beat normal 14–6. A variant without the earlier attack won only 11–9. Menu cycles Easy, Normal, Hard; **P3-13b** ✅ personalities (2026-11-28, Claude Code: Balanced, Rusher, Turtle, Tech and Random in `game/data/ai/personalities.json`, applied by `AiPersonality` over any faction preset; "Style" in the skirmish menu; `test_personalities.gd`); **P3-13c** ⬜ AI uses transports, aircraft rearming and superweapon timing well |
| P3-14 | LAN multiplayer (lockstep over ENet, input delay, desync reports) — 🔄 split 2026-11-28 (Claude Code): **P3-14a** ✅ 1v1 over ENet (`NetSession`: host/join, the host sends the match, batches and hashes cross, desync and disconnect notices), "LAN game" screen, `smoke_lan.gd` in `tools/run_tests.sh`; **P3-14b** ⬜ up to 4 players and AI fill, adaptive input delay, reconnect, a replay saved on desync, a check on a real network with two phones |
| P3-15 | Online multiplayer via a small open-source relay server (`server/`), lobby, reconnect |
| P3-16 | Map editor v1 (desktop-first) |
| P3-17 | Mod support (data packs that override JSON and assets) |
| P3-18 | Localization through translation keys and Weblate |
| P3-19 | Spreadsheet → JSON balance import tool |
| P3-20 | Accessibility options ([controls-and-ui.md](../docs/design/controls-and-ui.md)) — 🔄 colorblind-safe team colors done 2026-11-27 (Claude Code); UI scale and key remapping exist; subtitles, hold-to-confirm and reduced shake wait for the features they apply to |
| P3-25 | Split `selection_controller.gd` (423 lines after P3-02f; guideline about 400): move armed-click handling (attack-move, patrol, guard, spoof, power, ability) into its own script — ✅ 2026-11-28 (Claude Code): `ArmedClicks` (absorbs `AbilityInput`); 394 lines |
| P3-21 | Turn on DCO sign-off once outside contributors join |
| P3-22 | Save and load — ✅ v1 2026-11-27 (Claude Code): a save is the replay plus the state hash; loading fast-forwards and checks the hash (`SaveGame`, `SaveLoader`, "Save game" in the pause menu, "Load game" in the main menu). Later: true snapshots if loading long matches is too slow on phones |
| P3-23 | Maps 2–12 (three biomes) — 🔄 split 2026-11-27 (Claude Code): **P3-23a** ✅ biomes in the view (`Biomes`, map `biome` field, obstacles drawn as rocks / mesas / pine forests, MultiMesh trees) and two 1v1 maps, Desert Crossroads and Frostwood (mirrored, every site and house reachable, `test_maps.gd`; 40 AI runs each before crushing: Frostwood sides 19–20, America 13–7 in faction games; Desert Crossroads east 25–15 and North Korea 15–5, rechecked in P2-11f); **P3-23b** 🔄 2v2 (2026-11-28, Claude Code: ✅ skirmish takes 4 players: you and a computer ally against two computers (`MatchConfig.skirmish_2v2`, Mode button in the menu, `ai_matches` plays 2v2 on four-start maps), ✅ first 2v2 map Pine Ridge (winter, 384×384 m); `test_skirmish_2v2.gd`. Left: more 2v2 maps, choosing the ally's and second enemy's factions, ally commands like "attack with me"); **P3-23c** 🔄 more 1v1 maps toward 12 in all, one feature each (2026-11-28, Claude Code: ✅ Three Bridges (desert, a canal with three destructible bridges) and ✅ Old Town (temperate, a city center of 32 garrisonable houses around a square with a data center); left: high ground and more, toward 12); **P3-23e** ⬜ side and player-order fairness on the new maps: mirror runs on Three Bridges had player 1 winning 37 of 58 (64%; the UAE mirror 16 of 20 in both orientations), Old Town's North Korea mirror went 9-1 to the west before contested captures (P3-23c fix), and flipped Riverside runs had the west winning 14 of 20. After the fix: Old Town west 11 of 26 (UAE 5-5, EU 4-4, North Korea 2-7), the Three Bridges UAE mirror 6-4. 10-run batches swing a lot (North Korea's mirror went 9-1, then 2-7), so measure with 40+ runs per mirror and `flip` before changing anything; **P3-23d** ⬜ props and textures (palms, boulders, snowdrifts, a splat map) |
| P3-24 | Open beta: Play open testing, F-Droid metadata, GitHub releases |

## Phase 4: Polish (epics)

| ID | Epic |
|---|---|
| P4-01 | Balance passes using AI-vs-AI statistics and beta replays |
| P4-02 | Low-end performance pass |
| P4-03 | Gauntlet mode (7 AI commanders with personalities) |
| P4-04 | Operations campaign (original story) |
| P4-05 | Store listing assets: screenshots, trailer captured in-game |
| P4-06 | Credits screen and legal notices |
| P4-07 | Legal review of the name and trademarks; privacy policy |
| P4-08 | Launch checklist ([08-testing-and-qa.md](../docs/08-testing-and-qa.md)) |

## Phase 5: Launch and live (epics)

| ID | Epic |
|---|---|
| P5-01 | 1.0 release on Google Play, F-Droid, GitHub and itch.io |
| P5-02 | Sub-faction variants |
| P5-03 | New nation design (candidates in [factions.md](../docs/design/factions.md)) |
| P5-04 | Community maps and tournaments |
