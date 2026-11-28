# Units and buildings

Rosters as **role × faction** tables. Every faction fills the same roles in its own way.

- Names here are working names. "X-class" marks a real-world reference and **never appears in the game**.
- IDs (`us_mbt` and so on) are the data file names in `game/data/units/` and `game/data/buildings/`. Prefixes: `us_` America, `ae_` UAE, `kp_` North Korea, `eu_` EU.
- First-pass numbers for the Phase 2 matchup (America vs North Korea) are in [vertical-slice.md](vertical-slice.md). Ids marked ✓ already exist with placeholder art.
- The UAE's first roster (P3-02a) is in `game/data/` with first-pass numbers: fewer, pricier, faster units. Its raider is simply fast until terrain types exist (P3-02d); the swarm-drone truck came in P3-02c; procurement comes in P3-02e.
- The EU's first roster (P3-12a) is in `game/data/` too: tough, well-rounded units, combat medics and logistics trucks with healing auras (`heal_aura`), and a patrol fighter for the air-policing power. Doctrine units and the interoperability bonus come in P3-12b and P3-12c.

## Units

| Role | America (`us_`) | UAE (`ae_`) | North Korea (`kp_`) | EU (`eu_`) |
|---|---|---|---|---|
| Builder | Armored engineer vehicle `engineer` ✓ | Engineering vehicle `engineer` ✓ | Combat engineer vehicle `engineer` ✓ (also digs trenches) | Engineer tank `engineer` ✓ (repairs faster) |
| Gatherer | Logistics truck `logistics_truck` ✓ (self-driving upgrade) | Contracted truck `logistics_truck` ✓ (fast, unarmored) | Armored logistics truck `logistics_truck` ✓ | Logistics truck `logistics_truck` ✓ (repairs vehicles nearby) |
| Basic infantry | Rifle squad `rifle_squad` ✓ | Rifle squad `rifle_squad` ✓ | Infantry squad `infantry_squad` ✓ (cheap, mass) | Rifle squad `rifle_squad` ✓ |
| Anti-tank infantry | Top-attack missile team `at_team` ✓ | Missile team `at_team` ✓ | Missile team `at_team` ✓ (Bulsae-class) | Missile team `at_team` ✓ |
| Specialist | Sniper team `sniper_team`: spots for the kill chain, detects stealth | Special forces team `sf_team` ✓: calls precision strikes, disables buildings | Infiltration team `infiltrators`: stealthy, sabotage | Combat medic team `medics` ✓: heals infantry |
| Elite (limit 1) | Special recon team `recon_team`: marks targets for every long-range weapon | Presidential guard detachment `guard_unit` ✓: elite assault infantry | Artillery spotter officer `spotter_officer`: doubles artillery accuracy nearby | Doctrine unit (see below) |
| Light vehicle | JLTV-class `light_vehicle` (carries 4) | Desert raider buggy `raider` ✓ (fast off-road) | Light utility truck `light_truck` | Boxer-class 8×8 `apc` ✓ |
| Armored transport | Bradley-class IFV `ifv` ✓ | Rabdan-class 8×8 IFV `ifv` ✓ | VTT-323-class IFV `ifv` ✓ | CV90-class IFV `ifv` ✓ |
| Main battle tank | Abrams-class `mbt` ✓ + active protection | Leclerc-class `mbt` ✓ | Chonma-class `mbt` ✓ + cage armor | Leopard 2A8-class `mbt` ✓ |
| Artillery | HIMARS-class `rocket_artillery` ✓ (shoot and scoot) | Jobaria-class rocket launcher `rocket_artillery` ✓; G6-class wheeled howitzer `howitzer` | Koksan-class long-range gun `howitzer` ✓; heavy rocket launcher `rocket_artillery` (KN-25-class) | CAESAR-class truck howitzer `howitzer` ✓ (fast to deploy) |
| Anti-air | M-SHORAD-class `shorad` | Pantsir-class `shorad` | Pongae-class missile vehicle `shorad` | IRIS-T-class `shorad` |
| Counter-drone | Laser vehicle `laser_cuas` ✓ | Laser vehicle `laser_cuas` ✓ | Jamming vehicle `ew_vehicle` ✓ (jamming field) | Gun-drone interceptor truck `cuas_truck` ✓ |
| Recon drone | Small recon drone `recon_drone` ✓ | Recon drone `recon_drone` ✓ | Recon drone `recon_drone` ✓ | Eurodrone-class MALE drone `recon_drone` ✓ |
| Strike drones | Loitering munition team `loitering_team` | Swarm-drone truck `swarm_launcher` ✓ (Hunter-class) | Loitering munition team `loitering_team` ✓ | Loitering munition team `loitering_team` ✓ |
| Attack helicopter | Apache-class `attack_heli` (launches drones) | Apache-class `attack_heli` | — | Tiger-class `attack_heli` |
| Air transport | MV-75-class tiltrotor `tiltrotor` | Chinook-class `transport_heli` (used by Procurement) | Old transport helicopter `transport_heli` | NH90-class `transport_heli` |
| Fighter / strike | F-35-class `stealth_fighter` + drone wingmen `wingman_drone` | Rafale-class `fighter` | Old strike jet `strike_jet` (cheap, fragile) | Eurofighter-class `fighter` |
| Deception | — | — | Inflatable decoys `decoy_team` | — |

