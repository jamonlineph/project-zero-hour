# Economy

## Credits

- One resource: **credits**. Each player starts with 10,000 on standard settings (an option in skirmish).
- **Income target:** about 1,500 credits per minute per player after 3 minutes, rising to about 3,000 at full expansion.

## Supply sites (P1-15)

- Supply sites are finite (for example 30,000 credits each) and placed by the map maker: 1 per base plus 2–4 contested.
- A gatherer loads 300 credits in 3 s, drives to a drop-off building, and unloads in 2 s.
- **Rule of thumb:** build the drop-off close to a supply site. The distance is the economy.
- When sites run dry, income comes from contested sites, capturable oil fields and faction mechanics (the UAE's sovereign fund).

| Faction | Gatherer | Twist |
|---|---|---|
| America | Logistics truck | Self-driving upgrade: +25% speed, no crew to kill |
| UAE | Contracted truck | Cheap and fast, but unarmored. **Sovereign fund** pays interest on banked credits |
| North Korea | Logistics truck | Armored: survives harassment better, but slower |
| EU | Logistics truck | Repairs vehicles it drives past |

## Power (P1-16)

Buildings have `power` (positive = produces, negative = uses).

| Situation | Effect |
|---|---|
| Consumption above production | Production is 50% slower; radar and powered defenses (lasers, air defense, jammers) switch off |
| Destroying power plants | A valid strategy |

Every faction uses power. The UAE's solar-gas plants are cheaper but weaker; North Korea's are tougher but use more space.

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

## Sovereign fund (UAE only, P3-12)

- Every minute, unspent credits earn 2% interest, up to 400 credits a minute (a rank-5 unlock doubles the cap).
- It rewards a healthy economy without making turtling strong: the cap is reached at 20,000 banked credits.

## Procurement (UAE only, P3-12)

- The procurement office lists a few top-tier units that can be ordered off-map at +30% cost.
- A transport aircraft delivers them to a landing pad after 30 s. It can be shot down, and the order is lost.
- In the game since P3-02e: the Defense Procurement Office (`ae_procurement_office`, its own landing pad) orders tanks, IFVs, rocket artillery and attack helicopters (`procurement_percent` 30, `delivery_s` 30). Orders queue at the office without using a factory; when one is due, a `ae_cargo_flight` (an aircraft strike with 900 hp) flies in from the UAE's map edge and drops the unit at the office (or where it was headed, if the office is gone). Cancelling refunds the full price. The UAE AI builds one late and buys there with its spare credits.
