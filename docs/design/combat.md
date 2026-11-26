# Combat

## Armor classes and damage types

**Armor classes** (the `armor_class` field in unit and building data):
- `infantry`
- `light_vehicle`
- `heavy_armor`
- `aircraft` (helicopters included)
- `drone`
- `structure`

**Damage types:**
- `small_arms`
- `autocannon`
- `anti_tank`
- `high_explosive` (artillery, bombs)
- `anti_air`
- `counter_drone` (lasers, microwave, jamming damage)
- `thermobaric` (clears garrisons)

### Damage multipliers (starting values, tuned in playtests)

These go into `game/data/damage_matrix.json` in P1-09.

| Damage ↓ / Armor → | Infantry | Light vehicle | Heavy armor | Aircraft | Drones | Structures |
|---|---|---|---|---|---|---|
| Small arms | 100% | 30% | 5% | 10% | 60% | 10% |
| Autocannon | 70% | 100% | 20% | 60% | 100% | 30% |
| Anti-tank | 25% | 100% | 100% | 0% | 0% | 60% |
| High explosive | 100% | 70% | 35% | 0% | 20% | 100% |
| Anti-air | 0% | 0% | 0% | 100% | 80% | 0% |
| Counter-drone | 0% | 0% | 0% | 10% | 150% | 0% |
| Thermobaric | 150% | 60% | 20% | 0% | 0% | 80% (+ clears garrisons) |

**Design rule:** every unit has **one clear job** and **at least two counters**. Check every new unit against this table before adding it.

## Weapons (data fields, P1-08)

| Field | Meaning |
|---|---|
| `damage` | Damage per hit |
| `damage_type` | One of the damage types above |
| `range_cm`, `min_range_cm` | Maximum and minimum range |
| `reload_ms` | Time between shots |
| `projectile` | `instant`, `ballistic`, `guided` or `drone` |
| `projectile_speed_cm_per_s` | Projectile speed |
| `splash_radius_cm`, `splash_edge_percent` | Area damage. Splash only hurts what the weapon can `target` (artillery doesn't hit drones overhead) |
| `cone_deg` | Cone weapons (microwave emitters): every valid target inside a cone of this width toward the aimed target is hit. Instant weapons only |
| `targets` | Which armor classes it can target, e.g. `["ground"]`, `["air"]`, `["drone"]` |
| `needs_spotter` | Kill-chain weapons (P2-04) |
| `guided` | Affected by jamming (P2-03) |

## Veterancy (P1-17)

Units earn XP equal to the cost-weighted damage they deal.

| Rank | Bonus |
|---|---|
| 1 | +10% damage |
| 2 | +10% damage, +10% armor |
| 3 | +20% damage, +20% armor, slow self-repair |

Thresholds scale with the unit's cost: 1×, 2× and 4× its cost in XP.

## Targeting (deterministic, P1-08 and P1-10)

- **Auto-target:** the nearest valid enemy in range. Ties are broken by lower entity id.
- **Priority:** units that are attacking us > units > buildings.
- **Attack-move:** move, and engage anything met on the way.
- **Hold position:** never move, only fire.

## 2026 systems (Phase 2)

| System | Rule |
|---|---|
| Kill chain | A weapon with `needs_spotter` may fire beyond its owner's own sight range only at targets that a friendly spotter (recon drone, sniper, recon team, satellite pass, cell tower bonus) currently sees. If the spotter dies or is jammed, guided shots in flight lose accuracy |
| Jamming field | A circle in which enemy `drone` units lose control: they hover, drift and crash when their endurance ends. Enemy `guided` weapons get −50% accuracy. Fiber-optic drones and unguided weapons are immune. Fields don't stack: the strongest wins |
| Spoofing | Ability: enemy drones in a radius pick a new random target (via `SimRng`) for 5 s, which can include their own side |
| Drone endurance | Every drone has `endurance_s`. At 20% it returns to its launcher if one exists; at 0 it crashes |
| Active protection | `aps_charges` intercept incoming `anti_tank` guided missiles and drones with 90% success. One charge reloads every 20 s |
| Interception | Strategic missiles and strike aircraft are entities with hp. Air-defense sites spend interceptors (stock + reload) to shoot them down |
| Decoys | Shown to enemies as the real unit type until an enemy unit comes within 15 m or a recon drone flies over. Decoys die in one hit |
