extends SceneTree
## Recomputes expected_hash in data/determinism_check.json (P1-37). Run by
## tools/regen_golden_replays.sh after an intended change to sim rules or data.

const PATH: String = "res://data/determinism_check.json"


func _initialize() -> void:
	var db := ContentDb.new()
	if not db.load_all():
		printerr("update_determinism_check: content failed to load: ", ", ".join(db.errors))
		quit(1)
		return
	var check := DeterminismCheck.new(db)
	var h: int = check.run()
	var text: String = FileAccess.get_file_as_string(PATH)
	var re := RegEx.create_from_string("\"expected_hash\":\\s*-?[0-9.eE+]+")
	text = re.sub(text, "\"expected_hash\": %d" % h)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("update_determinism_check: expected_hash = %d" % h)
	quit(0)
