# ADR 0004: GDScript first; native code only when measured

- **Status:** accepted (2026-11-25)

## Decision

All code is **statically typed GDScript**. Hot spots (pathfinding, large-scale targeting) may later move to a C++ GDExtension, but only:
- after the performance harness (P1-33) shows they exceed the budgets,
- through a new ADR,
- keeping the same deterministic rules and tests.

## Why

- One language; no native toolchains for Android or desktop.
- Exports to every platform work out of the box.
- AI agents produce correct GDScript reliably when they're told "Godot 4.7" and shown the pitfall table.
- GDScript ints are 64-bit, which is enough for 16.16 fixed point.

## Why not C#

- Godot's C# needs the .NET build, and the Android and web exports are more fragile.
- It would also add a second toolchain for agents and CI.
