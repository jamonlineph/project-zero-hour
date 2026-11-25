# ADR 0006: GPL-3.0-or-later for code, CC BY-SA 4.0 for assets

- **Status:** accepted (2026-11-25). The owner may still revise this before outside contributors join (see `tasks/QUESTIONS.md`).

## Decision

- Code is licensed **GPL-3.0-or-later**.
- Assets, data and docs are licensed **CC BY-SA 4.0**.
- Every asset's provenance is recorded in `ASSET_MANIFEST.csv` and enforced by CI.

## Why

- Copyleft keeps the game and its forks open; closed-source clones aren't allowed. This is the norm for open-source games.
- CC BY-SA 4.0 is one-way compatible with GPL-3.0, so assets can ship in the game.
- Selling the game (for example a paid Play Store listing) stays possible.

## Alternatives

| Alternative | Trade-off |
|---|---|
| MIT for code | More permissive: allows closed forks and console ports, but gives no protection against closed clones |
| CC BY 4.0 for assets | Allows closed reuse of the art |

Switching is easy now and hard after outside contributions arrive.
