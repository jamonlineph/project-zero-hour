class_name SaveGame
extends RefCounted
## Saved games (P3-22). A save is the match's replay (scenario, seed and every
## command so far) plus the state hash at the moment of saving. Loading
## rebuilds the match and fast-forwards to that moment (SaveLoader): the
## sim and the AI players are deterministic, so they end up exactly where they
## were, and the hash proves it. No game state can be forgotten this way; the
## cost is a few seconds of loading for long matches.

## Where saves go; tests point it elsewhere so they never touch a player's saves.
static var dir: String = "user://saves/"
const FORMAT: int = 1


## Writes a save of the runner's match. Returns the file path, or "" on error.
static func save(runner: SimRunner, label: String = "") -> String:
	var r: Replay = runner.make_replay()
	var d: Dictionary = r.to_dict()
	d["save_format"] = FORMAT
	d["state_hash"] = runner.world.state_hash()
	d["local_player"] = runner.local_player_id
	d["ai_players"] = runner.ai_players.keys()
	d["label"] = label
	d["saved_at"] = Time.get_datetime_string_from_system(false, true)
	d["map"] = str(runner.scenario_data.get("map", ""))
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp: int = Time.get_unix_time_from_system()
	var path: String = dir + "save_%d.json" % stamp
	while FileAccess.file_exists(path):   # two saves in the same second
		stamp += 1
		path = dir + "save_%d.json" % stamp
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(d))
	return path


## Saved games, newest first: [{"path", "label", "map", "saved_at", "game_seconds"}].
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var folder := DirAccess.open(dir)
	if folder == null:
		return out
	for file: String in folder.get_files():
		if not file.ends_with(".json"):
			continue
		var d: Dictionary = read(dir + file)
		if d.is_empty():
			continue
		out.append({"path": dir + file, "label": str(d.get("label", "")), "map": str(d.get("map", "")),
			"saved_at": str(d.get("saved_at", "")), "game_seconds": int(d.get("end_tick", 0)) / SimWorld.TICK_RATE})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["path"] > b["path"])
	return out


## A save file's contents, or {} if it isn't a readable save.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not (parsed as Dictionary).has("save_format"):
		return {}
	return parsed
