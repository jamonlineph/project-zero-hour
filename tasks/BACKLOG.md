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
- **Accept:** the preset exists. An agent with the SDK installed can export a debug APK headless with `godot --headless --path game --export-debug "Android" ../build/signal-front-debug.apk`.

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

### P1-24b · Guard and patrol orders — ⬜
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

### P1-30b · "material is null" errors under software OpenGL — ⬜
- **Seen:** rendering an `ai_duel` match for about 3:40 of game time with the Compatibility renderer on Mesa llvmpipe (Xvfb) logs 24–48 `Parameter "material" is null` errors (from `material_casts_shadows`, `material_is_animated`, `material_get_instance_shader_parameters`, `material_update_dependency`, in that order). They start soon after the first vehicle wrecks and right after new unit views are created. The game keeps running; nothing visibly breaks. Not seen in the first 1,500 frames.
- **Reproduce:** `xvfb-run -a godot --rendering-driver opengl3 --path game -- --scenario=ai_duel --screenshot=/tmp/x.png --screenshot-frames=3300`, then grep the output.
- **Suspects:** a material override or surface override material (wreck darkening in `UnitView.become_wreck`, team-color duplicates in `TeamColors.apply`, `UnitStatus` materials) reaching the renderer before it exists or after it was freed.
- **Accept:** the run above logs no such errors; check it on a real GPU too (Mobile renderer).

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

### P1-36 · Low-end renderer fallback — ⬜
- **Do:**
  - Detect weak or Vulkan-less devices and use the Compatibility renderer.
  - A low-quality preset.
  - Test on a low-end phone.
- **Accept:** runs at 30 fps or better on the low-end test device.

### P1-37 · Cross-device determinism check — ⬜
- **Needs:** P1-20, P0-12
- **Do:** a debug menu entry plays a golden replay and shows the final hash. Compare a phone (ARM) with a desktop (x86).
- **Accept:** identical hashes, recorded in PROGRESS.

### P1-EXIT · Phase 1 exit check — ⬜ (owner)
- **Accept:** a full 1v1 skirmish against AI v0 on a mid-range phone; 30 fps or better with 300 units; golden replays and the cross-device hash match.

---

## Phase 2: Vertical slice (US vs Russia)

### P2-01 · Drone endurance and return to launcher — ⬜
- **Needs:** P1-08, P1-04
- **Accept:** drones have `endurance_s`, return at 20%, and crash at 0; tests.

### P2-02 · Counter-drone weapons — ⬜
- **Needs:** P2-01
- **Accept:** laser (single target, unlimited ammo), microwave (cone area) and gun variants follow `combat.md`; tests.

### P2-03 · Jamming fields and spoofing — ⬜
- **Needs:** P2-01
- **Accept:** fields affect drones and guided weapons as specified; fiber-optic immunity; spoofing uses `SimRng`; tests, including determinism.

### P2-04 · Kill chain — ⬜
- **Needs:** P1-11
- **Accept:** `needs_spotter` weapons fire beyond their own vision only at spotted targets; losing the spotter breaks guided shots; tests.

### P2-05 · Upgrades system — ⬜
- **Needs:** P1-14
- **Accept:** global and per-unit upgrades from data; models show upgrade attachments by node name; tests.

### P2-06 · Active protection and cage armor — ⬜
- **Needs:** P2-05
- **Accept:** charges, interception chance, reload; cage reduces drone damage for the first N hits; tests.

### P2-07 · Interceptable strikes — ⬜
- **Needs:** P1-08
- **Accept:** missiles and strike aircraft are entities; air-defense sites spend interceptor stock; tests.

### P2-08 · Decoys — ⬜
- **Needs:** P1-11
- **Accept:** enemies see decoys as real units until close or scouted; decoys die in one hit; tests.

### P2-09 · Commander power tree (ranks 1–3, US and RU) — ⬜
- **Needs:** P1-18, P2-07
- **Accept:** a tree from data; spend points; power bar UI (mouse and touch); every rank 1–3 power from `commander.md` works; tests.

### P2-10 · Slice content data — ⬜
- **Needs:** P1-34
- **Accept:** all slice units and buildings have final first-pass numbers from `vertical-slice.md` in JSON; `ContentDb` validates them.

### P2-11 · Skirmish AI v1 — ⬜
- **Needs:** P1-31, P2-09
- **Accept:** easy and normal difficulty for US and RU; counter-building; uses powers; AI-vs-AI results logged.

### P2-12 · Map "Riverside" — ⬜
- **Needs:** P1-30
- **Accept:** a map per `vertical-slice.md` that is fair in AI-vs-AI runs (neither side wins more than 55% of 40 runs).

### P2-13 · Final art: US slice set — ⬜ (artist or agent + owner review)
- **Needs:** P2-15
- **Accept:** each US slice asset follows `04-art-pipeline.md`; icons rendered; manifest updated. Split into one task per asset if needed.

### P2-14 · Final art: Russia slice set — ⬜
- **Needs:** P2-15
- **Accept:** as P2-13.

### P2-15 · Export script for hand-made `.blend` files — ⬜
- **Accept:** `blender/export_blend.py` exports `art_source/**/<id>.blend` to `.glb` and renders icons and sheets with the same settings as the placeholders, then updates the manifest.

### P2-16 · Infantry skeleton and animations — ⬜
- **Accept:** a shared rig plus an animation set (idle, walk, run, aim, fire, prone, 2 deaths, enter building) from CC0 or original sources; a Godot `AnimationTree` hooks them to sim states.

### P2-17 · UI art pass — ⬜
- **Accept:** a Godot `Theme`, an OFL font, framed icons, readable at phone size.

### P2-18 · Audio pass — ⬜
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
| P3-01 | Complete US and Russia rosters ([units-and-buildings.md](../docs/design/units-and-buildings.md)) |
| P3-02 | China faction: roster, mechanics (repeat-build discount, swarm launchers, linked air defense, navigation station), art, AI preset |
| P3-03 | Superweapons for all factions, with countdowns and counterplay |
| P3-04 | Aircraft and airbases (ammo, rearming, helicopters) |
| P3-05 | Garrisoning buildings, and clearing them |
| P3-06 | Transports and firing ports |
| P3-07 | Crushing |
| P3-08 | Neutral capturable buildings |
| P3-09 | Stealth and detection |
| P3-10 | Mines, trenches and obstacles |
| P3-11 | Bridges (destructible, repairable) |
| P3-12 | Irregulars faction: roster, contracts, mobile base, fiber-optic drones, art, AI preset |
| P3-13 | AI v2: all factions, hard difficulty, personalities |
| P3-14 | LAN multiplayer (lockstep over ENet, input delay, desync reports) |
| P3-15 | Online multiplayer via a small open-source relay server (`server/`), lobby, reconnect |
| P3-16 | Map editor v1 (desktop-first) |
| P3-17 | Mod support (data packs that override JSON and assets) |
| P3-18 | Localization through translation keys and Weblate |
| P3-19 | Spreadsheet → JSON balance import tool |
| P3-20 | Accessibility options ([controls-and-ui.md](../docs/design/controls-and-ui.md)) |
| P3-21 | Turn on DCO sign-off once outside contributors join |
| P3-22 | Save and load |
| P3-23 | Maps 2–12 (three biomes) |
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
