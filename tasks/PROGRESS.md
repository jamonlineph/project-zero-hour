# Progress log

Newest entry at the top. Every session adds one entry using the template in [AGENTS.md](../AGENTS.md) section 8.

---

## 2026-11-26: P2-06 Active protection and cage armor (Claude Code, branch claude/phase-0-wrapup)
- Done: America's tank carries 2 active-protection charges. When a guided anti-tank missile or loitering munition comes within 12 m, a charge fires and destroys it 90% of the time (`SimRng`); charges reload one every 20 s. North Korea's tank has cage armor: the first 2 drone hits (loitering munitions, or anything fired by a drone) do 25% damage. The IFV kits from P2-05 use the same rules. Interceptions flash and make a sound. New `ProtectionSystem` (recharge after combat), `drone_attack` weapon field, `aps_charges` and `cage_hits` unit fields.
- Golden replays and the determinism-check hash were regenerated: tanks now carry protection state, which is part of the state hash. Fights in those replays use only cannons and rifles, which active protection ignores, so the outcomes are the same. The phone determinism check now expects **4002681017**.
- Tests: `tools/run_tests.sh` -> 201 tests, 0 failed (new `test_protection.gd`: data, about 90% interceptions with one charge each, no charges no interception, reload, unguided shots ignored, cage only on the first drone hits, loitering munitions count as drone hits, IFV kit, determinism).
- Not verified: balance.
- Next: P2-07 interceptable strikes.
- For the owner: the determinism-check number for the phone test changed to 4002681017.

---

## 2026-11-26: P2-05 Upgrades system (Claude Code, branch claude/phase-0-wrapup)
- Done: upgrades are data (`game/data/upgrades/`). **Global** upgrades are researched at a building (costs credits, takes time, half speed on low power) and apply to every matching unit, existing and future. **Per-unit kits** are bought for selected units. Effects: speed, health, damage, range and vision percentages, plus active-protection charges and cage hits (used by P2-06). Requirements: buildings, commander rank, faction. Six slice upgrades:
  - America: Self-Driving Logistics (rank 5), Composite Armor, and an Active Protection Kit for the IFV.
  - North Korea: Reactive Armor, Extended-Range Shells, and a Cage Armor Kit for the IFV.
- Controls and view: a selected building shows its research buttons (with progress), and selected units show kit buttons in the top row of the grid. Model parts named `upg_*` stay hidden until owned; the two IFVs were rebuilt with kit parts.
- Tests: `tools/run_tests.sh` -> 193 tests, 0 failed (new `test_upgrades.gd`: loading, research time, cost and effects on old and new units, rules, low power, kits per unit, building requirement, range, round trip, determinism); smoke_main buys a kit through the grid and checks the part appears.
- Not verified: balance and button text length on phones.
- Next: P2-06 active protection and cage armor.
- For the owner: none.

---

