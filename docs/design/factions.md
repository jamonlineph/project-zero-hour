# Factions

Four sides, chosen by the owner on 2026-11-26: **America, the United Arab Emirates, North Korea and the European Union**. Each has a distinct way to win. Rosters are in [units-and-buildings.md](units-and-buildings.md); powers are in [commander.md](commander.md).

"X-class" in these docs names the real-world system a unit is based on, for the designers' reference. **In-game names are always generic or invented** ([../06-legal-and-licensing.md](../06-legal-and-licensing.md)). No real political leaders, no real flags or emblems on units (team colors instead), no nuclear weapons.

| ID | Faction | In one line | Playable |
|---|---|---|---|
| `us` | America | Expensive and precise: see first, strike from far away | Now (vertical slice) |
| `kp` | North Korea | Mass and firepower: artillery, jamming and fortifications | Now (vertical slice) |
| `ae` | United Arab Emirates | Rich and fast: buys the best, strikes with drones and special forces | Playable since P3-02a (base roster); signature mechanics in P3-02b–f |
| `eu` | European Union | A coalition: well-rounded, tough, adapts its doctrine | Playable since P3-12a (base roster); doctrines since P3-12b; interoperability since P3-12c |

## America (`us`): expensive and precise

- **Fantasy:** a small, networked force that sees everything and strikes from far away.
- **Strengths:** sensors, precision long-range fires, stealth aircraft, drone wingmen.
- **Weaknesses:** expensive units, a slow economy early on, and heavy dependence on spotters.
- **Signature mechanics:**
  - **Kill chain:** long-range weapons fire only at targets a spotter has marked (recon drone, sniper team, satellite pass). Kill or jam the spotter and the shot is lost.
  - **Active protection** on tanks: a few charges that shoot down incoming missiles and drones.
  - **Shoot and scoot:** rocket artillery relocates automatically after firing.
  - **Drone wingmen:** unmanned jets that escort each fighter.
- **Economy flavor:** logistics trucks can be upgraded to drive themselves (faster, no crew needed).
- **Look:** angular hulls, sensor domes, sand and olive.

## North Korea (`kp`): mass and firepower

- **Fantasy:** a huge, dug-in army that buries the enemy under artillery and rockets while jamming knocks their drones and guided weapons out of the sky.
- **Strengths:** massed long-range artillery and rocket launchers, cheap infantry, field fortifications, strong jamming, heavy ballistic missiles.
- **Weaknesses:** older, slower vehicles; weak air force; poor at hitting fast, mobile targets; easy to outmaneuver once the guns are found.
- **Signature mechanics:**
  - **Hardened gun positions:** artillery built into hillside shelters. It rolls out, fires a salvo and pulls back under cover, where only heavy weapons can reach it.
  - **Jamming fields:** blind enemy drones and guided weapons. **GPS jamming** makes enemy precision strikes scatter.
  - **Fortifications:** engineers dig trenches, tank obstacles and minefields.
  - **Mass mobilization:** infantry squads cost less the more barracks you own.
  - **Cage armor:** tanks shrug off the first drone hits.
- **Economy flavor:** armored logistics trucks: slower, but they survive raids.
- **Look:** boxy, older hulls with add-on armor and cages; dark olive green.

## United Arab Emirates (`ae`): rich and fast

- **Fantasy:** a small, wealthy military that buys the best equipment in the world and fights fast: drone swarms, special forces and long-range air defense over the desert.
- **Strengths:** the strongest economy, top-tier imported vehicles, drone swarms from its own defense industry, layered air defense, elite special forces.
- **Weaknesses:** few units on the field, expensive losses, needs its economy running to keep up; heavy armor is limited.
- **Signature mechanics:**
  - **Procurement:** units can be ordered off-map for a premium; a transport aircraft delivers them to a landing pad (it can be shot down).
  - **Sovereign fund:** unspent credits earn a small interest every minute, up to a cap. Saving pays off, but so does spending well. In the game (P3-02b): 3% of unspent credits every 60 s, at most 300 per payment, 600 with the rank-5 unlock (`sovereign_fund` in rules.json, `FundSystem`); the top bar shows "(+N fund)" for a few seconds.
  - **Swarm drones:** trucks that launch groups of small drones that hunt together. In the game (P3-02c): the swarm-drone truck (`ae_swarm_launcher`, from the drone industry complex) launches 5 drones at the nearest ground enemy it can see within 90 m, every 40 s. They are real flying units (30 hp, 30 s of flight, small explosive charges), so lasers, jammers and rifles can shoot them down; they crash when their flight time ends.
  - **Desert raiders:** fast wheeled vehicles that move faster off-road.
  - **Special forces:** elite infantry that can call in precision strikes and disable buildings. In the game (P3-02f): the special-forces team has two abilities, "Call Strike" (2 guided rockets on a point it can see within 70 m, every 90 s) and "Disable Building" (an enemy building within 8 m of its walls makes, trains, researches and fires nothing for 25 s; every 60 s). The AI uses both.
- **Economy flavor:** contracted logistics trucks are fast and cheap but unarmored.
- **Look:** clean modern wheeled vehicles, desert sand and pale grey.

## European Union (`eu`): a coalition that adapts

- **Fantasy:** a coalition army of many nations, well equipped and well supplied, that chooses how it fights.
- **Strengths:** tough, well-rounded units, the best repair and medical support, strong air defense, excellent tanks.
- **Weaknesses:** no single overwhelming strength; slow to mass up; units are costly to replace.
- **Signature mechanics:**
  - **Battlegroup doctrine:** at the start of a match, pick one of three doctrines (Heavy Armor, Air Mobile, Integrated Air Defense). Each unlocks one unique unit and a passive bonus. In the game since P3-12b (`docs/design/commander.md`).
  - **Interoperability:** groups that mix three or more unit types fight better together (faster reload). In the game since P3-12c: an armed EU unit with 3+ different armed unit types of its own (itself included) within 25 m reloads 10% faster, 20% with the rank-5 unlock (15% was too strong: the EU then beat America 75% of the time) (`rules.json` `interoperability`, `InteropSystem`; the selection panel says "mixed group: faster reload").
  - **Field repair and medics:** damaged units heal near repair vehicles and field hospitals.
  - **Sovereign airspace:** air-defense sites share targets with each other and with fighters.
- **Economy flavor:** logistics trucks repair nearby vehicles while they drive.
- **Look:** clean, modern tracked vehicles, grey-green with crisp edges.

## Hard rules for all factions

- Real nations are fine. Their leaders, flags and emblems don't appear; team colors mark sides.
- No nuclear, chemical or biological weapons.
- No attacks on civilians, no terror tactics, no suicide infantry.
- Story and mission text (Phase 4) is a fictional 2026 crisis, not a real war.

## Sub-faction variants (after 1.0)

Each faction gets 2–3 variants with roster changes and bonuses, chosen before a match. Examples:

| Faction | Variants |
|---|---|
| America | Armored, Expeditionary (air-mobile), Unmanned (drone-heavy) |
| North Korea | Artillery Corps, Electronic Warfare, Light Infantry |
| UAE | Drone Industry, Special Operations, Air Defense |
| EU | (the battlegroup doctrines above already play this role) |
