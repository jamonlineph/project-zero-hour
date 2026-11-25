# Mechanics checklist

Every mechanic in the game, its status, and the backlog task that builds it. These are genre mechanics; the content that uses them is original (see [../00-vision.md](../00-vision.md)).

Status: ✅ built · 🔄 in progress · ⬜ planned

## Economy and base building

| Mechanic | Spec | Task | Status |
|---|---|---|---|
| Builder units | Builders construct structures anywhere on valid ground (no build radius), repair buildings, clear mines | P1-12 | ⬜ |
| Construction | Placing a building reserves its footprint. The builder walks there and the building rises over `build_time`. Several builders speed it up with diminishing returns | P1-12 | ⬜ |
| Supply harvesting | Logistics vehicles load from finite supply sites and unload at a drop-off building. Income depends on distance | P1-15 | ⬜ |
| Capturable neutral buildings | Infantry capture neutral structures: oil field (income), field hospital (heals infantry), data center (reveals area), rail depot (faster vehicles), solar farm (power) | P3-08 | ⬜ |
| Power grid | Buildings produce or use power. Low power slows production 50% and shuts off radar and powered defenses (Irregulars don't use power) | P1-16 | ⬜ |
| Production | Per-building queues (up to 9), rally points, cancel with full refund. Several factories of one type each have their own queue | P1-13 | ⬜ |
| Tech tree | Units, buildings and upgrades need prerequisite buildings and, for some, commander rank | P1-14 | ⬜ |
| Sell and repair | Sell for 50% refund; repair with credits over time, or with a builder | P1-12 | ⬜ |
| Upgrades | Global (all units of a type) and per-unit, bought at buildings. Upgrades show on the model | P2-05 | ⬜ |

## Combat

| Mechanic | Spec | Task | Status |
|---|---|---|---|
| Movement | Fixed-point movement toward a target | P0 | ✅ |
| Group movement | Formation offsets for group orders | P0 | ✅ basic |
| Turning | Units turn at `turn_rate` (data: `turn_rate_deg_per_s`, missing = instant); they creep at 25% speed until facing within 22.5° of their heading | P1-02 | ✅ |
| Pathfinding | Grid A* (8 directions, no corner cutting, deterministic tie-breaks, weighted heuristic), line-of-sight smoothing, nearest reachable spot for blocked goals. Flow fields for big groups come in P1-05; speed-up in P1-04b | P1-04 | ✅ (speed: P1-04b) |
| Avoidance | Units don't overlap; they push or wait | P1-06 | ⬜ |
| Health and death | hp, death, removal, wreck props | P1-07 | ⬜ |
| Weapons | Range, reload, projectile or instant, splash, min range, anti-air/ground flags | P1-08 | ⬜ |
| Damage types × armor classes | Damage multiplier table ([combat.md](combat.md)) | P1-09 | ⬜ |
| Attack orders | Attack unit, attack-move, stop, hold position, guard | P1-10 | ⬜ |
| Vision and fog of war | Per-player visibility grid; black shroud never seen; grey fog previously seen | P1-11 | ⬜ |
| Veterancy | Three ranks earned from kills: +damage, +armor, self-repair at the top rank | P1-17 | ⬜ |
| Garrisoning | Infantry enter buildings and fire from them; flame/thermobaric weapons clear them | P3-05 | ⬜ |
| Transports | Vehicles carry infantry; some have firing ports | P3-06 | ⬜ |
| Crushing | Heavy vehicles crush infantry and light obstacles | P3-07 | ⬜ |
| Stealth and detection | Stealthed units are invisible until they fire or a detector is near | P3-09 | ⬜ |
| Mines and obstacles | Engineers lay mines, trenches and tank obstacles | P3-10 | ⬜ |
| Bridges | Destructible; builders repair them | P3-11 | ⬜ |
| Aircraft | Limited ammo, return to the airbase to rearm; helicopters hover | P3-04 | ⬜ |

## 2026 systems (what makes this game different)

| Mechanic | Spec | Task | Status |
|---|---|---|---|
| Drone endurance | Drones fly for `endurance_s`, then return to their launcher or crash | P2-01 | ⬜ |
| Counter-drone | Lasers (single target, unlimited shots), microwave (cone, area), guns, jammers | P2-02 | ⬜ |
| Jamming fields | Areas where enemy drones lose control and guided weapons lose accuracy; fiber-optic drones are immune | P2-03 | ⬜ |
| Spoofing | Ability: enemy drones in an area retarget randomly (deterministic RNG) | P2-03 | ⬜ |
| Kill chain | Long-range weapons can only fire at targets a friendly spotter has marked. Losing the spotter breaks the shot | P2-04 | ⬜ |
| Active protection | Tanks carry N charges that intercept incoming missiles or drones, then reload slowly | P2-06 | ⬜ |
| Interceptable strikes | Strategic missiles and air strikes fly visibly; air-defense sites with interceptor stock can shoot them down | P2-07 | ⬜ |
| Decoys | Inflatable decoys look real to the enemy (shown as real units) until scouted at close range | P2-08 | ⬜ |

## Commander and strategy

| Mechanic | Spec | Task | Status |
|---|---|---|---|
| Commander XP and ranks | XP from damage dealt and objectives; ranks 1–5; each rank gives points | P1-18, P2-09 | ⬜ |
| Power tree | Spend points on powers and unlocks per faction ([commander.md](commander.md)) | P2-09 | ⬜ |
| Superweapon | One per faction; a countdown visible to all players; can be intercepted or destroyed | P3-03 | ⬜ |
| Sub-faction variants | 2–3 per faction, with roster changes and bonuses | P5 | ⬜ |
| Contracts (Irregulars) | Rotating cash bounties for map objectives | P3-12 | ⬜ |

## Modes and meta

| Mechanic | Task | Status |
|---|---|---|
| Skirmish vs AI (difficulties, personalities) | P1-31, P2-11, P3-13 | ⬜ |
| Replays | P1-20 | ⬜ |
| LAN and online multiplayer (lockstep + relay) | P3-14, P3-15 | ⬜ |
| Gauntlet mode (ladder of AI commanders) | P4-03 | ⬜ |
| Operations campaign | P4-04 | ⬜ |
| Map editor and mods | P3-16, P3-17 | ⬜ |
| Victory conditions (destroy all buildings; options) | P1-19 | ⬜ |
