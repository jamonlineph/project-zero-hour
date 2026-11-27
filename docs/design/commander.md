# Commander progression and powers

## Ranks (P1-18, P2-09)

- Players earn **commander XP** from damage dealt (cost-weighted), buildings destroyed and objectives.
- XP raises the commander from **rank 1 to rank 5**. Approximate times in a normal match:

| Rank | Reached at about |
|---|---|
| 2 | 4 minutes |
| 3 | 8 minutes |
| 4 | 13 minutes |
| 5 | 19 minutes |

- Every rank gives **1 point**, and rank 1 starts with 1 point. Points are spent in the faction's **power tree**.
- Tiers: rank-1 options, rank-3 options and rank-5 options. Higher tiers need the commander to have reached that rank.
- **Powers** go on a power bar and have cooldowns (2–6 minutes).
- Some tree entries **unlock units or upgrades** instead of powers. For example, the elite unit unlocks at rank 3.
- Powers that create aircraft or missiles create real sim entities that can be intercepted (P2-07).

In the game (P2-09): powers are data in `game/data/powers/`; the Commander button opens the tree, and chosen powers appear on the power bar. A satellite pass also counts as a kill-chain spotter. Powers that need a target point are used with a click or tap on the map after pressing their button.

## Power trees (first draft, original)

### America

| Tier | Options |
|---|---|
| Rank 1 | Satellite recon pass (reveal an area for 20 s) · Precision rocket strike (3 guided rockets; needs a spotted target) |
| Rank 3 | Drone-wingman patrol (2 unmanned jets guard an area for 60 s) · Cyberattack (enemy minimap and radar off for 30 s) · Unlock: special recon team |
| Rank 5 | Stealth-bomber glide-bomb strike (line of 6 bombs; interceptable) · Unlock: self-driving logistics upgrade |

### North Korea

| Tier | Options |
|---|---|
| Rank 1 | Recon drone sweep (a drone flies a path revealing the ground) · Reserve call-up (3 free infantry squads at the HQ) |
| Rank 3 | Rocket barrage (24 unguided heavy rockets on an area) · GPS jamming (enemy guided weapons scatter in an area for 20 s) · Unlock: artillery spotter officer |
| Rank 5 | Decoy deployment (6 decoy tanks at a point) · Unlock: hardened gun position |

### UAE

| Tier | Options |
|---|---|
| Rank 1 | Satellite recon pass · Emergency procurement (the next off-map order arrives in half the time) |
| Rank 3 | Drone swarm strike (24 small drones attack an area) · Laser shield (air-defense sites in an area also shoot down drones and shells for 30 s) · Unlock: presidential guard detachment |
| Rank 5 | Stand-off missile strike (2 jets fire 4 missiles; interceptable) · Unlock: sovereign fund cap doubled |

In the game (P3-02a): satellite pass (`ae_satellite_pass`), drone swarm strike (`ae_drone_swarm`: 24 `swarm_drone` strikes), the presidential guard unlock (`ae_unlock_guard`) and the stand-off strike (`ae_standoff_strike`: 4 `standoff_missile` strikes from the map edge). Emergency procurement, the laser shield and the sovereign-fund unlock wait for their mechanics (P3-02e, P3-02f, P3-02b).

### EU

| Tier | Options |
|---|---|
| Rank 1 | Air policing patrol (2 fighters guard an area for 45 s) · Field repair (vehicles in an area repair over 15 s) |
| Rank 3 | Coalition artillery strike (an off-map battery fires 12 precision shells) · Cyber defense (your units ignore jamming and spoofing for 30 s) · Unlock: second doctrine unit |
| Rank 5 | Stealth cruise strike (4 low-flying missiles at one target; interceptable) · Unlock: interoperability bonus doubled |

## Superweapons (P3-03)

- Each faction has one superweapon: see [units-and-buildings.md](units-and-buildings.md).
- It needs its building (5,000 credits) and rank 3 or higher.
- Its 4-minute countdown is visible to **all players**.
- The effect resolves as interceptable sim entities where that makes sense.
- Building a second superweapon site is not allowed (limit 1).
