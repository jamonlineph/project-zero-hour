# Roadmap

Each phase ends with an **exit check**: a playable, testable state. Don't start a phase's features until the previous exit check passes. Art, audio and design work may run ahead. Simulation tasks that need no device may also start while the previous phase only waits on the owner's device checks.

Durations assume one owner plus AI agents working most days, with volunteer or commissioned help for art and audio. They will move, but the order matters more than the dates. Task IDs (P0-01 and so on) point into [tasks/BACKLOG.md](../tasks/BACKLOG.md).

| Phase | Goal | Rough duration | Exit check |
|---|---|---|---|
| 0: Foundations | Repo, plan, skeleton, pipelines, first Android build | 2–4 weeks | Sandbox runs on an Android phone, a Googlebook and desktop; CI green |
| 1: Core RTS systems | Every core mechanic working with placeholder art | 4–6 months | A full 1v1 skirmish against a basic AI, start to victory, on a phone |
| 2: Vertical slice | One polished matchup: America vs North Korea | 4–6 months | A fun 15-minute match on phone and Googlebook; closed test on Google Play |
| 3: Production | All four factions, maps, multiplayer, map editor | 9–12 months | Open beta on Play, F-Droid and GitHub |
| 4: Polish | Balance, performance, accessibility, campaign | 3–6 months | Release candidate passes the launch checklist |
| 5: Launch and live | 1.0 release, patches, community content | ongoing | — |

## Phase 0: Foundations

**Delivered by the first session:**
- The repo and the full plan.
- A Godot project with a deterministic sim core and an RTS camera.
- Mouse and touch selection, and move orders.
- Headless tests and a smoke test.
- The Blender placeholder pipeline.
- A CI workflow and the provenance checks.

**Still to do:**
- Push to GitHub and get CI green (P0-07, P0-08).
- An Android debug build running on a real phone and a Googlebook (P0-11 to P0-13).
- Desktop exports (P0-14).
- A name and trademark check (P0-10).

**Exit check:**
- The sandbox runs on a real Android phone, a Googlebook (or the Android Studio desktop emulator) and a desktop OS.
- Touch and mouse both select and move units.
- CI is green.

## Phase 1: Core RTS systems (placeholder art)

Build every system the game needs, using Blender placeholder models.

**Simulation:**
- fixed-point angles and turning
- grid pathfinding with group movement
- health, damage and death
- weapons, armor classes, attack orders
- vision and fog of war
- construction, production queues, tech prerequisites
- supply economy and power
- veterancy and commander XP
- victory conditions
- replays and the lockstep scheduler

**View and UI:**
- glTF unit views with team colors and health bars
- full desktop and touch controls
- HUD v1 with minimap, build menus and building placement
- fog rendering, basic effects and sound

**Game flow:**
- skirmish AI v0
- main menu and skirmish setup
- settings
- a performance harness

**Exit check:**
- A complete 1v1 skirmish against AI v0, from building a base to destroying the enemy, on a mid-range Android phone.
- 30 fps or better with 300 units.
- No desyncs in replay tests.

## Phase 2: Vertical slice (America vs North Korea)

Make one matchup feel like the real game.

**2026 systems:**
- drone flight time and counter-drone weapons
- jamming fields and spoofing
- kill chain spotting
- active protection on tanks
- interceptable strikes
- decoys

**Content and polish:**
- about 8 units and 8 buildings per side, with final-quality Blender art
- commander ranks 1–3 with powers
- one polished map
- AI v1 with easy and normal difficulty
- UI art and sound passes
- a Google Play internal or closed test

**Exit check:**
- Testers finish 15-minute matches on a phone and a Googlebook and say they're fun.
- No crashes in 20 test matches.
- Performance budgets met.

## Phase 3: Production

**Factions and content:**
- Complete rosters for America and North Korea, then the UAE, then the EU.
- Air units and airbases, garrisons and transports, stealth.
- Superweapons, ranks 4–5, neutral buildings.
- 8–12 maps.

**Systems and tools:**
- multiplayer (LAN, then online through a relay server)
- map editor v1 and mod support
- localization through Weblate
- accessibility options

Open beta.

**Exit check:**
- Open beta on Play open testing, F-Droid and GitHub releases.
- Multiplayer stable across Android and PC.

## Phase 4: Polish

- Balance passes using AI-vs-AI simulations and beta replays.
- Performance on low-end devices.
- Gauntlet mode and the operations campaign.
- Store listings, rating questionnaire, privacy policy.
- Launch checklist ([08-testing-and-qa.md](08-testing-and-qa.md)).

## Phase 5: Launch and live

1.0 on Google Play, F-Droid, GitHub and itch.io. After that:
- patches
- sub-faction variants
- new nations
- community maps
- tournaments

## Scope levers (if time runs short)

These come from least to most painful:
1. Ship the campaign after 1.0.
2. Ship 1.0 with three factions and release the EU as the first update.
3. Cut sub-faction variants until after 1.0.
4. Cut 4-player maps; keep 1v1 and 2v2.
