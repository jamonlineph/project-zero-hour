# Testing and QA

## Automated tests (run by `tools/run_tests.sh` and in CI)

| Layer | Where | What it proves |
|---|---|---|
| Unit tests | `game/tests/unit/test_*.gd` | Fixed-point math, RNG, commands, movement, content loading |
| Determinism tests | `game/tests/unit/test_determinism.gd` | Same seed + commands → identical state hash every tick; command order inside a tick doesn't matter |
| Smoke test | `game/tests/smoke_main.gd` | The real main scene loads headless; units use their Blender models with team colors; selecting and ordering a move works; no errors are logged |
| Repo checks | `tools/check_repo.py` | Every asset has provenance; no banned file types; no huge files |

How the test runner behaves:
- It fails a test if the test crashes (script error), even when no assertion failed.
- `push_error()` inside a test doesn't count as a failure, because tests trigger it on purpose to check error handling.
- The smoke test does count `push_error()`, because the real game must start cleanly.

## Planned test additions

| Task | Adds |
|---|---|
| P1-20 | **Golden replays**: `game/tests/replays/*.json` (seed, map, command log, expected hash at given ticks). The runner replays each one and compares hashes. When a sim rule changes on purpose, regenerate them with the tool the task provides and explain why in the commit |
| P1-33 | **Performance harness**: a headless scene that spawns N units and records sim milliseconds per tick. CI fails if the budget regresses by more than 20% |
| P1-31 | **AI-vs-AI matches**: headless full matches between AI players. They catch crashes and stalemates, and feed balance numbers in Phase 4 |
| P1-37 | **Cross-device determinism**: a debug menu entry plays a golden replay on a phone and shows the final hash, which must equal the desktop value |

## Manual test checklist (each phase exit)

- [ ] Fresh install on each device in the matrix ([05-platforms.md](05-platforms.md)); the game starts in under 10 s.
- [ ] Touch: tap select, tap-ground move, drag pan, long-press box select, double-tap select-type, pinch zoom and rotate.
- [ ] Mouse: click and box select, shift-add, right-click move, wheel zoom, middle-drag pan, edge pan, hotkeys.
- [ ] Googlebook: resize the window during a match (no broken layout), trackpad, keyboard shortcuts, lid close and reopen.
- [ ] App switching: home button during a match, then return. The game is paused, nothing is lost.
- [ ] 20-minute match: no crash, no memory growth over 10%, frame rate inside budget, device not overheating.
- [ ] Every new unit and building checked at the closest and farthest zoom.

## Bug report template

```
Title: <short>
Build: <git commit or version> on <device / OS>
Steps: 1. … 2. … 3. …
Expected: …
Actual: …
Replay or screenshot: <attach if possible>
```

## Launch checklist (Phase 4)

- [ ] Final name cleared (trademark search) and used everywhere.
- [ ] Every asset in the manifest is final (no "placeholder" notes) or knowingly kept.
- [ ] Credits screen lists contributors, third-party assets and the Godot license.
- [ ] Store listing, screenshots, privacy policy, Data safety form and content rating done.
- [ ] Target API level and 16 KB page-size checks pass on Play.
- [ ] F-Droid metadata merged; GitHub release with APK and desktop builds.
- [ ] Crash-free rate in open beta ≥ 99%.
