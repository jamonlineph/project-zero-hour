# Economy

## Credits

- One resource: **credits**. Each player starts with 10,000 on standard settings (an option in skirmish).
- **Income target:** about 1,500 credits per minute per player after 3 minutes, rising to about 3,000 at full expansion.

## Supply sites (P1-15)

- Supply sites are finite (for example 30,000 credits each) and placed by the map maker: 1 per base plus 2–4 contested.
- A gatherer loads 300 credits in 3 s, drives to a drop-off building, and unloads in 2 s.
- **Rule of thumb:** build the drop-off close to a supply site. The distance is the economy.
- When sites run dry, income comes from contested sites, capturable oil fields and faction mechanics (contracts).

| Faction | Gatherer | Twist |
|---|---|---|
| United States | Logistics truck | Self-driving upgrade: +25% speed, no crew to kill |
| China | Logistics truck | Repeat-build discount applies to trucks |
| Russia | Logistics truck | Armored: survives harassment better, but slower |
| Irregulars | Pickup truck | Cheap and fast, but fragile. **Contracts** add income |

## Power (P1-16)

Buildings have `power` (positive = produces, negative = uses).

| Situation | Effect |
|---|---|
| Consumption above production | Production is 50% slower; radar and powered defenses (lasers, air defense, jammers) switch off |
| Destroying power plants | A valid strategy |

The Irregulars don't use power at all. Their buildings are weaker instead.

## Neutral capturable buildings (P3-08)

Infantry capture them in 5 s if no enemy infantry contests them.

| Building | Effect |
|---|---|
| Oil field | +200 credits every 10 s |
| Field hospital | Heals nearby infantry |
| Data center | Reveals a 60 m radius |
| Rail depot | Vehicles build 15% faster |
| Solar farm | +power |
| Cell tower | Extends the kill-chain spotting range nearby |

## Contracts (Irregulars only, P3-12)

- Three contracts are on offer at any time, and the player picks one to work on.
- Examples:
  - "Hold the bridge for 60 s": 1,500 credits
  - "Destroy an enemy logistics truck": 800 credits
  - "Spot the enemy HQ": 500 credits
- A new contract appears every 90 s. Choices come from `SimRng`, so replays stay deterministic.

## Costs (anchors for balance)

| Item | Cost (credits) |
|---|---|
| Basic infantry squad | 200–300 |
| Gatherer | 600 |
| Main battle tank | 850–1,100 |
| Attack helicopter | 1,500 |
| Air-defense site | 1,000 |
| Superweapon | 5,000 (+ 4 min countdown) |
