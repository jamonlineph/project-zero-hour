# Vertical slice (Phase 2): United States vs Russia

**Goal:** one matchup that feels like the finished game, played on a phone and a Googlebook. US vs Russia shows the core 2026 duel best: precision and drones against jamming and artillery.

## Scope

- **Map:** one 256×256 m 1v1 map, "Riverside" (farmland, a river with two bridges, a small town in the middle).
- **Commander:** ranks 1–3 only, with the rank-1 and rank-3 powers in [commander.md](commander.md).
- **AI:** v1, easy and normal.
- **Art:** final-quality Blender models and icons for everything listed below.
- **Audio:** weapon sounds, explosions, unit acknowledgements (voice lines optional), and one music track.

## Units (first-pass numbers; tune in playtests)

Speeds in cm/s; ranges in meters; reload in seconds; build time in seconds.

| ID | Role | Cost | HP | Armor | Speed | Weapon (type, damage, range, reload) | Notes |
|---|---|---|---|---|---|---|---|
| `us_engineer` | Builder | 1,000 | 600 | light_vehicle | 600 | — | Builds and repairs |
| `us_logistics_truck` | Gatherer | 600 | 500 | light_vehicle | 700 | — | |
| `us_rifle_squad` | Basic infantry | 250 | 240 | infantry | 380 | small_arms 12, 30 m, 1.0 s | Can capture (P3) |
| `us_at_team` | Anti-tank infantry | 400 | 200 | infantry | 340 | anti_tank 140, 45 m, 4.0 s | Top-attack |
| `us_ifv` | Armored transport | 800 | 700 | light_vehicle | 800 | autocannon 25, 40 m, 0.8 s | Carries 1 squad |
| `us_mbt` | Main battle tank | 1,000 | 1,200 | heavy_armor | 750 | anti_tank 160, 50 m, 3.0 s | Active protection: 2 charges |
| `us_rocket_artillery` | Artillery | 1,300 | 450 | light_vehicle | 700 | high_explosive 220 (splash 6 m), 160 m, 10 s | Kill chain; shoot and scoot |
| `us_laser_cuas` | Counter-drone | 900 | 450 | light_vehicle | 650 | counter_drone 60, 50 m, 0.5 s | Drones only |
| `us_recon_drone` | Recon drone | 300 | 60 | drone | 1,600 | — | Spotter; endurance 90 s |
| `ru_engineer` | Builder | 900 | 650 | light_vehicle | 550 | — | Also digs trenches |
| `ru_logistics_truck` | Gatherer | 600 | 650 | light_vehicle | 600 | — | Armored |
| `ru_motor_rifle_squad` | Basic infantry | 200 | 220 | infantry | 360 | small_arms 10, 30 m, 1.0 s | |
| `ru_at_team` | Anti-tank infantry | 350 | 200 | infantry | 330 | anti_tank 130, 50 m, 4.5 s | |
| `ru_ifv` | Armored transport | 700 | 650 | light_vehicle | 750 | autocannon 30, 40 m, 1.0 s | Carries 1 squad |
| `ru_mbt` | Main battle tank | 850 | 1,100 | heavy_armor | 700 | anti_tank 150, 45 m, 3.2 s | Cage armor: first 2 drone hits do 25% |
| `ru_howitzer` | Artillery | 1,100 | 500 | heavy_armor | 500 | high_explosive 180 (splash 8 m), 140 m, 7 s | Counter-battery radar synergy |
| `ru_ew_vehicle` | Counter-drone | 1,000 | 550 | light_vehicle | 550 | — | Jamming field, 40 m radius |
| `ru_recon_drone` | Recon drone | 250 | 50 | drone | 1,400 | — | Spotter; endurance 120 s |
| `ru_loitering_team` | Strike drones | 600 | 180 | infantry | 340 | Launches a loitering drone: anti_tank 200, 200 m, 25 s | Drone can be jammed |

## Buildings

Power is listed as produced (+) or used (−).

| ID | Cost | HP | Power | Notes |
|---|---|---|---|---|
| `us_command_hq` / `ru_command_hq` | — (start) | 5,000 | +5 | Builds the builder |
| `us_microreactor` / `ru_power_plant` | 800 | 1,200 | +10 | |
| `us_barracks` / `ru_barracks` | 500 | 1,500 | −1 | Infantry |
| `us_logistics_hub` / `ru_logistics_hub` | 1,500 | 1,800 | −1 | Drop-off; comes with 1 free gatherer |
| `us_vehicle_depot` / `ru_vehicle_plant` | 2,000 | 2,500 | −2 | Vehicles |
| `us_drone_center` / `ru_drone_launch_site` | 1,200 | 1,400 | −2 | Drones and loitering teams |
| `us_bunker` / `ru_trench_line` | 600 / 150 | 1,500 / 400 | 0 | Garrisonable (P3); trenches built by the engineer |
| `us_sam_site` / `ru_sam_site` | 1,000 | 1,100 | −3 | Air defense, intercepts strikes |

## Exit check

Five or more testers each play at least three matches against AI v1 on a phone and on a Googlebook. Most say they would play again, nobody hits a crash, and performance budgets are met ([../05-platforms.md](../05-platforms.md)).
