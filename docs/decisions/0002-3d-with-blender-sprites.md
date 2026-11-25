# ADR 0002: A 3D game, with Blender for models and rendered sprites

- **Status:** accepted (2026-11-25)

## Context

The owner wants Blender to produce the game's art, including sprites. The genre's reference games of the 2000s moved from 2D sprites to 3D models, and the design needs camera zoom and rotation, terrain height and projectile arcs.

## Decision

- Units and buildings are low-poly **3D models** made in Blender and exported as **glTF binary (.glb)**.
- Blender also renders the **2D sprites** from the same models:
  - build icons
  - 8-direction sprite sheets for the minimap and far-zoom impostors
  - portraits later
- Asset generation is scripted (`blender/`) so it runs headless and agents can use it.

## Alternatives considered

**Pre-rendered 2D isometric sprites for everything.** Rejected:
- no free camera rotation or zoom without pixelation
- huge sprite memory (directions × animations × units)
- harder terrain height

## Consequences

- An art style guide and polygon budgets are needed ([../04-art-pipeline.md](../04-art-pipeline.md)).
- Infantry need a skeleton and an animation set (a Phase 2 task).
- Team colors work through a `team_color` material convention.
