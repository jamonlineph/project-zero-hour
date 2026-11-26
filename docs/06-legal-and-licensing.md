# Legal and licensing

*This is project policy, not legal advice. Get a lawyer's review of the name and trademarks before the first public release (P0-10, P4-07).*

## Licenses

| What | License | File |
|---|---|---|
| Code (GDScript, Python, shaders, tools) | GPL-3.0-or-later | `LICENSE` |
| Assets (models, textures, icons, sprites, audio, music, maps, data, docs) | CC BY-SA 4.0 | `ASSETS_LICENSE.md` |
| Fonts | SIL OFL 1.1 (each font keeps its license) | listed in the manifest |
| Godot engine | MIT (credit the engine in the game's credits screen) | — |

**Why GPL and CC BY-SA:**
- Anyone may play, study, change and share the game.
- Copies and changes must stay open; closed-source clones aren't allowed.
- CC BY-SA 4.0 assets can legally ship inside a GPL-3.0 game.
- Selling the game is allowed, including on Google Play.

This decision is recorded in [decisions/0006-licensing.md](decisions/0006-licensing.md). It's easy to change now and hard to change after outside contributors join.

## The IP boundary (the most important rule)

- ✅ **Genre mechanics** are free to use: base building, harvesting, power, tech trees, veterancy, garrisons, commander ranks, superweapons, asymmetric factions.
- ❌ **Nothing from any existing game:**
  - names, factions, characters, story or text
  - specific unit, building or power designs, including renamed or "modernized" versions
  - art, models, textures, sounds, voices, music, maps or UI layout
  - logos and trademarks
- ❌ **No files from game installs or mods**, even "just as placeholders". `tools/check_repo.py` blocks the archive and data formats other games use.
- ❌ **No "Command & Conquer", "Generals" or "Zero Hour"** in the game's name, store listing or marketing. Saying "inspired by classic 2000s RTS games" is fine.

## Asset provenance

Every file under `game/assets/` has a row in `ASSET_MANIFEST.csv`:

| Column | Meaning |
|---|---|
| `path` | Repo-relative path |
| `author` | Person, group, or "Project Zero Hour contributors" |
| `source` | Where it came from: script name, URL, `.blend` path |
| `license` | `CC-BY-SA-4.0`, `CC-BY-4.0`, `CC0-1.0` or `OFL-1.1` |
| `generated_by` | `script`, `human`, `ai:<tool name>`, or `third-party` |
| `notes` | Anything else, for example "placeholder" |

CI fails if an asset is missing from the manifest, a row points to a missing file, or a license isn't allowed.

## AI-generated content

**Code:** allowed. The person who commits it is responsible for it.

**Assets (images, models, audio)** are allowed only if all of these hold:
- The tool's terms allow use under CC BY-SA 4.0, including commercial use.
- Prompts never ask for the style or likeness of an existing game, franchise, artist, actor or voice actor.
- No voice cloning of real people. Synthetic voices are fine only from tools that license them for this use.
- A human reviews the result for accidental likeness to existing work.
- The manifest says `generated_by = ai:<tool>`.

Note: purely AI-generated material may not be protected by copyright in some countries. That doesn't block using it here, but contributors can't claim exclusive rights in it.

## Real-world content

**Real nations are fine:** America, the United Arab Emirates, North Korea and the European Union appear as factions. Their flags, emblems and leaders do not; team colors mark the sides.

**Keep these out:**
- real terrorist organizations
- real ongoing wars as scenarios
- real political leaders
- war crimes or attacks on civilians
- weapons of mass destruction

Story and missions are a fictional 2026 crisis, not a real war.

**Weapon names in the game:**
- Use generic names ("Main Battle Tank", "Guided Rocket Artillery") or invented designations.
- Don't use trademarked product names, manufacturer logos or company names.
- Design docs may say "Abrams-class" as a reference only. In-game text never does.

**Regional bans are possible.** Some countries restrict games that depict them at war. Accept this risk and check store rules per region before launch.

## Store compliance

- Google Play:
  - Data safety form ("no data collected" until multiplayer accounts exist)
  - a privacy policy page
  - IARC rating questionnaire (expect a teen rating for stylized military violence)
  - target API requirements (see [05-platforms.md](05-platforms.md))
- No ads, tracking or analytics SDKs. If crash reporting is added later, it must be opt-in, and the Data safety form must be updated.

## Contributor terms

- Contributors keep their copyright and license contributions under the licenses above.
- A DCO sign-off (`git commit -s`) becomes required when the first outside contributor joins (P3-21). It confirms the contributor has the right to submit the work.
- Before accepting assets from other mods or projects, get written permission and record it in the manifest `notes`.
