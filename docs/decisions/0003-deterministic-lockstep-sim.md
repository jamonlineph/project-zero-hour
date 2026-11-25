# ADR 0003: Deterministic fixed-point simulation, ready for lockstep

- **Status:** accepted (2026-11-25)

## Context

RTS multiplayer with hundreds of units uses **lockstep**: players exchange only commands, and every machine simulates the same game. That needs bit-identical results on x86 PCs and ARM phones. Floats can differ between CPUs and compilers. Retrofitting determinism later is extremely painful.

## Decision

- The simulation (`game/src/sim/`) runs at a fixed **15 ticks per second**.
- It uses only **integers**:
  - 16.16 fixed point (`Fx`)
  - its own **xorshift32 RNG** (`SimRng`)
  - its own **FNV-style state hash** (`SimHash`)
  - canonical iteration order
- Input enters only as `SimCommand`s, applied in `(player_id, seq)` order.
- The view interpolates between ticks.

## Consequences

- **Gained:**
  - Replays are just the seed plus commands.
  - Desyncs are detectable with state hashes.
  - Tests and AI-vs-AI simulations run headless.
- **Costs:**
  - No Godot physics or navigation in gameplay.
  - Fixed-point math has to be written for angles, trig and pathfinding (P1-01, P1-04).
  - Agents must follow the determinism rules (AGENTS.md rule 2).
- 15 Hz keeps GDScript sim costs low on phones. Movement looks smooth through interpolation.
