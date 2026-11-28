class_name ModLoader
extends RefCounted
## Finds mods (P3-17, docs/modding.md): every folder in user://mods that has
## an index.json, in name order. ContentDb.load_all loads them on top of the
## game's data. Multiplayer needs the same mods on every machine (the
## content hash differs otherwise, and a LAN game refuses to start).

const ROOT: String = "user://mods"


static func mod_dirs(root: String = ROOT) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(root):
		return out
	var names: PackedStringArray = DirAccess.get_directories_at(root)
	names.sort()
	for n: String in names:
		var dir: String = root.path_join(n)
		if FileAccess.file_exists(dir.path_join("index.json")):
			out.append(dir)
	return out


## The mod's own description (mod.json: name, version, author...), or {}.
static func info(dir: String) -> Dictionary:
	var path: String = dir.path_join("mod.json")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
