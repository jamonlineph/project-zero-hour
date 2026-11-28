# Progress log

Newest entry at the top. Every session adds one entry using the template in [AGENTS.md](../AGENTS.md) section 8.

---

## 2026-11-28: P3-03 superweapons, P3-08 capturable buildings, P3-25, faction fixes (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **P3-03 superweapons:** one per faction (5,000 credits, rank 3, one each), built on building abilities: a 4-minute charge everyone sees under the top bar, then interceptable strikes anywhere. The AI builds and fires them. `BuildingLoader` split out of `ContentDb`.
  - **P3-08 capturable buildings:** oil field, solar farm, field hospital, data center, rail depot, cell tower. Infantry capture by standing next to them; enemies take them back. Placed mirrored on Riverside, Desert Crossroads and Frostwood; the AI captures them.
  - **P3-25:** `selection_controller.gd` split (`ArmedClicks`).
  - **Why the UAE and EU lost:** their logistics hubs had no free truck (America's and North Korea's do), so their early income ran at half speed; and the AI never counted unarmed support (medics, swarm trucks, jammers) and kept building it. Both fixed, with tests. The AI also now uses field repair and cyber defense.
  - **Balance:** after those fixes the new factions were too strong; trimmed in steps. Latest Riverside runs against America and North Korea: UAE about 40%, EU about 65% (15–20 games each, noisy).
- Tests: `tools/run_tests.sh` -> 321 tests, 0 failed (+ both smoke tests). `python3 tools/check_repo.py` -> ok (209 assets).
- Not verified: four-faction balance with large samples; superweapon and capture flow by touch on a phone.
- Next: P3-04 aircraft and airbases; P3-14 LAN multiplayer; P3-13 AI v2 (hard difficulty).
- For the owner: the four superweapons and six capturable buildings are first-pass designs from the docs; say if any effect should change.

---

## 2026-11-28: P3-12a EU, UAE mechanics (P3-02b/c/f), P1-30b, balance work (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **P3-12a EU:** all four factions are now playable in skirmish. 13 units (with combat medics and a patrol fighter), 8 buildings, 5 powers, 3 upgrades, `eu_default`, placeholder art. New mechanics: healing auras (`HealSystem`: medics heal infantry 3%/s, trucks repair vehicles 1%/s), `repair_area` and `cyber_defense` power kinds. The AI keeps unarmed helpers (medics) in the middle of its army. `test_eu.gd`.
  - **UAE:** sovereign fund (P3-02b, `FundSystem`), swarm-drone truck (P3-02c, `LaunchSystem`: real drone units), special-forces abilities (P3-02f: `AbilitySystem`, USE_ABILITY, "Call Strike" and "Disable Building", HUD buttons, AI use).
  - **P1-30b:** the 72 "material is null" errors came from wreck darkening stacked on team-color duplicates; wrecks now swap surface materials (0 errors); the smoke test guards it.
  - **Balance (P2-11f):** America counters infantry with rocket artillery too; mixed groups move at their slowest member's pace (`SimMover.group_speed`). US vs North Korea on the same seeds moved from 15–25 to about even.
  - **UAE balance (P3-02g, open):** units now match North Korea's cost-efficiency and the AI mix leans on tanks and missile teams; still 7 wins of 40.
- Tests: `tools/run_tests.sh` -> 303 tests, 0 failed (+ both smoke tests). `python3 tools/check_repo.py` -> ok.
- Not verified: four-faction balance beyond the runs above; the EU AI has not been measured against the others (P3-12d); a real-GPU check of the wreck fix.
- Next: P3-12d/P3-02g balance with AI runs; P3-25 split `selection_controller.gd`; P3-03 superweapons; P3-04 aircraft.
- For the owner: determinism hash is now 789762363 (group speed). The UAE wins only about 1 game in 6 against the AI factions so far.

---

## 2026-11-27: P3-02a UAE base roster, P1-30b bisect, HUD split (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **P3-02 split** into a–g in the backlog. **P3-02a:** the UAE is playable in skirmish. 12 units (engineer, contracted truck, rifle squad, missile team, special forces as a spotter, presidential guard unlock, desert raider, 8x8 IFV, tank, rocket launcher, laser vehicle, recon drone), 8 buildings, 9 weapons, 3 upgrades, 4 powers (satellite pass, 24-drone swarm strike, guard unlock, 4-missile stand-off strike) and the `ae_default` AI preset. Placeholder art for all 20 from the Blender specs, including two new wheeled options: `gun` (turreted 8x8) and `hmg` (open buggy). The menu has "You" and "Enemy" side by side; any faction can face any other. `ai_matches.gd` takes `vs=<f1>,<f2>`.
  - `test_factions.gd`: every playable faction has a start kit, an AI preset that only uses its own content, a way to build every unit, and powers in tiers 1 and 3; the UAE AI builds and fights against North Korea; its strike powers launch 24 drones and 4 missiles.
  - `hud.gd` split (438 → 258 lines): `CommandMenus`, `SelectionText`.
  - **P1-30b bisect:** the 3,300-frame `ai_duel` render logs the same 72 "material is null" errors with particle effects disabled, so particles are not the cause; the count is the same both times, so it follows game events.
  - **Balance (P2-11f):** with and without crushing, all 20 paired Riverside seeds had the same winner, so crushing did not cause the North Korea lean. Since the formation fix North Korea won 58 of 80 Riverside faction games. Desert Crossroads mirror runs with crushing: west 20, east 20.
- Tests: `tools/run_tests.sh` -> 279 tests, 0 failed (+ both smoke tests). `python3 tools/check_repo.py` -> ok (143 assets).
- Not verified: UAE balance (P3-02g); the UAE AI loses its first infantry to North Korea's early raids on Twin Ridge.
- Next: P2-11f (North Korea 72% on Riverside since the formation fix), P1-30b (bisect wrecks, status bars, team colors next), P3-02b sovereign fund.
- For the owner: the UAE uses working names only ("8x8 Infantry Fighting Vehicle", "Desert Raider"); real-world class names stay out of the game.

