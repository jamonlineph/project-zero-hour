# ADR 0001: Use Godot 4 as the engine

- **Status:** accepted (2026-11-25)
- **Decided by:** project owner

## Context

The game must run on Android phones and tablets, Googlebook (Android-based laptops) and Chromebooks, and also on PC. The project is open source. Most code will be written by AI coding agents working headless.

An earlier option was to fork the GPL-licensed source code of an existing 2003 RTS engine. That would mean porting a Windows/DirectX 8 codebase to Android, and making all content from scratch in legacy formats.

## Decision

Use **Godot 4** (4.7.x, the standard non-.NET build) with an original codebase.

## Why

- **License:** MIT, compatible with our GPL-3.0 code, with no fees or royalties.
- **Platforms:** first-class Android export (ARM64 and x86_64) and desktop exports. The Android build covers Googlebook and Chromebook.
- **Mobile:** a mobile renderer, touch input, and ASTC/ETC2 texture compression are built in.
- **Headless:** the editor, imports and tests all run headless, which suits CI and AI agents.
- **Agent-friendly:** AI models know Godot and GDScript well. Text scene and resource formats diff cleanly in git.
- **Assets:** Blender → glTF import is excellent.

## Consequences

- We build all RTS systems ourselves: pathfinding, lockstep, fog, AI. The backlog plans for this.
- We don't use Godot's physics or navigation in game logic, because they're not deterministic (see ADR 0003).
- Upgrade within 4.x deliberately: one minor version at a time, tests green, recorded in `tasks/PROGRESS.md`.
