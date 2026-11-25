# ADR 0005: Game content as JSON data files

- **Status:** accepted (2026-11-25)

## Decision

Units, weapons, buildings, factions, AI build orders and maps are **JSON files** under `game/data/`.
- Every file is listed in `game/data/index.json`.
- Values use human-friendly integer units (cm, cm/s, ms). `ContentDb` validates them and converts them to sim units.

## Why

- Easy for humans, AI agents and modders to read and edit. Clean git diffs.
- Godot parses JSON natively. Exports pack the files through the `data/*` include filter.
- Balance changes are data edits, not code changes.

## Notes

- Godot parses every JSON number as a float. Fields must hold whole numbers, and the loader rejects fractions. This keeps the sim integer-only.
- A spreadsheet → JSON import tool may come later (P3-19) for balancing. JSON stays the source of truth.
