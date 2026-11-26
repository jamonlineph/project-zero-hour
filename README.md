# Signal Front (codename)

[![CI](https://github.com/jamonlineph/project-zero-hour/actions/workflows/ci.yml/badge.svg)](https://github.com/jamonlineph/project-zero-hour/actions/workflows/ci.yml)

An open-source, modern-warfare **real-time strategy** game for **Android phones and tablets, Googlebook, Chromebooks and PC**, built with **Godot 4** and **Blender**.

It uses the classic 2000s base-building formula (builders, supply trucks, power, tech trees, veterancy, commander powers, superweapons) with original content built around what defines warfare in 2026: drones, electronic warfare and sensor networks.

> **Status: Phase 0 (foundations).** The development sandbox runs: you can select and move units with mouse or touch, on a deterministic simulation covered by tests. The Blender pipeline makes placeholder models, icons and sprite sheets. See [tasks/PROGRESS.md](tasks/PROGRESS.md) for the latest state.

## Quick start

1. Install **Godot 4.7.x** (the standard build, not .NET) from <https://godotengine.org/download> and **Blender 5.x** from <https://www.blender.org/download/> (tested with 5.3).
2. Clone this repository.
3. Open `game/project.godot` in Godot and press **F5**. The menu lets you play a skirmish against the computer, watch two computer players, or open the developer sandbox.
4. Run the tests: `tools/run_tests.sh` (Windows: `tools\run_tests.ps1`). If Godot isn't on your PATH, set `GODOT` to its full path first.
5. Rebuild the placeholder art: `tools/build_assets.sh` (Windows: `tools\build_assets.ps1`). Set `BLENDER` to Blender's full path if needed.

## Built with AI coding agents

An owner directs this project, and AI coding agents (Claude Code, Codex, Gemini CLI, Cursor, Copilot and others) write most of the code.

- **Agents:** start with [AGENTS.md](AGENTS.md).
- **Humans:** [docs/07-ai-workflow.md](docs/07-ai-workflow.md) explains the day-to-day loop and has prompts you can copy and paste.

## The plan

| Document | What's in it |
|---|---|
| [docs/00-vision.md](docs/00-vision.md) | The game in one page, design pillars, 1.0 scope, the IP boundary |
| [docs/01-roadmap.md](docs/01-roadmap.md) | Phases 0–5, from foundations to launch, each with an exit check |
| [docs/02-architecture.md](docs/02-architecture.md) | Deterministic simulation, view, input, data, multiplayer design |
| [docs/03-coding-standards.md](docs/03-coding-standards.md) | GDScript style, Godot 3→4 pitfalls, determinism checklist |
| [docs/04-art-pipeline.md](docs/04-art-pipeline.md) | Blender → glTF models, rendered icons and sprites, budgets, naming |
| [docs/05-platforms.md](docs/05-platforms.md) | Android, Googlebook, Chromebook, desktop, Play Store requirements |
| [docs/06-legal-and-licensing.md](docs/06-legal-and-licensing.md) | Licenses, asset provenance, AI-generated content, real-world naming |
| [docs/07-ai-workflow.md](docs/07-ai-workflow.md) | How to run the project with several AI tools |
| [docs/08-testing-and-qa.md](docs/08-testing-and-qa.md) | Tests, determinism checks, device testing, performance |
| [docs/design/](docs/design/) | Game design: mechanics, factions, units and buildings, combat, economy, commander powers, controls, maps, AI |
| [docs/decisions/](docs/decisions/) | Why we chose Godot, 3D, lockstep, GDScript, JSON data and these licenses |
| [tasks/BACKLOG.md](tasks/BACKLOG.md) | Every task, in order, with acceptance criteria |

## License

- Code: **GPL-3.0-or-later** ([LICENSE](LICENSE)).
- Art, audio, data and other assets: **CC BY-SA 4.0** ([ASSETS_LICENSE.md](ASSETS_LICENSE.md)).

This is an independent project. It is not affiliated with or endorsed by any game publisher, and it contains no content from other games.
