class_name Gauntlet
extends RefCounted
## Gauntlet mode (P4-03): seven computer commanders in order
## (game/data/gauntlet.json). Progress is how many are beaten, saved in
## user://gauntlet.json; beating the next one moves it on. UI side only: a
## gauntlet match is an ordinary skirmish tagged with its step.

const DATA_PATH: String = "res://data/gauntlet.json"
const SAVE_PATH: String = "user://gauntlet.json"

## Where progress is kept (tests point it elsewhere).
static var save_path: String = SAVE_PATH


static func commanders() -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	return (d as Dictionary).get("commanders", []) if d is Dictionary else []


## How many commanders are beaten (0..7).
static func beaten() -> int:
	if not FileAccess.file_exists(save_path):
		return 0
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return clampi(int((d as Dictionary).get("beaten", 0)), 0, commanders().size()) if d is Dictionary else 0


## Called when the player wins gauntlet step `step` (0-based): it counts only
## if it was the next one.
static func record_win(step: int) -> void:
	if step == beaten():
		_save(step + 1)


static func reset() -> void:
	_save(0)


static func _save(n: int) -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"beaten": n}))


## The skirmish for step `step` against the player's faction, tagged with the
## step so the end of the match can record a win.
static func scenario(content: ContentDb, step: int, faction: String, credits: int) -> Dictionary:
	var c: Dictionary = commanders()[step]
	var sc: Dictionary = MatchConfig.skirmish(content, str(c["map"]), faction, credits, false,
		str(c["difficulty"]), str(c["faction"]), str(c["personality"]))
	sc["name"] = "Gauntlet %d: %s" % [step + 1, c["call_sign"]]
	sc["gauntlet_step"] = step
	return sc
