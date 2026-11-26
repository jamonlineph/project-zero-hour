# Progress log

Newest entry at the top. Every session adds one entry using the template in [AGENTS.md](../AGENTS.md) section 8.

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
