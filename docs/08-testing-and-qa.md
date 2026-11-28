# Testing and QA

## Automated tests (run by `tools/run_tests.sh` and in CI)

| Layer | Where | What it proves |
|---|---|---|
| Unit tests | `game/tests/unit/test_*.gd` | Fixed-point math, RNG, commands, movement, content loading |
| Determinism tests | `game/tests/unit/test_determinism.gd` | Same seed + commands → identical state hash every tick; command order inside a tick doesn't matter |
| LAN smoke test | `game/tests/smoke_lan.gd` | Two `NetSession`s in one process connect over ENet on localhost (port 7351); the host sends the match; each side's player is an AI; after 40 s both machines have the same state hash and no desync was reported (P3-14a) |
| Smoke test | `game/tests/smoke_main.gd` | The real main scene loads headless; units use their Blender models with team colors; selecting and ordering a move works; no errors are logged |
| Golden replays | `game/tests/replays/*.json`, checked by `test_replays.gd` | Recorded matches replay to identical state hashes. After an intended change to sim rules or game data, run `tools/regen_golden_replays.sh` and say why in the commit |
| Repo checks | `tools/check_repo.py` | Every asset has provenance; no banned file types; no huge files |
| Performance harness | `game/tests/perf/run_perf.gd`, run by `tools/run_perf.sh` | Sim milliseconds per tick and view sync time for fixed 300-unit scenarios stay within 20% of `game/tests/perf/perf_baseline.json` |

### Performance harness (P1-33)

- **Scenarios:** `battle_300` (two 150-unit armies attack-move into each other on an open 256 m map), `march_300` (300 vehicles cross the sandbox map in groups of 12, through the ridge gap), `view_300` (`GameView.sync` with 300 entities on screen), `effects_50` (50 explosions per second with muzzle flashes and tracers, on top of the view).
- **Numbers:** median, 95th percentile and maximum ms per tick (per frame for the view), best of 3 repeats. Results go to `build/perf/latest.json`.
- **Limits:** the sim scenarios fail at more than 20% over the baseline; `view_300` and `effects_50` (a few ms of work, noisier) at more than 50%.
- **Machine speed:** every run also times a fixed GDScript workload ("calibration"). The regression check compares `median / calibration`, so a slower CI runner doesn't fail on its own.
- **Find the slow system:** `tools/run_perf.sh --profile` prints the average ms per tick of each sim system.
- **Update the baseline** only after an intended change (new feature, accepted slowdown, faster code) or a change of CI runner: `tools/run_perf.sh --update-baseline`, and say why in the commit. CI uploads its own `latest.json` as an artifact; copying that over the baseline is the most reliable way to set it.
- **Budget:** the harness measures desktop or CI speed, not a phone. Divide the phone budget (8 ms per tick at 300 entities, [05-platforms.md](05-platforms.md)) by about 3 to compare: aim for about 3 ms on desktop.

How the test runner behaves:
- It fails a test if the test crashes (script error), even when no assertion failed.
- `push_error()` inside a test doesn't count as a failure, because tests trigger it on purpose to check error handling.
- The smoke test does count `push_error()`, because the real game must start cleanly.

## Screenshots without a screen

Agents usually run on machines without a GPU or display. The game can still render through a virtual display and Mesa's software OpenGL:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path game -- --scenario=skirmish_vs_ai --screenshot=/tmp/shot.png --screenshot-frames=240
```

- `--screenshot=<file>` saves the rendered frame after `--screenshot-frames` frames (default 90), then quits (`DevCapture`). Without `--scenario=` or `--watch=` it captures the main menu.
- `--watch=<map_id>` starts computer vs computer on any map (for example `--watch=riverside`); `--side=kp` makes player 1 (whose HUD you see) North Korea. `--select=<def_id>` selects player 1's units or buildings of that type at the start, so the command grid shows their buttons; `--open=pause|settings|commander` opens that screen. `--camera=<x_m>,<z_m>,<distance_m>` aims the camera at a map point, and `--reveal` lifts the fog and shows every unit (view only).
- Gameplay videos use Godot's movie writer plus `--director` (`CameraDirector`), which follows the fighting and tours the bases in quiet moments, then quits 6 s after the end screen. `--seed=<n>` picks the match, `--speed=<x>` speeds the game up, and `--shot-dir=<dir> --shot-every=<s>` saves a screenshot every few game seconds. Engine flags go before `--`:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path game --write-movie /tmp/match.avi --fixed-fps 30 -- --watch=riverside --director --reveal --seed=5003 --speed=3 --shot-dir=/tmp/shots --shot-every=5
```

  Then convert with `ffmpeg -i /tmp/match.avi -c:v libx264 -crf 23 -pix_fmt yuv420p -c:a aac match.mp4`.
- `--scenario=<id>` skips the menu and starts that scenario (`sandbox`, `skirmish_vs_ai`, `ai_duel`).
- Use a normal Godot editor build (the official downloads include X11 and OpenGL). A "headless only" build can't do this.
- Software rendering runs at about 15–20 fps, so the sim reaches about 15 s of game time per 240 frames.
- It uses the Compatibility renderer, not Mobile, so lighting can differ slightly from phones. It's good for layout, colors, models and UI, not for final lighting or performance.
- Example shots live in `docs/screenshots/`.

## Planned test additions

| Task | Adds |
|---|---|
| P1-31 | **AI-vs-AI matches**: headless full matches between AI players. They catch crashes and stalemates, and feed balance numbers in Phase 4 |
| P1-37 | **Cross-device determinism**: Settings > Developer > Determinism check plays the match in `data/determinism_check.json` and shows whether its final hash equals the desktop value (code done; needs a phone run) |

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
