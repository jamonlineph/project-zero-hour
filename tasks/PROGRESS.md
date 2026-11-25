# Progress log

Newest entry at the top. Every session adds one entry using the template in [AGENTS.md](../AGENTS.md) section 8.

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
