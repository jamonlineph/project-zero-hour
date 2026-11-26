# Skirmish AI

The AI is an ordinary player. It sees the world through the same fog-of-war rules as a human (no cheating, except where a difficulty level says so), and it acts only by issuing `SimCommand`s. It runs inside the deterministic simulation, using `SimRng`, so replays and multiplayer with AI players stay in sync.

## Layers

1. **Economy manager:**
   - keeps gatherers busy
   - builds drop-offs near supply sites
   - expands when the current sites run low
   - keeps power positive
2. **Build planner:** follows a data-driven **build order** (`game/data/ai/<faction>_<style>.json`), then switches to reactive building based on what it scouts.
3. **Army manager:**
   - groups units into squads with roles (defense, raid, main army)
   - picks targets
   - retreats damaged units
4. **Tactics:**
   - focus fire on the best target
   - pull back from superweapon countdowns
   - use commander powers
   - counter-build: if it scouts many drones, it builds counter-drone units

## Difficulty

| Level | Behavior |
|---|---|
| Easy | Slow decisions (every 3 s), small army, no harassment, ignores counters |
| Normal | Decisions every 1 s, counter-builds, one harassment group |
| Hard | Decisions every 0.5 s, full build orders, multi-prong attacks, uses all powers |
| Brutal (later) | Hard + 20% income bonus (labeled as cheating in the UI) |

## Personalities (for Gauntlet and variety)

Each personality is a JSON preset: build order, unit preferences, aggression and timings. Examples:
- **Artillery Grinder:** North Korea, turtles and shells.
- **Drone Swarmer:** UAE, swarm drones and raids.
- **Precision Raider:** America, kill-chain strikes on the economy.
- **Shield Wall:** EU, layered air defense and armored pushes.

## Roadmap

| Version | Task | Scope |
|---|---|---|
| v0 ✅ | P1-31 | Build order from `game/data/ai/*.json`, keeps a builder and trucks, fills factories with the unit mix it lacks most, defends buildings, attacks in waves. Shortcut: it knows where enemy buildings are (start positions). Code: `game/src/ai/ai_player.gd` |
| v1 | P2-11 | Easy and normal, counter-building, uses powers |
| v2 | P3-13 | All factions, hard difficulty, personalities |