## 2026-11-26: P2-04 Kill chain (Claude Code, branch claude/phase-0-wrapup)
- Done: America's rocket artillery now fires guided rockets that need a spotter: beyond its own 40 m sight it only fires at targets a friendly spotter (the recon drone, for now) can see. A tank seeing the target isn't enough. If the spotter dies, is jammed or is spoofed, rockets already in the air lose guidance and fly to the last known point. New `spotter` (units) and `needs_spotter` (weapons) data fields and a `KillChainSystem`.
- Fixed along the way: jammed drones were drifting at full speed (a new drift point every time they reached the last one); they now drift one 2 m step a second and hover in between.
- Tests: `tools/run_tests.sh` -> 184 tests, 0 failed (new `test_kill_chain.gd`: data, no spotter no fire, spotted targets hit at 100 m, own sight needs no spotter, jammed spotters don't count, guidance lost when the spotter dies, determinism). The audio test now expects the missile sound for the guided rocket pod.
- Not verified: balance; there is no UI hint yet showing which targets are spotted (a P2-17 UI pass item).
- Next: P2-05 upgrades system.
- For the owner: none.

---

## 2026-11-26: P2-03 Jamming fields and spoofing (Claude Code, branch claude/phase-0-wrapup)
- Done: North Korea's EW vehicle now projects a 40 m jamming field (shown as a purple ring). Enemy drones inside lose control: they hover and drift, can't fire, ignore orders, and crash if their endurance runs out before they drift clear. Guided missiles fired at targets inside a hostile field lose lock half the time and scatter 4–10 m (deterministic `SimRng`). Fiber-optic drones are immune. The vehicle's **Spoof** button (then click a point up to 70 m away, every 30 s) sends enemy drones in a 25 m area to random points for 5 s; armed ones attack a random nearby entity, which can be their own side. New `SimJammer` component, `JammingSystem`, and a `SPOOF` command. Jammer state is hashed only where it exists, so golden replays still match.
- Tests: `tools/run_tests.sh` -> 177 tests, 0 failed (new `test_jamming.gd`: data, loss of control, own side and range, crash, no firing, fiber-optic immunity, about half of guided shots lose lock, unguided unaffected, spoof radius, range and cooldown, spoofed friendly fire, determinism, command round trip); smoke_main checks the Spoof button end to end.
- Not verified: balance; how the ring reads at phone size.
- Next: P2-04 kill chain (America's long-range weapons need spotters).
- For the owner: none.

---

## 2026-11-26: P2-02 Counter-drone weapons (Claude Code, branch claude/phase-0-wrapup)
- Done: three counter-drone weapon kinds. The laser (America's laser vehicle) is a single-target, drone-only weapon drawn as a cyan beam. A new `cone_deg` field makes microwave emitters (`hpm_emitter`) hit every drone inside a cone. An airburst gun (`cuas_airburst_gun`) uses splash against drone groups. Splash now only hurts what a weapon can target, so artillery no longer damages drones flying over its impact point. The microwave and the gun are weapon data for the Phase 3 rosters (UAE, EU); no slice unit carries them yet.
- Tests: `tools/run_tests.sh` -> 166 tests, 0 failed (new `test_counter_drone.gd`); golden replays unchanged.
- Not verified: balance.
- Next: P2-03 jamming fields and spoofing (North Korea's jamming vehicle).
- For the owner: none.

---

## 2026-11-26: P2-01 Drone flight, endurance and return (Claude Code, branch claude/phase-0-wrapup)
- Done: Phase 2 started at the owner's request. Drones now fly: they take a straight line over rocks and cliffs and don't push or get pushed by ground units. Each drone has an endurance (America's recon drone 90 s, North Korea's 120 s). At 20% it flies back to the building that made it, ignoring other orders, and recharges there (full in 10 s); docked drones settle onto the pad in the view. Without a launcher, a drone crashes when its endurance runs out. New `SimDrone` component and `DroneSystem` (after `OrderSystem`). Drone state is hashed only for drones, so the golden replays still match.
- Tests: `tools/run_tests.sh` -> 161 tests, 0 failed (new `test_drones.gd`: data, straight flight over a wall, no pushing, crash, return and recharge, returning drones ignore orders, produced drones remember their launcher, determinism).
- Not verified: how it feels in play; the endurance isn't shown in the HUD yet (comes with the P2-17 UI pass).
- Next: P2-02 counter-drone weapons, then P2-03 jamming.
- For the owner: none.

---

## 2026-11-26: Owner decisions applied: name, factions, art direction (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **Name:** the game is now **Project Zero Hour** everywhere (menu, project, Android package `io.github.jamonlineph.projectzerohour`, build file names, docs, credits). A trademark and store-name check (P0-10) is still required before any store release, because "Zero Hour" is also the name of the game this one is inspired by (see Q-1).
  - **Factions:** America (`us`), the UAE (`ae`), North Korea (`kp`) and the EU (`eu`) replace the China, Russia and Irregulars drafts. New faction designs, rosters, buildings, superweapons and power trees in `docs/design/`. The Russia slice roster became North Korea's (`ru_*` ids renamed to `kp_*`, models and icons rebuilt with the new palette), so the vertical slice is **America vs North Korea**. The UAE and the EU are designed and scheduled for Phase 3 (P3-02, P3-12).
  - **Art direction:** "classic 2000s military RTS look" in `docs/04-art-pipeline.md`, with the originality boundary spelled out (nothing traced or recreated from other games).
  - Golden replays and the determinism-check hash were regenerated, because unit ids are part of the state hash. Behavior did not change; only the ids did.
- Tests: `tools/run_tests.sh` -> 153 tests, 0 failed; `python3 tools/check_repo.py` -> ok.
- Not verified: the in-game menu title on a real screen.
- Next: same as before: device checks (owner), then Phase 2.
- For the owner: Q-2, Q-4, Q-5 and Q-7 are still open. The determinism check's expected value changed with the ids: the phone should now show the hash in `game/data/determinism_check.json`.

---

## 2026-11-26: P1-36 and P1-37 code parts (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **P1-36:** the project falls back to the OpenGL (Compatibility) renderer on devices without Vulkan (`rendering_device/fallback_to_opengl3`). Settings has a quality preset (Low: 67% resolution, no shadows, 30 fps; Medium; High). On first run, devices on the fallback renderer or with under about 4.5 GB of memory start on Low.
  - **P1-37:** Settings > Developer > "Determinism check" plays a fixed AI-vs-AI match (`data/determinism_check.json`: ai_duel, seed 7, 1,800 ticks) and shows whether its final state hash equals the desktop's (2876121879). A unit test keeps the stored hash honest; `tools/regen_golden_replays.sh` updates it with the golden replays.
- Tests: `tools/run_tests.sh` -> 153 tests, 0 failed; smoke_menu runs the in-game determinism check and gets "Match".
- Not verified, and how the owner can finish both tasks:
  1. Install the debug APK from the latest CI run (Actions > newest run > artifact "android-debug-apk") on a phone.
  2. Open Settings > Developer > Determinism check > Run. "Match: 2876121879" means P1-37 passes; write the phone model and result in PROGRESS. "MISMATCH" means the sim differs on ARM; open an issue with the number shown.
  3. On a low-end phone, play a skirmish for 5 minutes on the Low preset and note whether it stays smooth (30 fps or better). That is P1-36's check.
- Next: P0-12, P0-13 and P0-15 device checks (owner), then P1-EXIT. Device-free Phase 2 work can start meanwhile.
- For the owner: the device steps above, plus Q-1 to Q-7.

---

## 2026-11-26: P1-24b Guard and patrol orders (Claude Code, branch claude/phase-0-wrapup)
- Done: two new sim orders and commands. PATROL attack-moves to the far end and back, forever; each unit patrols between its own start and the place it reached, and stops to fight on the way. GUARD keeps armed units within 6 m of an own or allied unit or building, attacks the nearest visible enemy within 25 m of it (chasing only inside that radius), and ends when the ward dies. Controls: G then click (or the Guard button) to guard; the Patrol button then click; radial menu "Patrol here" and "Guard this"; right-click cancels a pending order. The patrol's far end only enters the state hash while a unit patrols, so golden replays recorded earlier still match.
- Tests: `tools/run_tests.sh` -> 150 tests, 0 failed (new `test_orders.gd`: back and forth, fights on the way, guard follows, guard attacks only near its ward, ends when the ward dies, can't guard an enemy, command round trip, determinism); smoke_main orders a guard and a patrol through the real click path.
- Not verified: on a phone.
- Next: P1-30b (renderer errors under software OpenGL); then the Phase 1 checks only the owner can do.
- For the owner: none.

---

## 2026-11-26: P1-30 Terrain and map format v1 (Claude Code, branch claude/phase-0-wrapup)
- Done: maps are folders (`game/data/maps/<id>/map.json` plus `height.r16`, raw 16-bit heights, one per 2 m cell). The sim gets integer heights; a cell more than `max_step_cm` above a neighbor is an impassable cliff edge, and cells under `water_level_cm` are water. `TerrainView` builds the ground mesh from the same heights (colored by slope and height, darkened by fog). Units, rocks, effects, move markers and the placement ghost sit on the terrain, and mouse and touch picking follow the hills. The sandbox is now a map folder with gentle hills and raised rocks inside its obstacle rectangles, so passability is unchanged (golden replays still match). `tools/make_heightmap.py` builds `height.r16` from `terrain_gen` in `map.json`.
- Tests: `tools/run_tests.sh` -> 142 tests, 0 failed (new `test_terrain.gd`: loader, exact scaling, bad file size, cliffs, water, sandbox passability unchanged, terrain mesh equals sim heights); smoke_main checks every unit stands on the drawn terrain.
- Not verified: hills steep enough to matter in play (the sandbox's are gentle on purpose); splat textures and props are not in yet.
- Found while rendering: renderer errors "material is null" late in long matches under software OpenGL. Logged as P1-30b with reproduction steps.
- Next: P1-24b guard and patrol, P1-30b, then the owner-only Phase 1 checks (P0-12, P0-13, P0-15, P1-36, P1-37, P1-EXIT).
- For the owner: none new.

---

## 2026-11-26: First real renders; P1-28 Effects; P1-29 Audio (Claude Code, branch claude/phase-0-wrapup)
- **First real look at the game.** A Godot build with OpenGL now runs on this machine through a virtual display and Mesa's software renderer, so the game was rendered for the first time (`docs/screenshots/`). New `--screenshot=<file>` option (`DevCapture`); how-to in `docs/08-testing-and-qa.md`. What it showed, and the fixes:
  - Colors were washed out to near white. Blender palette colors were being treated as linear; `sf_common.get_material` now converts them from sRGB, and all 35 models were rebuilt. Scene ambient light and sun were also turned down.
  - The camera started away from the base; it now starts on the player's HQ.
  - The F1 help ran off the screen; it now wraps.
  - Since P1-32, `-- --scenario=<id>` no longer skipped the menu (the menu became the main scene). The menu now honors it again.
  - A custom-cursor texture leaked at exit; it is released when the match closes.
- **P1-28 effects:** `CombatEffects` keeps pools of particle effects (muzzle flash, explosion sized by splash radius, smoke, death blast) and tracers for instant weapons, driven by sim events. Nothing plays where the player can't see. Battery saver halves particle counts. New perf scenario `effects_50` (50 explosions a second).
- **P1-29 audio:** audio buses (Master, Music, SFX, UI, Voice), a pool of 3D sound players with a per-sound rate limit, and 11 original placeholder sounds synthesized by `tools/gen_sounds.py` (weapons by type, explosions, UI click, unit acknowledgement, construction complete). The Settings volume sliders now work.
- Tests: `tools/run_tests.sh` -> 134 tests, 0 failed (new `test_audio.gd`); smoke_main checks that combat plays effects and sounds.
- Not verified: effects and sounds on a phone; how the synthesized sounds feel (they are rough placeholders); lighting under the Mobile renderer (the screenshots use Compatibility).
- Next: P1-30 terrain and map format, then P1-24b guard and patrol.
- For the owner: look at `docs/screenshots/` and say whether the look is heading the right way (Q-6).

---

## 2026-11-26: P1-24 Touch controls (Claude Code, branch claude/phase-0-wrapup)
- Done: a touch bar above the minimap with Clear, a Box toggle (one-finger drag selects instead of panning) and group buttons 1–5 (tap selects, tap twice jumps the camera, hold 0.5 s stores; each shows its size). Holding a finger still for 0.6 s opens a radial menu with the orders that fit the selection: attack-move here, move here, stop, hold, rally here. Touch gestures moved out of `SelectionController` into `TouchGestures`. Guard and patrol need new sim orders, so they became P1-24b.
- Tests: `tools/run_tests.sh` -> 129 tests, 0 failed; smoke_main drives the group buttons, Clear, box mode, the long press and the radial menu through the real code paths.
- Not verified: on a real phone (button sizes, the 0.6 s hold, notches). That check belongs to P0-12.
- Next: P1-28 effects, P1-29 audio, P1-30 terrain.
- For the owner: when you try the APK, check that the touch bar is reachable with your thumb and that the long press feels right.

---

## 2026-11-26: P1-35 Settings (Claude Code, branch claude/phase-0-wrapup)
- Done: a Settings screen, reached from the main menu and the pause menu, with render scale, frame-rate limit (30/60/unlimited), shadows, battery saver (30 fps, lower resolution, no shadows), interface size, edge panning, key rebinding (a key already in use is swapped) and volume sliders. Every change applies at once and is saved in `user://settings.cfg` (`GameSettings`). Tests use scratch files, never the player's settings.
- Tests: `tools/run_tests.sh` -> 129 tests, 0 failed (new `test_settings.gd`); smoke_menu opens Settings from both menus and checks that battery saver applies and is saved.
- Not verified: how the screen looks on a phone; volume sliders do nothing until the audio buses exist (P1-29).
- Next: P1-24 touch controls, then P1-28 effects and P1-29 audio.
- For the owner: none.

---

## 2026-11-26: P1-23 Desktop controls (Claude Code, branch claude/phase-0-wrapup)
- Done: control groups (Ctrl+1–9 store, 1–9 select, twice quickly centers the camera, Shift+1–9 adds), camera bookmarks (Ctrl+F5–F8 save, F5–F8 return), Space + left-drag panning for trackpads, a hover ring on the unit under the mouse (red on enemies), and cursor shapes for select, move, attack (a red crosshair drawn in code) and valid or invalid placement. The F1 help lists the new keys.
- Tests: `tools/run_tests.sh` -> 123 tests, 0 failed (new `test_controls.gd`); smoke_main drives groups, bookmarks (real key events), Space-drag, cursor states and hover; smoke_menu ok.
- Not verified: how the cursors look on a real desktop.
- Next: P1-35 settings (rebinding, render scale, fps cap), then P1-24 touch controls.
- For the owner: none.

---

## 2026-11-26: P1-33 Performance harness (Claude Code, branch claude/phase-0-wrapup)
- Done: `tools/run_perf.sh` runs three fixed scenarios headless (two 150-unit armies fighting; 300 vehicles marching through the sandbox ridge gap; the view syncing 300 entities) and writes `build/perf/latest.json`. CI fails when a scenario's normalized median (ms per tick ÷ a calibration workload) is more than 20% above `game/tests/perf/perf_baseline.json`. `--profile` prints ms per tick for each sim system.
- The harness found the sim far over budget, so I optimized it without changing any result (golden replays still match bit for bit):
  - Target search skips friendly units through a per-team spatial index, and distance checks use exact squared comparisons instead of square roots.
  - Separation inlines its cheap overlap test and reads the padded walk grid.
  - Vision stamps each (team, cell, sight radius) circle once.
  - Result on this desktop: battle 34 → about 9 ms per tick, march 79 → about 12 ms.
- Tests: `tools/run_tests.sh` -> 118 tests, 0 failed (golden replays unchanged); smoke tests ok.
- Not verified: phone speed. The phone budget is 8 ms per tick at 300 units and a mid-range phone is roughly 3× slower than this desktop, so we are probably still over. That is P1-33b, and Q-7 asks the owner whether native code is allowed.
- Next: P1-23 desktop controls.
- For the owner: Q-7 (native code for the sim's hot spots).

---

## 2026-11-26: P1-27 Fog rendering (Claude Code, branch claude/phase-0-wrapup)
- Done: `FogOfWar` turns the local team's vision into a texture after every sim tick; a terrain shader (`fog_terrain.gdshader`) draws unexplored ground nearly black and explored-but-unseen ground at 45% brightness, with soft edges. Ground and rocks use it. Supply sites appear once explored. The minimap already had fog.
- Tests: `tools/run_tests.sh` -> 118 tests, 0 failed; smoke_main now checks that every enemy view is hidden exactly when the player can't see it, and that the fog texture matches the sim's grid.
- Not verified: the shader has not been compiled on a GPU yet (the headless build skips shaders). Checking it next with a software-OpenGL build.
- Next: P1-33 performance harness.
- For the owner: none.

---

## 2026-11-26: P1-22 Unit views v2 (Claude Code, branch claude/phase-0-wrapup)
- Done: health bars (shown when damaged or selected; green, yellow, red), veterancy pips, turrets that turn toward their target and barrels that rise for artillery, shots that flash at the model's `muzzle_0`, and wrecks: destroyed vehicles and buildings turn dark, stay 20 s and sink away; infantry and drones vanish. Death flashes in the fog are no longer drawn. Blender models now have `turret`/`barrel` pivots (rocket pods, the laser mount and SAM launchers too), and all 35 assets were rebuilt.
- Tests: `tools/run_tests.sh` -> 118 tests, 0 failed; smoke_main (now also checks turret aim, health bar rules, pips and wrecks) ok; smoke_menu ok.
- Not verified: no screenshot yet, because this machine has no screen. Bar sizes and colors may need tuning once someone looks (P0-15).
- Next: P1-27 fog rendering, then P1-33 performance harness.
- For the owner: none.

---

## 2026-11-26: P1-04b to P1-34 (Claude Code, branch claude/phase-0-wrapup)

**Done:**
- **Pathfinding (P1-04b):** Jump Point Search with precomputed straight-run tables. Worst case 2.4 ms, typical 0.09 ms (was 22 ms worst).
- **Movement (P1-05, P1-06):** one shared path per group; compact groups keep their layout, spread groups form a grid. Bucket-grid separation stops units overlapping.
- **Combat (P1-07 to P1-10):** health and death, damage matrix and weapons from data, instant, ballistic and guided projectiles, splash. Attack, attack-move, hold and stop.
- **Vision (P1-11):** per-team 8 m vision grid with explored memory. Units only target what their team sees.
- **Base and economy (P1-12 to P1-16):** construction by engineers, production queues with rally points, prerequisites, supply trucks and supply sites, power (low power halves production and shuts down armed buildings).
- **Progression (P1-17 to P1-19):** veterancy, commander rank, victory and defeat rules.
- **Replays and lockstep (P1-20, P1-21):** replays with golden replay tests; a lockstep scheduler with input delay and hash checks.
- **AI (P1-31):** skirmish AI v0 from presets in `game/data/ai`. An AI-vs-AI duel ends at about 5:00 game time.
- **UI (P1-25, P1-26, P1-32):** HUD with minimap and a 3×4 command grid (Q-W-E-R / A-S-D-F / Z-X-C-V); building placement ghost; main menu, skirmish setup, pause menu and end screen.
- **Roster (P1-34):** every unit and building in `docs/design/vertical-slice.md` has data, a Blender placeholder model and an icon (35 assets). New generator options are listed in `docs/04-art-pipeline.md`.

**Tests:** `tools/run_tests.sh` → 118 tests, 0 failed; `smoke_main: ok`; `smoke_menu: ok`. `python3 tools/check_repo.py` → ok.

**Not verified:**
- Nothing seen on a real screen. The test machine has no GPU; the owner check is P0-15.
- Not run on an Android phone or a Googlebook (P0-12, P0-13).
- The new units' special rules are not in yet: EW jamming, transports, drone endurance, active protection and cage armor come in Phase 2 (P2-01 to P2-04). Drones still path on the ground in the sim; the view lifts them 6 m.

**Next:** P1-22 (unit views v2), P1-27 (fog rendering), P1-23/P1-24 (controls), P1-33 (performance harness).

**For the owner:** play a skirmish from the menu and say how it feels; answer Q-1 to Q-6 in `tasks/QUESTIONS.md`.

---

## 2026-11-25: P1-02, P1-03, P1-04 (Claude Code, branch claude/phase-0-wrapup)

**Done:**
- **P1-02 facing and turn rate:**
  - Units have a sim facing, and turn at `turn_rate_deg_per_s` from data (missing = instant, as for infantry).
  - They creep at 25% speed until they face within 22.5° of their heading.
  - The view draws the sim facing, interpolated between ticks.
  - The two sides now spawn facing each other.
- **P1-03 map grid:**
  - `SimMap` uses 2 m cells, with a terrain layer and a building-footprint layer (claim/release, all-or-nothing).
  - Maps are content: `game/data/maps/sandbox.json` has a ridge with a gap plus rocks.
  - The sandbox draws its rocks from the map, so what you see is what blocks.
- **P1-04 pathfinding:**
  - Deterministic A* with 8 directions, no corner cutting, (f, h, index) tie-breaks and a 5/4-weighted octile heuristic.
  - Line-of-sight smoothing into a few waypoints.
  - A blocked or unreachable goal sends the unit to the nearest reachable cell.
  - `PathingSystem` plans at most 3 searches per tick, and units follow their waypoints.

**Tests:** `tools/run_tests.sh` → 58 tests, 0 failed; `smoke_main: ok`. A unit ordered across the sandbox goes through the ridge gap without ever entering a rock cell.

**Measured (desktop, GDScript):**
- About 1 ms per typical 20–60 m search.
- About 22 ms per worst-case search across a maze of walls on a 256 m map (it was 91 ms before optimizing).
- The P1-04 speed target isn't met yet, so I added **P1-04b**, with options (Jump Point Search, or C++ per ADR 0004).

**Not verified:**
- Nothing seen on screen yet (P0-15).
- Units still overlap each other, and big tanks can clip rock corners: they follow cell centers without accounting for their radius. Avoidance and clearance come in P1-06.

**Next:**
- P1-04b (pathfinding speed), P1-05 (group movement: one shared path per group also cuts searches), P1-06 (separation).
- Owner: merge the branch, try the APK, answer Q-1 to Q-6.

---

## 2026-11-25: P0-07 to P0-09, P0-11, P0-14, P1-01 (Claude Code, branch claude/phase-0-wrapup)

**Done:**
- The repo is on GitHub (jamonlineph/project-zero-hour). The first CI run on `main` passed both jobs.
- **Builds:** `game/export_presets.cfg` (Android debug APK, Linux, Windows). A new CI job exports all three after the tests pass and uploads them as artifacts (APK about 54 MB). On `v*` tags it attaches them to a GitHub release. CI now also runs on `claude/**` and `task/**` branches.
- **Housekeeping:** GitHub labels (phases, areas, good-first-task) and issue templates. Branch-protection steps for the owner are in `docs/07-ai-workflow.md`.
- **P1-01 fixed-point trigonometry:** binary angles (4096 per turn), a generated quarter-wave sine table (`tools/gen_trig_table.py` → `game/src/sim/trig_table.gd`), and `Fx.sin_a`, `cos_a`, `atan2_a`, `angle_diff`, `angle_from_degrees`. atan2 is within 1 unit (0.09°) in all 4096 directions.
- Roadmap rule clarified: device-free sim tasks may start while the previous phase only waits on the owner's device checks.

**Tests:**
- `tools/run_tests.sh` → 32 tests, 0 failed; `smoke_main: ok` (Godot 4.7.2, headless).
- GitHub Actions on the branch: repo checks, Godot tests and builds all green.

**Not verified:**
- The APK hasn't been installed on a phone or Googlebook yet (P0-12, P0-13).
- macOS export not added (P0-14 stays 🔄). The Gradle/AAB preset moved to P2-19.

**Next:**
- Owner: download the APK from Actions and try it (P0-12), merge this branch, set branch protection.
- Agents: P1-02 (facing and turn rate), then P1-03 (map grid).

**For the owner:** questions Q-1 to Q-6 in `tasks/QUESTIONS.md` are still open.

---

## 2026-11-25: P0-01 to P0-06, project setup (Claude Code)

**Done:**
- **The plan:**
  - Vision with the IP boundary, and a roadmap for phases 0–5 with exit checks.
  - Architecture (deterministic lockstep-ready sim) and coding standards (including the Godot 3→4 pitfall table).
  - Art, platform, legal, AI-workflow and testing docs.
  - The full game design: mechanics, four original factions, role × faction rosters, combat matrix, economy, commander trees, controls, maps and modes, AI, and the vertical slice with first-pass numbers.
  - 7 ADRs.
- **Agent setup:** `AGENTS.md` as the single source of truth, plus pointers for Claude Code, Gemini CLI, Cursor and Copilot. Backlog with detailed Phase 0–2 tasks and Phase 3–5 epics; questions file.
- **Godot 4.7 project:**
  - The sim core: `Fx` 16.16 fixed point, `SimRng` xorshift32, `SimHash`, `SimWorld` with 15 Hz ticks, canonical command order and ownership validation, `SimEntity`/`SimMover`/`MovementSystem`, `SimCommand` with a replay-ready dict round trip, and formation offsets.
  - `ContentDb` JSON loader with validation.
  - The sandbox scene: RTS camera, mouse and touch selection and move orders, team colors, move markers, and a debug HUD with a state hash.
- **Tests:** a headless unit-test runner (24 tests; script errors count as failures) and a main-scene smoke test. The smoke test checks selection, movement, Blender models loading with team colors, and that no errors are logged.
- **Blender 5 pipeline:**
  - 5 archetype generators (tracked, wheeled, infantry, drone, building).
  - glTF export, 256 px icons, 8-direction sprite sheets, and automatic manifest rows.
  - 7 placeholder assets generated: US and RU tanks and squads, a US logistics truck, an RU recon drone and a US HQ.
- **Repo hygiene:** `check_repo.py` (provenance, banned file types, size), a CI workflow, licenses (GPL-3.0-or-later, CC BY-SA 4.0), contributing guide, code of conduct, PR template.

**Tests:**
- `tools/run_tests.sh` → 24 tests, 0 failed; `smoke_main: ok`. Run on Godot 4.7.2-stable built from the official source tag, headless, on Linux x86_64.
- `python3 tools/check_repo.py` → ok (16 assets in the manifest).
- `tools/build_assets.sh` (all assets with icons, and `--sheets`) → ok on Blender 5.3.0.

**Not verified:**
- **Nothing has been seen on a screen yet.** Camera framing, model orientation, colors and overlay positions are untested visually (P0-15).
- Not run on Android or a Googlebook (P0-11 to P0-13).
- The GitHub Actions workflow hasn't run yet; it needs the repo on GitHub (P0-07, P0-08).

**Next:**
- P0-07: the owner publishes the repo.
- P0-08: green CI.
- P0-15: visual check on a desktop.
- P0-11 to P0-13: Android and Googlebook builds.

**For the owner:** please answer Q-1 to Q-6 in `tasks/QUESTIONS.md` when you can. Q-2 (licenses) and Q-4 (public or private) matter before P0-07.
