# Running the project with AI agents (for the owner)

You direct the work; AI coding agents do most of the typing. The repo is set up so any agent can pick up where the last one stopped, using only what's written here:
- **AGENTS.md** holds the rules.
- **tasks/BACKLOG.md** says what to do next.
- **tasks/PROGRESS.md** says what happened.
- **tasks/QUESTIONS.md** holds the questions agents need you to answer.

## Tools that work with this repo

| Tool | How it reads the rules |
|---|---|
| Claude Code (terminal, desktop, web, IDE) | `CLAUDE.md` imports `AGENTS.md` |
| OpenAI Codex (CLI or cloud) | reads `AGENTS.md` directly |
| Gemini CLI | `GEMINI.md` points to `AGENTS.md` |
| Cursor | `.cursor/rules/project.mdc` points to `AGENTS.md` |
| GitHub Copilot (agent mode or coding agent) | `.github/copilot-instructions.md` points to `AGENTS.md` |
| Others (Jules, Aider, Windsurf, …) | Tell them: "Read AGENTS.md first." |

Cloud agents need the tools to run the tests. They should download Godot 4.7.2 (Linux, standard build) and set `GODOT`. The CI workflow in `.github/workflows/ci.yml` shows the exact commands.

## The daily loop

1. **Pick the work.** Open `tasks/BACKLOG.md`. Usually you just let the agent take the next task.
2. **Start a session** with the "Next task" prompt below.
3. **Review.** When the agent finishes:
   - read its handoff entry in `tasks/PROGRESS.md`
   - check that CI is green on its pull request
   - run the game for 2 minutes
4. **Merge** if it's good. If it isn't, use the "Fix review comments" prompt.
5. **Answer questions** in `tasks/QUESTIONS.md` when agents add them. Your answers are binding decisions.

Every few weeks, ask an agent for a **plan check** (prompt below). It compares the code with the docs and reports drift.

## Copy-paste prompts

**Next task**
> Read AGENTS.md and follow it exactly. Take the next available task from tasks/BACKLOG.md, implement it with tests, run tools/run_tests.sh and python3 tools/check_repo.py, update the docs, BACKLOG.md and PROGRESS.md, and commit. If anything needs my decision, add it to tasks/QUESTIONS.md and stop.

**A specific task**
> Read AGENTS.md and follow it exactly. Do task P1-08 from tasks/BACKLOG.md. Stay within that task's scope.

**Break a phase into tasks** (before starting phases 3–5)
> Read AGENTS.md, docs/01-roadmap.md and the Phase 3 epics in tasks/BACKLOG.md. Break epic P3-E2 into tasks in the same format as the Phase 1 tasks: ID, goal, steps, acceptance criteria, files, dependencies. Each task should fit in one session. Don't write code.

**Make a placeholder model**
> Read AGENTS.md and docs/04-art-pipeline.md. Add a placeholder for <unit id> to blender/specs/placeholders.json using the right archetype (add an archetype to blender/sf_generators.py if needed). Run tools/build_assets.sh --only <id>, hook it into game/data, and run the tests.

**Design sheet for a unit**
> Read AGENTS.md, docs/design/factions.md, units-and-buildings.md and combat.md. Write a design sheet for <unit> in docs/design/units/<id>.md: role, cost, health, armor class, speed, weapons (damage type, range, reload), abilities, upgrades, counters. The numbers must fit docs/design/vertical-slice.md. Don't base it on any existing game's unit.

**Fix review comments**
> Read AGENTS.md. On branch <branch>, address these review comments: <paste>. Run the tests and update PROGRESS.md.

**Fix failing CI**
> Read AGENTS.md. CI is failing on <branch>. Reproduce the failure locally with tools/run_tests.sh, fix the root cause (don't weaken tests), and explain the cause in PROGRESS.md.

**Plan check**
> Read AGENTS.md and every doc in docs/. Compare them with the code. List mismatches (docs that are out of date, code that breaks a rule, missing tests) as new backlog tasks in tasks/BACKLOG.md. Don't change code.

## Running agents in parallel

- One task per agent, each on its own branch.
- Avoid two agents in the same area at once: two sim systems are usually fine; two UI tasks often collide.
- Merge often. Ask the second agent to rebase onto `main` before it finishes.

## Review checklist (no coding knowledge needed)

- [ ] CI is green: the "Repo checks" and "Godot tests" jobs both passed.
- [ ] The PROGRESS entry clearly says what changed and what wasn't verified.
- [ ] The game still starts, and the thing the task added works when you try it.
- [ ] No unexpected files: big binaries, files from other games, secrets or keys.
- [ ] New art has manifest rows (CI checks this, but glance anyway).
- [ ] If the agent changed AGENTS.md or anything in `docs/decisions/`, you agreed to it.

## Protect the main branch (one-time, P0-09)

So nothing broken lands on `main`:
1. On GitHub, open the repo → **Settings** → **Branches** (or **Rules** → **Rulesets**).
2. Add a rule for `main`: **Require a pull request before merging** and **Require status checks to pass**.
3. Pick the checks "Repo checks (provenance, banned files)", "Godot tests (headless)" and "Builds (Android debug APK, Linux, Windows)".

After that, agents work on branches (`claude/...`, `task/...`) and you merge their pull requests when CI is green.

## Things only you can do

- Create the GitHub repository, accounts and keys (Google Play developer account, upload keystore).
- Test on physical devices: phones, tablet, Googlebook. Agents can write exact test steps.
- Approve the name, licenses, art direction and anything legal (`tasks/QUESTIONS.md`).
- Recruit artists, voice actors and testers, and commission music if you choose to.
