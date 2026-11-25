# Units and buildings

Rosters as **role × faction** tables. Every faction fills the same roles in its own way.

- Names here are working names. "X-class" marks a real-world reference and **never appears in the game**.
- IDs (`us_mbt` and so on) are the data file names in `game/data/units/` and `game/data/buildings/`.
- First-pass numbers for the Phase 2 matchup are in [vertical-slice.md](vertical-slice.md).

## Units

| Role | United States (`us_`) | China (`cn_`) | Russia (`ru_`) | Irregulars (`irr_`) |
|---|---|---|---|---|
| Builder | Armored engineer vehicle `engineer` | Engineering vehicle `engineer` | Combat engineer vehicle `engineer` (also digs trenches) | Field crew `crew` (infantry) |
| Gatherer | Logistics truck `logistics_truck` (self-driving upgrade) | Logistics truck `logistics_truck` | Logistics truck `logistics_truck` | Pickup truck `pickup` |
| Basic infantry | Rifle squad `rifle_squad` | Infantry squad `infantry_squad` (exoskeleton upgrade) | Motorized rifle squad `motor_rifle_squad` (cheap) | Fighters `fighters` (cheapest) |
| Anti-tank infantry | Top-attack missile team `at_team` | Missile team `at_team` | Kornet-class missile team `at_team` | RPG team `rpg_team` |
| Specialist | Sniper team `sniper_team`: spots for the kill chain, detects stealth | Armed robot-dog pack `robot_dogs` | Portable-jammer team `jammer_team` | FPV drone team `fpv_team` |
| Elite (limit 1) | Special recon team `recon_team`: stealthy, marks targets for every long-range weapon | Swarm controller `swarm_controller`: speeds up and extends nearby drones | Electronic-warfare officer `ew_officer`: spoofs enemy drones | Drone ace `drone_ace`: long-range fiber-optic strikes, can't be jammed |
| Light vehicle | JLTV-class `light_vehicle` (carries 4) | Lynx-class ATV `atv` | Tigr-class `light_vehicle` | Technical `technical` (armed pickup) |
| Armored transport | Bradley-class IFV `ifv` | ZBD-04-class IFV `ifv` | BMP-3-class IFV `ifv` | Up-armored truck `armored_truck` |
| Main battle tank | Abrams-class `mbt` + active protection | Type 99A-class `mbt` | T-90M-class `mbt` + cage armor | Refurbished old tank `old_tank` |
| Light tank | — | ZTQ-15-class `light_tank` | — | — |
| Artillery | HIMARS-class `rocket_artillery` (shoot and scoot) | PHL-16-class `rocket_artillery` | Msta-class `howitzer`; TOS-class `thermobaric_launcher` (clears garrisons) | Truck rockets `truck_rockets`, mortar team `mortar_team` |
| Anti-air | M-SHORAD-class `shorad` | HQ-17-class `shorad` | Tor-class `shorad` | Shoulder-fired missile team `manpads_team`, anti-air gun truck `aa_truck` |
| Counter-drone | Laser vehicle `laser_cuas` | Microwave-weapon vehicle `hpm_cuas` | Jamming vehicle `ew_vehicle` (jamming field) | Jammer truck `jammer_truck` |
| Recon drone | Small recon drone `recon_drone` | Recon drone `recon_drone` | Orlan-class `recon_drone` | Commercial quadcopter `quadcopter` |
| Strike drones | Switchblade-class loitering munition team `loitering_team` | Swarm-launcher truck `swarm_launcher` | Lancet-class `loitering_team`; long-range attack drone `strike_drone` (hits buildings) | FPV drones (from `fpv_team`); heavy hexacopter bomber `hexacopter` |
| Attack helicopter | Apache-class `attack_heli` (launches drones) | Z-10-class `attack_heli` | Ka-52-class `attack_heli` | — |
| Air transport | MV-75-class tiltrotor `tiltrotor` | Z-20-class `transport_heli` | Mi-8-class `transport_heli` | — |
| Fighter / strike | F-35-class `stealth_fighter` + drone wingmen `wingman_drone` | J-20-class `stealth_fighter`; GJ-11-class stealth drone `stealth_drone` | Su-57-class `stealth_fighter`; Su-34-class `strike_jet` (glide bombs) | Export strike drone `strike_drone` (TB2-class) |
| Deception | — | — | Inflatable decoys `decoy_team` | Decoy positions (built by `crew`) |

## Buildings

| Role | United States | China | Russia | Irregulars |
|---|---|---|---|---|
| HQ | Command HQ `command_hq` | Command HQ `command_hq` | Command HQ `command_hq` | Mobile command post `command_post` (packs up and moves) |
| Power | Microreactor `microreactor` | Power station `power_station` | Power plant `power_plant` | — (no power) |
| Infantry | Barracks `barracks` | Barracks `barracks` | Barracks `barracks` | Recruitment post `recruitment_post` |
| Supply drop-off | Logistics hub `logistics_hub` | Logistics hub `logistics_hub` | Logistics hub `logistics_hub` | Supply cache `supply_cache` |
| Vehicles | Vehicle depot `vehicle_depot` | Vehicle factory `vehicle_factory` | Vehicle plant `vehicle_plant` | Garage `garage` |
| Air | Airbase `airbase` (rearm pads) | Airbase `airbase` | Airbase `airbase` | — |
| Drones | Drone operations center `drone_center` | Drone works `drone_works` (repeat builds cheaper) | Long-range drone launch site `drone_launch_site` | Drone workshop `drone_workshop` (core building) |
| Tech and upgrades | Battle network center `network_center` | Integrated command center `command_center` | Artillery command post `artillery_post` (counter-battery radar) | Contracts office `contracts_office` |
| Radar and intel | Space operations center `space_ops` | Navigation satellite station `nav_station` (boosts guided weapons) | Jamming station `ew_station` (jamming dome) | Comms relay `comms_relay` |
| Ground defense | Hardened bunker `bunker` (can be garrisoned) | Fortified position `fortified_position` | Trenches, tank obstacles, minefields (engineer-built) | Foxholes, minefields (crew-built) |
| Air defense | Long-range air-defense site `sam_site` (shoots down strikes) | HQ-9-class air-defense site `sam_site` (linked bonus) | S-400-class air-defense site `sam_site` | Anti-air gun emplacement `aa_emplacement` |
| Close-in defense | Gun + laser turret `point_defense` | Gun + microwave emitter `point_defense` | Pantsir-class gun-missile emplacement `point_defense` | Drone net + jammer mast `jammer_mast` |
| Superweapon | Hypersonic battery `hypersonic_battery` | Rocket Force launch site `rocket_force_site` | Strategic missile site `strategic_missile_site` | Drone wave launch site `drone_wave_site` |

## Superweapons (one per faction, countdown visible to everyone)

| Faction | Effect | Counterplay |
|---|---|---|
| United States | One heavy, precise hit with a short warning | Hard to intercept; destroy the battery, or spread out |
| China | Many missiles over a wide area | Air-defense sites can intercept some of them |
| Russia | A missile that splits into several impact points | Intercept the main missile before it splits |
| Irregulars | 40 one-way drones fly across the map | Counter-drone weapons and jamming thin the wave |

## Neutral buildings (capturable)

| Building | Effect |
|---|---|
| Oil field | Income |
| Field hospital | Heals nearby infantry |
| Data center | Reveals an area |
| Rail depot | Faster vehicle production |
| Solar farm | Free power |
| Cell tower | Extends the kill-chain spotting range |
