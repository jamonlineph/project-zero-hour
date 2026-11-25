# The plan: reading order

Read these in order the first time. After that, read only what your task needs.

1. [00-vision.md](00-vision.md): what we're making and the IP boundary. **Everyone reads this.**
2. [01-roadmap.md](01-roadmap.md): phases and exit checks.
3. [02-architecture.md](02-architecture.md): how the code is organized and why the simulation is deterministic.
4. [03-coding-standards.md](03-coding-standards.md): GDScript rules and Godot 3→4 pitfalls.
5. [04-art-pipeline.md](04-art-pipeline.md): Blender to Godot, icons and sprites.
6. [05-platforms.md](05-platforms.md): Android, Googlebook, Chromebook, desktop.
7. [06-legal-and-licensing.md](06-legal-and-licensing.md): licenses, provenance, AI-generated assets.
8. [07-ai-workflow.md](07-ai-workflow.md): how the owner runs the project with AI agents.
9. [08-testing-and-qa.md](08-testing-and-qa.md): tests, determinism checks, device testing.

## Game design (`design/`)

| Doc | Contents |
|---|---|
| [mechanics.md](design/mechanics.md) | Every mechanic in the game, with status and the backlog task that builds it |
| [factions.md](design/factions.md) | The four factions: identity, signature mechanics, look |
| [units-and-buildings.md](design/units-and-buildings.md) | Full rosters as role × faction tables |
| [combat.md](design/combat.md) | Damage types, armor classes, veterancy, 2026 systems |
| [economy.md](design/economy.md) | Supply, power, capturable buildings, contracts |
| [commander.md](design/commander.md) | Commander ranks, points, powers, superweapons |
| [controls-and-ui.md](design/controls-and-ui.md) | Touch, mouse/keyboard, trackpad; HUD layouts |
| [maps-and-modes.md](design/maps-and-modes.md) | Map rules and game modes |
| [ai-opponent.md](design/ai-opponent.md) | The skirmish AI |
| [vertical-slice.md](design/vertical-slice.md) | Exact Phase 2 scope with first-pass numbers |

## Decisions (`decisions/`)

Architecture decision records (ADRs). Each one says what was decided and why. Don't reverse one without a new ADR approved by the owner.
