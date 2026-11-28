# Modding

Project Zero Hour loads **mods**: folders of JSON data (and, if you like, models and icons) that change or add to the game's content. Mods change numbers, add units, buildings, weapons, powers, maps and AI presets. They don't add code.

## Where mods go

Put each mod in its own folder under the game's user data folder, in `mods/`:

| Platform | Folder |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Project Zero Hour\mods\` |
| Linux | `~/.local/share/godot/app_userdata/Project Zero Hour/mods/` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Project Zero Hour/mods/` |
| Android | the app's internal storage (`user://mods/`); needs a file manager with access to app data |

A folder is a mod when it has an `index.json`. Mods load after the game's own data, in folder-name order. The main menu lists the loaded mods under the title.

## A mod's files

```
mods/heavier_tanks/
  mod.json          name, version, author, description (shown to people; optional)
  index.json        which files to load, in the same format as game/data/index.json
  units/us_mbt.json
  units/scout_team.json
  models/scout_team.glb      optional
  icons/scout_team.png       optional
```

`index.json` lists files by kind, with paths relative to the mod folder:

```json
{
  "units": ["units/us_mbt.json", "units/scout_team.json"],
  "weapons": [],
  "buildings": []
}
```

The kinds are the same as in `game/data/index.json`: `weapons`, `units`, `buildings`, `maps`, `upgrades`, `strikes`, `powers`, `scenarios`, `ai`, plus `rules`, `damage_matrix` and `ai_personalities` for single files.

- **Changing** something: copy the game's file (for example `game/data/units/us_mbt.json`), keep its `id` and file name, and edit the numbers. Your file replaces the game's.
- **Adding** something: give it a new `id`, with a file name that matches it. Remember to make it buildable, for example by replacing a factory's file with your unit added to its `produces` list.
- Every rule the game checks applies to mods too (known weapons, matching file names...). A mistake shows as an error at startup.

## Models and icons

Point `visual.model` and `visual.icon` at files in your mod with full paths, for example `"model": "user://mods/heavier_tanks/models/scout_team.glb"`. The game loads `.glb` models and `.png` icons from there at run time. Name the team-colored material `team_color` (see `docs/04-art-pipeline.md`). Without a model, the game draws a placeholder.

## Multiplayer

Every machine in a LAN game needs the same game version and the same mods. The host's content (game data plus mods) is compared with yours when the match starts; if it differs, the game refuses to start instead of falling out of sync later. Replays record the content they were played with.

## Licenses

Mods are yours. Share only what you have the right to share: no files taken from other games.