**EU doctrine units** (one per doctrine, chosen at match start): Heavy Armor → breakthrough tank `heavy_mbt`; Air Mobile → air-assault squad `air_assault` (dropped by helicopter); Integrated Air Defense → long-range air-defense vehicle `lr_sam` (SAMP/T-class).

## Buildings

| Role | America | UAE | North Korea | EU |
|---|---|---|---|---|
| HQ | Command HQ `command_hq` ✓ | Command HQ `command_hq` ✓ | Command HQ `command_hq` ✓ | Coalition HQ `command_hq` ✓ |
| Power | Microreactor `microreactor` ✓ | Solar-gas power plant `power_plant` ✓ | Power plant `power_plant` ✓ | Power station `power_station` ✓ |
| Infantry | Barracks `barracks` ✓ | Barracks `barracks` ✓ | Barracks `barracks` ✓ (more barracks, cheaper squads) | Barracks `barracks` ✓ |
| Supply drop-off | Logistics hub `logistics_hub` ✓ | Logistics hub `logistics_hub` ✓ | Logistics hub `logistics_hub` ✓ | Logistics hub `logistics_hub` ✓ |
| Vehicles | Vehicle depot `vehicle_depot` ✓ | Vehicle depot `vehicle_depot` ✓ | Vehicle plant `vehicle_plant` ✓ | Vehicle works `vehicle_works` ✓ |
| Air | Airbase `airbase` (rearm pads) | Airbase `airbase` | Hardened airstrip `airstrip` | Airbase `airbase` |
| Drones | Drone operations center `drone_center` ✓ | Drone industry complex `drone_complex` ✓ | Drone launch site `drone_launch_site` ✓ | Drone center `drone_center` ✓ |
| Tech and upgrades | Battle network center `network_center` | Defense procurement office `procurement_office` (off-map orders) | Artillery command post `artillery_post` (counter-battery radar) | Joint command center `joint_command` |
| Radar and intel | Space operations center `space_ops` | Intelligence center `intel_center` | Jamming station `ew_station` (jamming dome, GPS jamming) | Satellite ground station `sat_station` |
| Special | — | Landing pad `landing_pad` (Procurement deliveries) | Hardened gun position `gun_position` (artillery shelter) | Field hospital `field_hospital` |
| Ground defense | Hardened bunker `bunker` ✓ (can be garrisoned) | Fortified post `fortified_post` ✓ | Trench line `trench_line` ✓, tank obstacles, minefields (engineer-built) | Bunker `bunker` ✓ |
| Air defense | Long-range air-defense site `sam_site` ✓ | THAAD-class site `sam_site` ✓ (best against missiles) | Air-defense site `sam_site` ✓ | SAMP/T-class site `sam_site` ✓ (shares targets) |
| Close-in defense | Gun + laser turret `point_defense` | Laser turret `point_defense` | Anti-aircraft gun nest `aa_guns` | Gun-missile turret `point_defense` |
| Superweapon | Hypersonic battery `hypersonic_battery` ✓ | Strike package airfield `strike_package` ✓ | Heavy missile site `heavy_missile_site` ✓ | Cruise missile battery `cruise_battery` ✓ |

## Superweapons (one per faction, countdown visible to everyone)

All conventional. Each resolves as sim entities that can be intercepted where that makes sense.

In the game (P3-03): each is a building (5,000 credits, commander rank 3, one per player: `limit`, `requires_rank`) with a `superweapon` ability. Its 4-minute charge starts when it is finished and again after each launch; every player sees each superweapon's countdown under the top bar. It fires anywhere on the map, needs no sight, and can't fire while disabled. America: one `hypersonic_missile` (1,600 damage, 400 hp, very fast); UAE: 4 `strike_package_jet` (3 bombs each); North Korea: one `heavy_ballistic_missile` (700 hp, splits into 6 warheads); EU: 12 `cruise_missile`. The AI builds its superweapon after its build order once it reaches rank 3, and fires it at its attack target.

| Faction | Effect | Counterplay |
|---|---|---|
| America | One heavy, precise hit with a short warning | Hard to intercept; destroy the battery, or spread out |
| UAE | Four strike jets fly in from off-map and fire stand-off missiles at a target area | Fighters and air-defense sites can shoot down jets or missiles |
| North Korea | A heavy ballistic missile that splits into several conventional warheads | Intercept the missile before it splits |
| EU | Twelve low-flying cruise missiles, hard to see until close | Short-range air defense near the target |

## Neutral buildings (capturable)

| Building | Effect |
|---|---|
| Oil field | Income |
| Field hospital | Heals nearby infantry |
| Data center | Reveals an area |
| Rail depot | Faster vehicle production |
| Solar farm | Free power |
| Cell tower | Extends the kill-chain spotting range |