---

## 2026-11-27: P3-23a biomes and two maps, P3-07 crushing (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **P3-23 split** into a–d in the backlog. **P3-23a:** maps pick a `biome` (temperate, desert, winter). The view takes ground, water and house colors and the obstacle style from `Biomes`: rocks, sandstone mesas, or pine forests (two MultiMeshes for all trees). Obstacle drawing moved from `main.gd` to `MapFeaturesView`.
  - **Desert Crossroads** (bases in the south, a mesa block between them, an oasis town on the northern road) and **Frostwood** (forest lanes, a logging village between the northern bases, a frozen lake). Both 256 m, mirrored, offered for skirmish; `test_maps.gd` now checks reachability (including every house) on every skirmish map. Base-to-base paths are mirror images on all three maps.
  - **P3-07:** `CrushSystem` (after the spatial index, before combat): main battle tanks run down enemy infantry touching their front while they move, 100% of max hp per second (`crush_percent_per_s` in rules.json; the damage matrix's `crush` row limits it to infantry). Golden replays and the determinism hash regenerated (crushing is in the rules hash): new hash 303367140.
- Tests: `tools/run_tests.sh` -> 272 tests, 0 failed (+ both smoke tests). `python3 tools/check_repo.py` -> ok.
- AI runs on the new maps (40 each, before crushing): Frostwood west 19, east 20; America 13–7 in faction games. Desert Crossroads east 25, west 15; North Korea 15–5. Within noise for 20–40 games, but logged in P2-11f with a recheck.
- Not verified: frame rate of the forest maps on a phone (trees are MultiMeshes, so the draw-call count stays small); how crushing feels with touch controls.
- Next: P2-11f balance recheck with crushing (batch running), then P1-30b renderer errors, then P3-02 UAE.
- For the owner: the determinism hash changed again on purpose (crushing). Screenshots of the new maps: `docs/screenshots/maps/`.

---

## 2026-11-27: P2-11e, P3-22, P3-05, P3-20, P2-12b: balance, save/load, garrisons, colorblind colors, side fairness (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **P2-11e:** America's rocket artillery sat idle because its recon drones hovered over the army; spotters now fly 30 m ahead toward the target while the army attacks, and America keeps 3. Riverside went from about 85% North Korea to 23–17.
  - **P3-22 (v1):** "Save game" in the pause menu and "Load game" in the main menu. A save is the replay plus the state hash; loading fast-forwards behind a progress label and warns if the hash differs.
  - **P3-05 (v1):** infantry garrison town houses (now neutral buildings), bunkers and trench lines: +5 m range inside, can't be targeted, thermobaric weapons clear them, a destroyed building throws them out hurt. Right-click to enter, "Exit all" to leave. The AI holds up to 2 houses on its half.
  - **P3-20 (part):** "Colorblind-safe team colors" setting (Okabe-Ito palette).
  - **P2-12b:** the west won about 64% of same-faction matches on Riverside. Cause: move orders filled their formation grid west to east whichever way the army went. The grid now fills from the side facing the destination; mirror runs are west 43, east 35 (55%). New determinism hash: 545746504 (golden replays regenerated for this change). `ai_matches.gd` labels sides correctly with `flip`.
- Tests: `tools/run_tests.sh` -> 267 tests, 0 failed (+ both smoke tests). `python3 tools/check_repo.py` -> ok.
- Not verified: save/load on a phone (loading a long match fast-forwards it; time it on a low-end device); garrison controls with touch.
- Next: P3-23a biomes and new maps (in progress), then P3-07 crushing, then P2-11f (faction balance re-check: North Korea 26–14 in the latest Riverside batch).
- For the owner: the determinism hash changed on purpose (formation fix); CI compares against the new value in `game/data/determinism_check.json`.

---

## 2026-11-27: P2-11d, P2-15, P2-16, P2-17, P2-18: refactor, art export, infantry animation, UI and audio passes (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **P2-11d:** `sim_world.gd` (790 → 346 lines) and `content_db.gd` (710 → 412) split into helpers: `WorldCommands`, `WorldSpawn`, `WorldPlacement`, `WorldDamage`, `SpatialIndex`; `UnitLoader`, `MapLoader`, `PowerLoader`. No behavior change: golden replays, content hash and determinism hash unchanged.
  - **P2-15:** `tools/export_blend.sh` exports hand-made `art_source/<category>/<id>.blend` (+ a provenance `.json`) to the same outputs as the placeholders and records the artist in the manifest; refuses files without provenance, an allowed license or a `team_color` surface. Self-test: `tools/test_export_blend.sh` (passes with Blender 5.3).
  - **P2-16:** shared infantry rig (`blender/sf_rig.py`, armature `squad_rig`, bones per soldier) with 9 generated animations; all 7 infantry models rebuilt. `InfantryAnimator` drives an `AnimationTree` from sim state; soldiers now fall and lie still instead of flattening. Screenshots: `docs/screenshots/infantry/`.
  - **P2-17:** `UiTheme` (dark olive panels, steel-olive frames, amber highlights) with the OFL font Inter, set on the window and on the HUD layer's controls (a `CanvasLayer` stops theme inheritance). Command-grid buttons are 88×80 with icon, name, cost and an amber hotkey tag. Screenshots: `docs/screenshots/ui/`.
  - **P2-18:** 9 new generated sound effects (alerts, active protection, jamming, radio acknowledgements) wired to sim events with rate limits, and an original generated music track (`tools/gen_music.py`, 80 s loop) played by `MusicPlayer`.
  - Dev options for screenshots: `--select=<def_id>`, `--open=pause|settings|commander`.
- Tests: `tools/run_tests.sh` -> 253 tests, 0 failed. `python3 tools/check_repo.py` -> ok (103 assets).
- Not verified: the music and sounds were checked by level and length only (no listening here); the UI on a real phone; real-GPU rendering of the rig.
- Next: finish P2-11e (Riverside balance); P1-30b (renderer "material is null" errors).
- For the owner: listen to `game/assets/audio/music/main_theme.ogg` and say if the style fits; it can be regenerated with different settings.

---

## 2026-11-27: P2-12 Map "Riverside", gameplay video and phase screenshots (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **Riverside** (`riverside`): a 256 m 1v1 map, exactly mirrored across x = 128. A river runs north-south through the middle with two bridges 116 m apart, a small town sits on both banks between them, and farmland with hedgerows and copses fills the rest. Per side: a safe supply site, two farm expansions and a contested site in the town square. It is the default skirmish map; the menu has a map button.
  - Map format: `terrain_gen.channels` (carved river with sloped banks), `terrain_gen.mirror_x` (exact mirrored heights), `civilian_buildings_m` (blocking houses), `bridges_m` (view-only decks), `skirmish`. The view draws water, bridge decks and houses, and turns river banks to mud.
  - AI: at most 2 unarmed recon drones at once (`max_spotters`), and an army that hasn't grown for 90 s attacks without a full wave (a Twin Ridge duel deadlocked without it).
  - Fix: the pause/end screen, settings screen, commander panel and other overlays under the HUD kept a zero size (anchors set without offsets), so the end screen sat in the top-left corner with no shade. The menu smoke test now checks their size. The main menu's spacing was tightened so the new map row fits 720p.
  - Gameplay video tools: `--director` (camera follows the fighting, tours the bases when quiet, saves a screenshot every few game seconds, quits after the end screen), `--seed=`, `--speed=`, `--side=`, `--watch=<map>`, `--camera=`, and `--reveal` (now also shows every unit). Recipe in `docs/08-testing-and-qa.md`.
  - Media: Blender rebuilt every placeholder model and icon from source; the icons came out pixel-identical and the models structurally identical, so they were not recommitted. A 2:36 gameplay video (Riverside, North Korea's side, 3× speed, phase captions) and one screenshot per phase are in `docs/screenshots/gameplay_phases/`; the video stays out of the repo (27 MB).
- Result: Riverside side fairness over 80 runs: west 42, east 38 (52.5%). North Korea won 68 of 80 there, a balance problem logged as **P2-11e** with its cause (America's vehicle depot is starved by the barracks spending first).
- Tests: `tools/run_tests.sh` -> 247 tests, 0 failed (new `test_maps.gd`, AI drone-cap and stall tests, overlay size checks). `python3 tools/check_repo.py` -> ok. The determinism check is unchanged (3445782503).
- Not verified: touch play on a phone; the houses can't be garrisoned yet; Riverside's look with real art.
- Next: P2-11e (Riverside balance; a "save for the most-needed unit" change is drafted), then P2-11d (split `sim_world.gd` and `content_db.gd`).
- For the owner: watch the video and look through `docs/screenshots/gameplay_phases/`. On Riverside the computer playing America loses most games until P2-11e is done.

---

## 2026-11-27: P2-11c Faction balance and side fairness (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - AI play: recon drones (spotters) now move with the army, so America's rocket artillery has spotters; units still in a factory queue count toward the mix; both AIs think on the same tick.
  - Mirror matches (same faction on both sides) showed America-vs-America went to the west 8 of 8, North Korea-vs-North Korea to the east 8 of 8. Two causes:
    - Buildings with an odd width (most of them) snapped 2 m east of the requested point, so the east base was never a true mirror. `footprint_origin` is now an instance method that rounds ties toward the map middle; exit-cell ties do the same.
    - The AI had no randomness, so every seed replayed nearly the same game. Each AI now has its own seeded `SimRng`: wave size ±1, first attack ±15 s, a little unit-mix and target noise.
  - `ai_matches.gd` gained `seed=<first>` and `stats` (units produced and lost per player).
- Result (Twin Ridge, normal vs normal):
  - Canonical 40 runs (seeds 1000+): America 18, North Korea 20, 2 unfinished; east side 22 of 38.
  - 120 runs (seeds 1000, 2000, 3000): America 67, North Korea 49 (58%); east 62, west 54 (53%).
  - Mirror matches after the fix: west 24 of 40.
  - A 40-run sample swings about ±8%, so the 55%/60% rules need the larger runs to judge.
- Golden replays and the determinism check were regenerated (building placement changed on purpose). The phone should now show **3445782503**.
- Tests: `tools/run_tests.sh` -> 240 tests, 0 failed (new `test_fairness.gd`). `python3 tools/check_repo.py` -> ok.
- Not verified: human play; matches mostly end in 4 to 6 minutes, so the late game (powers, upgrades) barely affects these numbers.
- Next: P2-12 (map "Riverside"); P2-11d (split `sim_world.gd`, now about 790 lines).
- For the owner: the determinism-check number is now 3445782503. America leans slightly stronger over 120 runs (58%); I left unit numbers alone, since final tuning comes from playtests (P2-20).

---

## 2026-11-26: P2-11b West-side advantage found and removed (Claude Code, branch claude/phase-0-wrapup)
- Done: tested the suspects one at a time with `ai_matches.gd`.
  - On a flat, exactly mirrored copy of the sandbox, the west player still won 20 of 26, so map asymmetry was only part of it.
  - The AI's building-spot search tried east first: toward the front for the west base, toward the map edge for the east base. It is now mirrored for a base on the east half.
  - The mirrored map became a real skirmish map, **Twin Ridge** (`twin_ridge`), now used by the skirmish menu, `skirmish_vs_ai` and `ai_duel`. The sandbox stays as the developer test map.
- Result: 40 runs on Twin Ridge, normal vs normal, half with the factions swapped. Each side won exactly 20 (passes the 55% rule). But North Korea won all 40 from either side: a faction balance issue, logged as **P2-11c** with suspects.
- The determinism check plays the AI duel, which now uses Twin Ridge, so its hash changed again: the phone should show **3797961381**.
- Tests: `tools/run_tests.sh` -> 236 tests, 0 failed.
- Next: P2-11c (balance), P2-12 (map "Riverside").
- For the owner: the determinism-check number is now 3797961381.

---

## 2026-11-26: P2-11 Skirmish AI v1 (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **Difficulty:** easy and normal, chosen in the main menu ("Computer: Normal"). Easy thinks half as often, attacks a minute later with bigger waves, and doesn't counter-build or research.
  - **Counter-building:** the AI counts the enemy units it can see by armor class and adds weight to its preset's `counters` (anti-tank teams against armor, IFVs against infantry, the laser or EW vehicle against drones).
  - **Commander powers:** it spends points in `power_priority` order and aims them: strikes at the biggest visible enemy group (precision rockets only at spotted points), reveals and sweeps at the enemy base, jamming and wingmen at enemy groups, decoys in front of its own base.
  - **Research:** it buys its preset's upgrades.
  - Presets now build drone and air-defense buildings and field the wider slice roster. Code: `game/src/ai/ai_strategy.gd`.
- **Fairness fix:** fire is now simultaneous within a tick: a unit killed during combat still gets its shot, so lower entity ids (the player who spawned first) don't win every even trade. A new combat test proves it.
- **AI-vs-AI results** (`tests/tools/ai_matches.gd`, results in `build/ai/results.json`): normal vs normal, the west player won 8/8; with factions swapped, the west player still won 6/6; normal vs easy, normal won 6/6. So there is a strong **west-side bias** that is not faction balance. Logged as P2-11b with suspects (the sandbox map isn't mirrored, the AI's base layout favors the west, think order).
- The determinism check plays an AI duel, so its hash was regenerated: the phone should show **2376107880**.
- Tests: `tools/run_tests.sh` -> 236 tests, 0 failed (new AI tests for difficulty, counters, powers and research; simultaneous-fire combat test).
- Not verified: how the AI feels to play against.
- Next: P2-11b (the west-side bias), then P2-12 (map "Riverside").
- For the owner: the determinism-check number is now 2376107880.

---

## 2026-11-26: P2-10 Slice content data (Claude Code, branch claude/phase-0-wrapup)
- Done: every America and North Korea slice unit and building carries the first-pass numbers from `docs/design/vertical-slice.md`, marked "first-pass numbers" in its data. New `test_slice_data.gd` reads the doc's tables and checks every unit (cost, hp, armor, speed, weapon type, damage, splash, range, reload) and building (cost, hp, power) against `game/data`, so the two can't drift apart. The loader now also rejects a minimum range at or above the range, a splash edge outside 0–100%, endurance on non-flyers, and units without vision (except decoys).
- The test found one real mismatch: North Korea's infantry squad used America's rifles (12 damage instead of 10). It now has its own `kp_assault_rifles`. That changes fights, so the golden replays and the determinism-check hash were regenerated; the phone check now expects **122369364**.
- Tests: `tools/run_tests.sh` -> 232 tests, 0 failed.
- Not verified: balance (that's for playtests).
- Next: P2-11 skirmish AI v1.
- For the owner: the determinism-check number changed to 122369364.

---

## 2026-11-26: P2-09b Power bar and commander tree UI (Claude Code, branch claude/phase-0-wrapup)
- Done: a power bar under the top bar. Its "Commander" button shows unspent points and opens the commander panel (the faction's tree grouped by rank, with Choose buttons). Each chosen power gets a button with its cooldown; targeted powers wait for a click or tap on the map (crosshair cursor), others fire at once. While an enemy cyberattack is on, the minimap shows "SIGNAL LOST". Works with mouse and touch.
- Tests: `tools/run_tests.sh` -> 229 tests, 0 failed; smoke_main chooses a power in the panel, uses it from the bar with a map click, checks the cooldown, and checks the blinded minimap. Checked on a real render: the bar sits clear of the top bar.
- Not verified: on a phone; with many powers the bar can reach the F1 help text (P2-17 UI pass).
- Next: P2-10 slice content data, then P2-11 skirmish AI v1 (it should use powers).
- For the owner: none.

---

## 2026-11-26: P2-09a Commander powers in the sim (Claude Code, branch claude/phase-0-wrapup)
- Done: commander powers are data (`game/data/powers/`). Rank gives points (rank N = N powers); a power's tier is the rank needed to choose it. New commands CHOOSE_POWER and USE_POWER with cooldowns. Powers:
  - America: Satellite Recon Pass (reveals 35 m for 20 s and counts as a kill-chain spotter), Precision Rocket Strike (3 guided rockets, only at a spotted point), Drone-Wingman Patrol (2 armed jets patrol for 60 s), Cyberattack (enemies "blinded" for 30 s), and an unlock for the Special Recon Team.
  - North Korea: Recon Drone Sweep (a drone crosses the map through the point), Reserve Call-Up (3 free squads at the HQ), Rocket Barrage (24 scattered heavy rockets, interceptable), GPS Jamming (a 40 m jamming zone for 20 s), an unlock for the Artillery Spotter Officer, and the rank-5 Decoy Deployment (6 decoy tanks).
  - Powers build ordinary entities: strikes, units, and short-lived untargetable "sensors" for reveals, sweeps and jamming. Timed entities expire on their own.
  - Three new units with placeholder models: Wingman Drone, Special Recon Team and Artillery Spotter Officer. The two officers/teams are spotters and need their unlock before barracks can train them.
- Tests: `tools/run_tests.sh` -> 229 tests, 0 failed (new `test_powers.gd` covers every power, points, tiers, cooldowns, unlocks and determinism); golden replays unchanged.
- Not verified: there is no power bar yet, so players can't use powers in a match. That is P2-09b, next.
- For the owner: none.

---

## 2026-11-26: P2-08 Decoys (Claude Code, branch claude/phase-0-wrapup)
- Done: decoys are units with `"decoy_of"` (the unit they imitate) and 1 hp. North Korea gets an inflatable **Decoy Tank** that uses the real tank's model. Enemies see and shoot it as a real tank until one of their units comes within 15 m or one of their recon drones flies within 12 m; from then on that team ignores it. Revealing is per team and permanent. The owner sees their decoys translucent, and so does an enemy who has seen through one. New `DecoySystem`.
- Tests: `tools/run_tests.sh` -> 214 tests, 0 failed (new `test_decoys.gd`: data, enemies waste a shot and one hit kills, close units see through and stop shooting, recon flyover reveals, far drones don't, per-team reveal, determinism); golden replays unchanged.
- Not verified: nothing deploys decoys in play yet (P2-09's North Korea power will).
- Next: P2-09 commander power tree (ranks 1–3, America and North Korea), which also launches strikes and decoys.
- For the owner: none.

---

## 2026-11-26: P2-07 Interceptable strikes (Claude Code, branch claude/phase-0-wrapup)
- Done: missiles and strike jets are now sim entities (armor class "aircraft") defined in `game/data/strikes/` (guided rocket, heavy rocket, strike jet). `StrikeSystem.launch()` sends one in from the map edge on the launcher's side; on arrival it delivers its payload (a jet drops 4 bombs and flies home; a missile ends). Air-defense sites can shoot them down, but now carry a limited interceptor stock (4, one back every 15 s). Strikes can't be selected and don't keep a player alive for victory. The view draws them as simple missile and jet shapes at altitude; missiles dive at the end.
- Tests: `tools/run_tests.sh` -> 208 tests, 0 failed (new `test_strikes.gd`: data, missile hits, jet bombs and leaves, air defense shoots down and spends stock, stock runs out and refills, victory, determinism); golden replays unchanged.
- Not verified: nothing launches strikes in play yet; the commander powers in P2-09 will.
- Next: P2-08 decoys, then P2-09 commander powers.
- For the owner: none.

---

## 2026-11-26: P2-06 Active protection and cage armor (Claude Code, branch claude/phase-0-wrapup)
- Done: America's tank carries 2 active-protection charges. When a guided anti-tank missile or loitering munition comes within 12 m, a charge fires and destroys it 90% of the time (`SimRng`); charges reload one every 20 s. North Korea's tank has cage armor: the first 2 drone hits (loitering munitions, or anything fired by a drone) do 25% damage. The IFV kits from P2-05 use the same rules. Interceptions flash and make a sound. New `ProtectionSystem` (recharge after combat), `drone_attack` weapon field, `aps_charges` and `cage_hits` unit fields.
- Golden replays and the determinism-check hash were regenerated: tanks now carry protection state, which is part of the state hash. Fights in those replays use only cannons and rifles, which active protection ignores, so the outcomes are the same. The phone determinism check now expects **4002681017**.
- Tests: `tools/run_tests.sh` -> 201 tests, 0 failed (new `test_protection.gd`: data, about 90% interceptions with one charge each, no charges no interception, reload, unguided shots ignored, cage only on the first drone hits, loitering munitions count as drone hits, IFV kit, determinism).
- Not verified: balance.
- Next: P2-07 interceptable strikes.
- For the owner: the determinism-check number for the phone test changed to 4002681017.

---

## 2026-11-26: P2-05 Upgrades system (Claude Code, branch claude/phase-0-wrapup)
- Done: upgrades are data (`game/data/upgrades/`). **Global** upgrades are researched at a building (costs credits, takes time, half speed on low power) and apply to every matching unit, existing and future. **Per-unit kits** are bought for selected units. Effects: speed, health, damage, range and vision percentages, plus active-protection charges and cage hits (used by P2-06). Requirements: buildings, commander rank, faction. Six slice upgrades:
  - America: Self-Driving Logistics (rank 5), Composite Armor, and an Active Protection Kit for the IFV.
  - North Korea: Reactive Armor, Extended-Range Shells, and a Cage Armor Kit for the IFV.
- Controls and view: a selected building shows its research buttons (with progress), and selected units show kit buttons in the top row of the grid. Model parts named `upg_*` stay hidden until owned; the two IFVs were rebuilt with kit parts.
- Tests: `tools/run_tests.sh` -> 193 tests, 0 failed (new `test_upgrades.gd`: loading, research time, cost and effects on old and new units, rules, low power, kits per unit, building requirement, range, round trip, determinism); smoke_main buys a kit through the grid and checks the part appears.
- Not verified: balance and button text length on phones.
- Next: P2-06 active protection and cage armor.
- For the owner: none.

---

## 2026-11-26: P2-04 Kill chain (Claude Code, branch claude/phase-0-wrapup)
- Done: America's rocket artillery now fires guided rockets that need a spotter: beyond its own 40 m sight it only fires at targets a friendly spotter (the recon drone, for now) can see. A tank seeing the target isn't enough. If the spotter dies, is jammed or is spoofed, rockets already in the air lose guidance and fly to the last known point. New `spotter` (units) and `needs_spotter` (weapons) data fields and a `KillChainSystem`.
- Fixed along the way: jammed drones were drifting at full speed (a new drift point every time they reached the last one); they now drift one 2 m step a second and hover in between.
- Tests: `tools/run_tests.sh` -> 184 tests, 0 failed (new `test_kill_chain.gd`: data, no spotter no fire, spotted targets hit at 100 m, own sight needs no spotter, jammed spotters don't count, guidance lost when the spotter dies, determinism). The audio test now expects the missile sound for the guided rocket pod.
- Not verified: balance; there is no UI hint yet showing which targets are spotted (a P2-17 UI pass item).
- Next: P2-05 upgrades system.
- For the owner: none.

---

## 2026-11-26: P2-03 Jamming fields and spoofing (Claude Code, branch claude/phase-0-wrapup)
- Done: North Korea's EW vehicle now projects a 40 m jamming field (shown as a purple ring). Enemy drones inside lose control: they hover and drift, can't fire, ignore orders, and crash if their endurance runs out before they drift clear. Guided missiles fired at targets inside a hostile field lose lock half the time and scatter 4–10 m (deterministic `SimRng`). Fiber-optic drones are immune. The vehicle's **Spoof** button (then click a point up to 70 m away, every 30 s) sends enemy drones in a 25 m area to random points for 5 s; armed ones attack a random nearby entity, which can be their own side. New `SimJammer` component, `JammingSystem`, and a `SPOOF` command. Jammer state is hashed only where it exists, so golden replays still match.
- Tests: `tools/run_tests.sh` -> 177 tests, 0 failed (new `test_jamming.gd`: data, loss of control, own side and range, crash, no firing, fiber-optic immunity, about half of guided shots lose lock, unguided unaffected, spoof radius, range and cooldown, spoofed friendly fire, determinism, command round trip); smoke_main checks the Spoof button end to end.
- Not verified: balance; how the ring reads at phone size.
- Next: P2-04 kill chain (America's long-range weapons need spotters).
- For the owner: none.

---

## 2026-11-26: P2-02 Counter-drone weapons (Claude Code, branch claude/phase-0-wrapup)
- Done: three counter-drone weapon kinds. The laser (America's laser vehicle) is a single-target, drone-only weapon drawn as a cyan beam. A new `cone_deg` field makes microwave emitters (`hpm_emitter`) hit every drone inside a cone. An airburst gun (`cuas_airburst_gun`) uses splash against drone groups. Splash now only hurts what a weapon can target, so artillery no longer damages drones flying over its impact point. The microwave and the gun are weapon data for the Phase 3 rosters (UAE, EU); no slice unit carries them yet.
- Tests: `tools/run_tests.sh` -> 166 tests, 0 failed (new `test_counter_drone.gd`); golden replays unchanged.
- Not verified: balance.
- Next: P2-03 jamming fields and spoofing (North Korea's jamming vehicle).
- For the owner: none.

---

## 2026-11-26: P2-01 Drone flight, endurance and return (Claude Code, branch claude/phase-0-wrapup)
- Done: Phase 2 started at the owner's request. Drones now fly: they take a straight line over rocks and cliffs and don't push or get pushed by ground units. Each drone has an endurance (America's recon drone 90 s, North Korea's 120 s). At 20% it flies back to the building that made it, ignoring other orders, and recharges there (full in 10 s); docked drones settle onto the pad in the view. Without a launcher, a drone crashes when its endurance runs out. New `SimDrone` component and `DroneSystem` (after `OrderSystem`). Drone state is hashed only for drones, so the golden replays still match.
- Tests: `tools/run_tests.sh` -> 161 tests, 0 failed (new `test_drones.gd`: data, straight flight over a wall, no pushing, crash, return and recharge, returning drones ignore orders, produced drones remember their launcher, determinism).
- Not verified: how it feels in play; the endurance isn't shown in the HUD yet (comes with the P2-17 UI pass).
- Next: P2-02 counter-drone weapons, then P2-03 jamming.
- For the owner: none.

---

## 2026-11-26: Owner decisions applied: name, factions, art direction (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **Name:** the game is now **Project Zero Hour** everywhere (menu, project, Android package `io.github.jamonlineph.projectzerohour`, build file names, docs, credits). A trademark and store-name check (P0-10) is still required before any store release, because "Zero Hour" is also the name of the game this one is inspired by (see Q-1).
  - **Factions:** America (`us`), the UAE (`ae`), North Korea (`kp`) and the EU (`eu`) replace the China, Russia and Irregulars drafts. New faction designs, rosters, buildings, superweapons and power trees in `docs/design/`. The Russia slice roster became North Korea's (`ru_*` ids renamed to `kp_*`, models and icons rebuilt with the new palette), so the vertical slice is **America vs North Korea**. The UAE and the EU are designed and scheduled for Phase 3 (P3-02, P3-12).
  - **Art direction:** "classic 2000s military RTS look" in `docs/04-art-pipeline.md`, with the originality boundary spelled out (nothing traced or recreated from other games).
  - Golden replays and the determinism-check hash were regenerated, because unit ids are part of the state hash. Behavior did not change; only the ids did.
- Tests: `tools/run_tests.sh` -> 153 tests, 0 failed; `python3 tools/check_repo.py` -> ok.
- Not verified: the in-game menu title on a real screen.
- Next: same as before: device checks (owner), then Phase 2.
- For the owner: Q-2, Q-4, Q-5 and Q-7 are still open. The determinism check's expected value changed with the ids: the phone should now show the hash in `game/data/determinism_check.json`.

---

## 2026-11-26: P1-36 and P1-37 code parts (Claude Code, branch claude/phase-0-wrapup)
- Done:
  - **P1-36:** the project falls back to the OpenGL (Compatibility) renderer on devices without Vulkan (`rendering_device/fallback_to_opengl3`). Settings has a quality preset (Low: 67% resolution, no shadows, 30 fps; Medium; High). On first run, devices on the fallback renderer or with under about 4.5 GB of memory start on Low.
  - **P1-37:** Settings > Developer > "Determinism check" plays a fixed AI-vs-AI match (`data/determinism_check.json`: ai_duel, seed 7, 1,800 ticks) and shows whether its final state hash equals the desktop's (2876121879). A unit test keeps the stored hash honest; `tools/regen_golden_replays.sh` updates it with the golden replays.
- Tests: `tools/run_tests.sh` -> 153 tests, 0 failed; smoke_menu runs the in-game determinism check and gets "Match".
- Not verified, and how the owner can finish both tasks:
  1. Install the debug APK from the latest CI run (Actions > newest run > artifact "android-debug-apk") on a phone.
  2. Open Settings > Developer > Determinism check > Run. "Match: 2876121879" means P1-37 passes; write the phone model and result in PROGRESS. "MISMATCH" means the sim differs on ARM; open an issue with the number shown.
  3. On a low-end phone, play a skirmish for 5 minutes on the Low preset and note whether it stays smooth (30 fps or better). That is P1-36's check.
- Next: P0-12, P0-13 and P0-15 device checks (owner), then P1-EXIT. Device-free Phase 2 work can start meanwhile.
- For the owner: the device steps above, plus Q-1 to Q-7.

---

## 2026-11-26: P1-24b Guard and patrol orders (Claude Code, branch claude/phase-0-wrapup)
- Done: two new sim orders and commands. PATROL attack-moves to the far end and back, forever; each unit patrols between its own start and the place it reached, and stops to fight on the way. GUARD keeps armed units within 6 m of an own or allied unit or building, attacks the nearest visible enemy within 25 m of it (chasing only inside that radius), and ends when the ward dies. Controls: G then click (or the Guard button) to guard; the Patrol button then click; radial menu "Patrol here" and "Guard this"; right-click cancels a pending order. The patrol's far end only enters the state hash while a unit patrols, so golden replays recorded earlier still match.
- Tests: `tools/run_tests.sh` -> 150 tests, 0 failed (new `test_orders.gd`: back and forth, fights on the way, guard follows, guard attacks only near its ward, ends when the ward dies, can't guard an enemy, command round trip, determinism); smoke_main orders a guard and a patrol through the real click path.
- Not verified: on a phone.
- Next: P1-30b (renderer errors under software OpenGL); then the Phase 1 checks only the owner can do.
- For the owner: none.

---

## 2026-11-26: P1-30 Terrain and map format v1 (Claude Code, branch claude/phase-0-wrapup)
- Done: maps are folders (`game/data/maps/<id>/map.json` plus `height.r16`, raw 16-bit heights, one per 2 m cell). The sim gets integer heights; a cell more than `max_step_cm` above a neighbor is an impassable cliff edge, and cells under `water_level_cm` are water. `TerrainView` builds the ground mesh from the same heights (colored by slope and height, darkened by fog). Units, rocks, effects, move markers and the placement ghost sit on the terrain, and mouse and touch picking follow the hills. The sandbox is now a map folder with gentle hills and raised rocks inside its obstacle rectangles, so passability is unchanged (golden replays still match). `tools/make_heightmap.py` builds `height.r16` from `terrain_gen` in `map.json`.
- Tests: `tools/run_tests.sh` -> 142 tests, 0 failed (new `test_terrain.gd`: loader, exact scaling, bad file size, cliffs, water, sandbox passability unchanged, terrain mesh equals sim heights); smoke_main checks every unit stands on the drawn terrain.
- Not verified: hills steep enough to matter in play (the sandbox's are gentle on purpose); splat textures and props are not in yet.
- Found while rendering: renderer errors "material is null" late in long matches under software OpenGL. Logged as P1-30b with reproduction steps.
- Next: P1-24b guard and patrol, P1-30b, then the owner-only Phase 1 checks (P0-12, P0-13, P0-15, P1-36, P1-37, P1-EXIT).
- For the owner: none new.

---

## 2026-11-26: First real renders; P1-28 Effects; P1-29 Audio (Claude Code, branch claude/phase-0-wrapup)
- **First real look at the game.** A Godot build with OpenGL now runs on this machine through a virtual display and Mesa's software renderer, so the game was rendered for the first time (`docs/screenshots/`). New `--screenshot=<file>` option (`DevCapture`); how-to in `docs/08-testing-and-qa.md`. What it showed, and the fixes:
  - Colors were washed out to near white. Blender palette colors were being treated as linear; `sf_common.get_material` now converts them from sRGB, and all 35 models were rebuilt. Scene ambient light and sun were also turned down.
  - The camera started away from the base; it now starts on the player's HQ.
  - The F1 help ran off the screen; it now wraps.
  - Since P1-32, `-- --scenario=<id>` no longer skipped the menu (the menu became the main scene). The menu now honors it again.
  - A custom-cursor texture leaked at exit; it is released when the match closes.
- **P1-28 effects:** `CombatEffects` keeps pools of particle effects (muzzle flash, explosion sized by splash radius, smoke, death blast) and tracers for instant weapons, driven by sim events. Nothing plays where the player can't see. Battery saver halves particle counts. New perf scenario `effects_50` (50 explosions a second).
- **P1-29 audio:** audio buses (Master, Music, SFX, UI, Voice), a pool of 3D sound players with a per-sound rate limit, and 11 original placeholder sounds synthesized by `tools/gen_sounds.py` (weapons by type, explosions, UI click, unit acknowledgement, construction complete). The Settings volume sliders now work.
- Tests: `tools/run_tests.sh` -> 134 tests, 0 failed (new `test_audio.gd`); smoke_main checks that combat plays effects and sounds.
- Not verified: effects and sounds on a phone; how the synthesized sounds feel (they are rough placeholders); lighting under the Mobile renderer (the screenshots use Compatibility).
- Next: P1-30 terrain and map format, then P1-24b guard and patrol.
- For the owner: look at `docs/screenshots/` and say whether the look is heading the right way (Q-6).

---

## 2026-11-26: P1-24 Touch controls (Claude Code, branch claude/phase-0-wrapup)
- Done: a touch bar above the minimap with Clear, a Box toggle (one-finger drag selects instead of panning) and group buttons 1–5 (tap selects, tap twice jumps the camera, hold 0.5 s stores; each shows its size). Holding a finger still for 0.6 s opens a radial menu with the orders that fit the selection: attack-move here, move here, stop, hold, rally here. Touch gestures moved out of `SelectionController` into `TouchGestures`. Guard and patrol need new sim orders, so they became P1-24b.
- Tests: `tools/run_tests.sh` -> 129 tests, 0 failed; smoke_main drives the group buttons, Clear, box mode, the long press and the radial menu through the real code paths.
- Not verified: on a real phone (button sizes, the 0.6 s hold, notches). That check belongs to P0-12.
- Next: P1-28 effects, P1-29 audio, P1-30 terrain.
- For the owner: when you try the APK, check that the touch bar is reachable with your thumb and that the long press feels right.

---

## 2026-11-26: P1-35 Settings (Claude Code, branch claude/phase-0-wrapup)
- Done: a Settings screen, reached from the main menu and the pause menu, with render scale, frame-rate limit (30/60/unlimited), shadows, battery saver (30 fps, lower resolution, no shadows), interface size, edge panning, key rebinding (a key already in use is swapped) and volume sliders. Every change applies at once and is saved in `user://settings.cfg` (`GameSettings`). Tests use scratch files, never the player's settings.
- Tests: `tools/run_tests.sh` -> 129 tests, 0 failed (new `test_settings.gd`); smoke_menu opens Settings from both menus and checks that battery saver applies and is saved.
- Not verified: how the screen looks on a phone; volume sliders do nothing until the audio buses exist (P1-29).
- Next: P1-24 touch controls, then P1-28 effects and P1-29 audio.
- For the owner: none.

---

## 2026-11-26: P1-23 Desktop controls (Claude Code, branch claude/phase-0-wrapup)
- Done: control groups (Ctrl+1–9 store, 1–9 select, twice quickly centers the camera, Shift+1–9 adds), camera bookmarks (Ctrl+F5–F8 save, F5–F8 return), Space + left-drag panning for trackpads, a hover ring on the unit under the mouse (red on enemies), and cursor shapes for select, move, attack (a red crosshair drawn in code) and valid or invalid placement. The F1 help lists the new keys.
- Tests: `tools/run_tests.sh` -> 123 tests, 0 failed (new `test_controls.gd`); smoke_main drives groups, bookmarks (real key events), Space-drag, cursor states and hover; smoke_menu ok.
- Not verified: how the cursors look on a real desktop.
- Next: P1-35 settings (rebinding, render scale, fps cap), then P1-24 touch controls.
- For the owner: none.

---

## 2026-11-26: P1-33 Performance harness (Claude Code, branch claude/phase-0-wrapup)
- Done: `tools/run_perf.sh` runs three fixed scenarios headless (two 150-unit armies fighting; 300 vehicles marching through the sandbox ridge gap; the view syncing 300 entities) and writes `build/perf/latest.json`. CI fails when a scenario's normalized median (ms per tick ÷ a calibration workload) is more than 20% above `game/tests/perf/perf_baseline.json`. `--profile` prints ms per tick for each sim system.
- The harness found the sim far over budget, so I optimized it without changing any result (golden replays still match bit for bit):
  - Target search skips friendly units through a per-team spatial index, and distance checks use exact squared comparisons instead of square roots.
  - Separation inlines its cheap overlap test and reads the padded walk grid.
  - Vision stamps each (team, cell, sight radius) circle once.
  - Result on this desktop: battle 34 → about 9 ms per tick, march 79 → about 12 ms.
- Tests: `tools/run_tests.sh` -> 118 tests, 0 failed (golden replays unchanged); smoke tests ok.
- Not verified: phone speed. The phone budget is 8 ms per tick at 300 units and a mid-range phone is roughly 3× slower than this desktop, so we are probably still over. That is P1-33b, and Q-7 asks the owner whether native code is allowed.
- Next: P1-23 desktop controls.
- For the owner: Q-7 (native code for the sim's hot spots).

---

## 2026-11-26: P1-27 Fog rendering (Claude Code, branch claude/phase-0-wrapup)
- Done: `FogOfWar` turns the local team's vision into a texture after every sim tick; a terrain shader (`fog_terrain.gdshader`) draws unexplored ground nearly black and explored-but-unseen ground at 45% brightness, with soft edges. Ground and rocks use it. Supply sites appear once explored. The minimap already had fog.
- Tests: `tools/run_tests.sh` -> 118 tests, 0 failed; smoke_main now checks that every enemy view is hidden exactly when the player can't see it, and that the fog texture matches the sim's grid.
- Not verified: the shader has not been compiled on a GPU yet (the headless build skips shaders). Checking it next with a software-OpenGL build.
- Next: P1-33 performance harness.
- For the owner: none.

---

## 2026-11-26: P1-22 Unit views v2 (Claude Code, branch claude/phase-0-wrapup)
- Done: health bars (shown when damaged or selected; green, yellow, red), veterancy pips, turrets that turn toward their target and barrels that rise for artillery, shots that flash at the model's `muzzle_0`, and wrecks: destroyed vehicles and buildings turn dark, stay 20 s and sink away; infantry and drones vanish. Death flashes in the fog are no longer drawn. Blender models now have `turret`/`barrel` pivots (rocket pods, the laser mount and SAM launchers too), and all 35 assets were rebuilt.
- Tests: `tools/run_tests.sh` -> 118 tests, 0 failed; smoke_main (now also checks turret aim, health bar rules, pips and wrecks) ok; smoke_menu ok.
- Not verified: no screenshot yet, because this machine has no screen. Bar sizes and colors may need tuning once someone looks (P0-15).
- Next: P1-27 fog rendering, then P1-33 performance harness.
- For the owner: none.

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
