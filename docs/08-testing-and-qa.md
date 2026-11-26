# Testing and QA

## Automated tests (run by `tools/run_tests.sh` and in CI)

| Layer | Where | What it proves |
|---|---|---|
| Unit tests | `game/tests/unit/test_*.gd` | Fixed-point math, RNG, commands, movement, content loading |
| Determinism tests | `game/tests/unit/test_determinism.gd` | Same seed + commands → identical state hash every tick; command order inside a tick doesn't matter |
| Smoke test | `game/tests/smoke_main.gd` | The real main scene loads headless; units use their Blender models with team colors; selecting and ordering a move works; no errors are logged |
| Golden replays | `game/tests/replays/*.json`, checked by `test_replays.gd` | Recorded matches replay to identical state hashes. After an intended change to sim rules or game data, run `tools/regen_golden_replays.sh` and say why in the commit |
| Repo checks | `tools/check_repo.py` | Every asset has provenance; no banned file types; no huge files |
| Performance harness | `game/tests/perf/run_perf.gd`, run by `tools/run_perf.sh` | Sim milliseconds per tick and view sync time for fixed 300-unit scenarios stay within 20% of `game/tests/perf/perf_baseline.json` |

### Performance harness (P1-33)

- **Scenarios:** `battle_300` (two 150-unit armies attack-move into each other on an open 256 m map), `march_300` (300 vehicles cross the sandbox map in groups of 12, through the ridge gap), `view_300` (`GameView.sync` with 300 entities on screen).
- **Numbers:** median, 95th percentile and maximum ms per tick (per frame for the view), best of 3 repeats. Results go to `build/perf/latest.json`.
- **Limits:** the sim scenarios fail at more than 20% over the baseline; `view_300` (about 2 ms of work, noisier) at more than 50%.
- **Machine speed:** every run also times a fixed GDScript workload ("calibration"). The regression check compares `median / calibration`, so a slower CI runner doesn't fail on its own.
- **Find the slow system:** `tools/run_perf.sh --profile` prints the average ms per tick of each sim system.
- **Update the baseline** only after an intended change (new feature, accepted slowdown, faster code) or a change of CI runner: `tools/run_perf.sh --update-baseline`, and say why in the commit. CI uploads its own `latest.json` as an artifact; copying that over the baseline is the most reliable way to set it.
- **Budget:** the harness measures desktop or CI speed, not a phone. Divide the phone budget (8 ms per tick at 300 entities, [05-platforms.md](05-platforms.md)) by about 3 to compare: aim for about 3 ms on desktop.

How the test runner behaves:
- It fails a test if the test crashes (script error), even when no assertion failed.
- `push_error()` inside a test doesn't count as a failure, because tests trigger it on purpose to check error handling.
- The smoke test does count `push_error()`, because the real game must start cleanly.

## Planned test additions

| Task | Adds |
|---|---|
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
