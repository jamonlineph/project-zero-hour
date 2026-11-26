# AGENTS.md: instructions for AI coding agents

This file is the single source of truth for every AI agent working in this repo: Claude Code, Codex, Gemini CLI, Cursor, GitHub Copilot, Jules, Aider and others. Tool-specific files (`CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`, `.github/copilot-instructions.md`) only point here.

## 1. The project in one paragraph

**Signal Front** (codename) is an open-source 3D real-time strategy game for Android phones and tablets, Googlebook (Google's Android-based laptops), Chromebooks and PC. It uses classic base-building RTS mechanics with **original** content set in 2026: drones, jamming and sensor networks. Engine: **Godot 4.7, GDScript**. Art: **Blender 5**, exported as glTF. A human owner directs the project. Agents implement tasks from `tasks/BACKLOG.md`, and the owner reviews and merges the work.

## 2. Start of every session (in this order)

1. Read this file completely.
2. Read the newest 3 entries of `tasks/PROGRESS.md` (newest at the top).
3. Read `tasks/QUESTIONS.md`. Answered questions are binding decisions.
4. Pick your task (section 4) and read the docs it lists.
5. Run the tests before you change anything (`tools/run_tests.sh`) so you know the starting state.

## 3. Golden rules (non-negotiable)

1. **Original content only.** Never copy or recreate content from *Command & Conquer: Generals / Zero Hour* or any other game. That covers names, factions, unit/building/power designs, characters, art, sounds, music, maps, missions, story text and UI layouts, including renamed or "modernized" versions. Genre mechanics are fine. Never add files from game installs or mods. If a task seems to need any of this, stop and add a question to `tasks/QUESTIONS.md`.
2. **The sim is deterministic.** Code in `game/src/sim/` must follow these rules:
   - Use ints only, with fixed-point math through `Fx`. No `float`, `Vector2`, `Vector3` or `Transform*`.
   - Use `SimRng` for randomness, never `randi()`, `randf()` or `RandomNumberGenerator`.
   - No `Time`, `OS` or `Engine` calls, no Nodes, scenes or signals.
   - Iterate entities through `entity_ids`.
   - Player input enters only as a `SimCommand`.

   Details are in `docs/02-architecture.md` section 3.
3. **Keep the sim and the view separate.** View, UI and input code (`game/src/view`, `ui`, `input`) reads sim state and never writes it. The sim never references the view.
4. **Godot 4.7 and GDScript 2.0 only.** No Godot 3 APIs; see the table in `docs/03-coding-standards.md`. Use static typing everywhere.
5. **Data-driven content.** Unit, building and weapon numbers live in `game/data/**/*.json`, not in code. List every new data file in `game/data/index.json`.
6. **Tests are the safety net.** Every sim change ships with tests. Run `tools/run_tests.sh` before every commit. Never delete, skip or weaken a test to make it pass. Fix the code, or ask.
7. **Every asset has provenance.** Every file in `game/assets/` needs a row in `ASSET_MANIFEST.csv` (author, source, license). Allowed licenses: `CC-BY-SA-4.0`, `CC-BY-4.0`, `CC0-1.0`, `OFL-1.1`. `tools/check_repo.py` enforces this.
8. **Mobile first.** Everything must work with touch and with mouse/keyboard, in resizable windows, within the performance budgets in `docs/05-platforms.md`.
9. **No silent architecture changes.** Changing anything in `docs/decisions/` needs a new ADR and the owner's approval through `tasks/QUESTIONS.md`.
10. **Stay in scope.** Do the task you claimed. Record other problems you notice as new backlog tasks or in your handoff note. Don't fix them on the side.

## 4. Picking a task

- Open `tasks/BACKLOG.md`. Take the first task in the current phase whose status is ⬜ (todo) and whose dependencies are all ✅ (done), unless the owner named a task.
- Change its status to 🔄 and add your tool name and the date. If other agents may be working in parallel, commit that change on its own first.
- If the task is too big for one session, split it into subtasks in `BACKLOG.md` (same format, IDs like `P1-04a`) and do the first one.
- If you are blocked on a decision only the owner can make, add it to `tasks/QUESTIONS.md`, mark the task ⛔ with a one-line reason, and pick another task.

## 5. Doing the work

- Branch name: `task/<ID>-<short-name>` (for example `task/P1-04-pathfinding`), if your tool uses branches.
- Read the related code first and follow its patterns. New sim features are a component plus a system; see `docs/02-architecture.md` section 10.
- Keep changes small. Start a new file rather than growing one past about 400 lines.
- Update the docs your change affects. If you change a convention, update this file too.
- Run headless; never assume someone can click in the editor. If a step truly needs a human (a phone, a store console), write exact instructions in your handoff and mark the task ⛔.

## 6. Commands (run from the repo root)

| What | Command |
|---|---|
| All tests (unit + smoke) | `tools/run_tests.sh`. On Windows: `tools\run_tests.ps1`. Set `GODOT=/path/to/godot` if Godot isn't on your PATH |
| Repo checks (provenance, banned files) | `python3 tools/check_repo.py` |
| Rebuild placeholder art | `tools/build_assets.sh` (set `BLENDER=/path/to/blender`). Options: `--only ID ...`, `--no-icons`, `--sheets` |
| Rebuild placeholder sounds | `python3 tools/gen_sounds.py` (needs numpy; writes `game/assets/audio/sfx/` and the manifest rows) |
| Re-import assets after adding files | `godot --headless --path game --import` |
| Regenerate golden replays (only after an intended change to sim rules or data; say why in the commit) | `tools/regen_golden_replays.sh` |
| Run the game | `godot --path game`, or open `game/project.godot` and press F5 |
| Screenshot without a screen | `xvfb-run -a godot --rendering-driver opengl3 --path game -- --scenario=skirmish_vs_ai --screenshot=/tmp/shot.png` (details in `docs/08-testing-and-qa.md`) |

## 7. Definition of done (every task)

- [ ] The task's acceptance criteria are met.
- [ ] `tools/run_tests.sh` and `python3 tools/check_repo.py` both pass.
- [ ] New sim behavior has tests. Add a determinism test whenever it involves randomness or ordering.
- [ ] No new Godot errors or warnings at startup.
- [ ] The affected docs are updated, and the task is marked ✅ in `tasks/BACKLOG.md`.
- [ ] A new handoff entry is at the top of `tasks/PROGRESS.md` (template below).
- [ ] The commit message reads `<type>(<area>): <summary> [<TASK-ID>]`, for example `feat(sim): grid pathfinding [P1-04]`. Types: feat, fix, test, docs, refactor, perf, art, chore.

## 8. Handoff entry template (put it at the top of tasks/PROGRESS.md)

```
## YYYY-MM-DD: <TASK-ID> <title> (<agent/tool name>)
- Done: what changed, in plain words.
- Tests: <command> -> <result>
- Not verified: anything you could not check (for example "not run on a real Android phone").
- Next: the most useful next task.
- For the owner: decisions or questions (or "none").
```

## 9. Repo map

```
AGENTS.md            this file (rules for agents)
docs/                the plan: vision, roadmap, architecture, design, pipelines
  decisions/         architecture decision records (ADRs)
  design/            game design: mechanics, factions, units, combat, UI...
tasks/               BACKLOG.md (what to do), PROGRESS.md (what happened), QUESTIONS.md
game/                the Godot project (open game/project.godot)
  src/sim/           deterministic simulation: ints only
  src/data/          loads JSON content into typed defs
  src/view/          3D presentation of the sim (reads only)
  src/input/         mouse/touch/keyboard -> selection and SimCommands
  src/ui/            HUD and menus
  src/main/          scene wiring and the fixed-tick runner
  data/              JSON content (units, later weapons, buildings, maps)
  assets/            models (.glb), icons and sprites (.png)
  tests/             headless test runner, unit tests, smoke test
blender/             scripts that generate placeholder models and render sprites
tools/               run_tests, build_assets, check_repo
ASSET_MANIFEST.csv   provenance of every file in game/assets/ (kept outside game/,
                     because Godot imports any .csv inside the project as translations)
```

## 10. When you're unsure

Ask in `tasks/QUESTIONS.md` rather than guess on anything about game design, licensing, legal or architecture. For small code choices, pick the simplest option that fits the existing code, and mention it in your handoff.
