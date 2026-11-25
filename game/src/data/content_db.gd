class_name ContentDb
extends RefCounted
## Loads game content from res://data/ (JSON) and converts it to sim units.
##
## Every content file must be listed in res://data/index.json, because exported
## games cannot reliably list folders. Godot parses JSON numbers as floats, so
## every numeric field must hold a whole number; it is converted to int here.
## Data units are human-friendly (centimeters, cm per second); the sim gets
## fixed-point meters and meters per tick.

const INDEX_PATH: String = "res://data/index.json"

var units: Dictionary[String, UnitDef] = {}
var maps: Dictionary[String, MapDef] = {}
var errors: PackedStringArray = []


## Loads everything listed in the index. Returns false if any error occurred;
## the messages are in `errors`.
func load_all(index_path: String = INDEX_PATH) -> bool:
	units.clear()
	maps.clear()
	errors.clear()
	var index: Variant = _read_json(index_path)
	if not index is Dictionary:
		errors.append("%s: expected a JSON object" % index_path)
		return false
	for path: Variant in (index as Dictionary).get("units", []):
		_load_unit(str(path))
	for path: Variant in (index as Dictionary).get("maps", []):
		_load_map(str(path))
	return errors.is_empty()


func get_unit(id: String) -> UnitDef:
	return units.get(id, null)


func get_map(id: String) -> MapDef:
	return maps.get(id, null)


func _load_map(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var m := MapDef.new()
	m.id = _req_string(src, "id", path)
	m.name = _req_string(src, "name", path)
	m.width_m = _req_int(src, "width_m", path, 16)
	m.height_m = _req_int(src, "height_m", path, 16)
	var obstacles: Variant = src.get("obstacles_m", [])
	if not obstacles is Array:
		errors.append("%s: 'obstacles_m' must be a list" % path)
		obstacles = []
	for i: int in (obstacles as Array).size():
		var o: Variant = obstacles[i]
		if not o is Array or (o as Array).size() != 4:
			errors.append("%s: obstacle %d must be [x_m, y_m, w_m, h_m]" % [path, i])
			continue
		var rect := PackedInt32Array()
		for v: Variant in o:
			if not (v is float or v is int) or float(v) != floorf(float(v)):
				errors.append("%s: obstacle %d must hold whole numbers" % [path, i])
				break
			rect.append(int(v))
		if rect.size() == 4:
			if rect[2] <= 0 or rect[3] <= 0:
				errors.append("%s: obstacle %d needs a positive size" % [path, i])
			else:
				m.obstacles_m.append(rect)
	if path.get_file().get_basename() != m.id:
		errors.append("%s: file name must match id '%s'" % [path, m.id])
	maps[m.id] = m


func _load_unit(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var u := UnitDef.new()
	u.id = _req_string(src, "id", path)
	u.faction = _req_string(src, "faction", path)
	u.role = _req_string(src, "role", path)
	u.name = _req_string(src, "name", path)
	u.armor_class = _req_string(src, "armor_class", path)
	u.max_hp = _req_int(src, "max_hp", path, 1)
	u.cost = _req_int(src, "cost", path, 0)
	u.speed = Fx.from_ratio(_req_int(src, "speed_cm_per_s", path, 0), 100 * SimWorld.TICK_RATE)
	u.radius = Fx.from_ratio(_req_int(src, "radius_cm", path, 1), 100)
	# Optional. Missing or 0 means the unit turns instantly (infantry, drones).
	if src.has("turn_rate_deg_per_s"):
		var deg_per_s: int = _req_int(src, "turn_rate_deg_per_s", path, 0)
		if deg_per_s > 0:
			# Round up so slow turners never get a turn rate of 0.
			var per_tick: int = (deg_per_s * Fx.ANGLE_FULL + 360 * SimWorld.TICK_RATE - 1) / (360 * SimWorld.TICK_RATE)
			u.turn_rate = mini(per_tick, Fx.ANGLE_FULL)
	var visual: Variant = src.get("visual", {})
	if visual is Dictionary:
		u.model_path = str((visual as Dictionary).get("model", ""))
		u.icon_path = str((visual as Dictionary).get("icon", ""))
	else:
		errors.append("%s: 'visual' must be an object" % path)
	if path.get_file().get_basename() != u.id:
		errors.append("%s: file name must match id '%s'" % [path, u.id])
	if units.has(u.id):
		errors.append("%s: duplicate unit id '%s'" % [path, u.id])
	units[u.id] = u


func _req_string(d: Dictionary, key: String, path: String) -> String:
	var v: Variant = d.get(key)
	if not v is String or (v as String).is_empty():
		errors.append("%s: '%s' must be a non-empty string" % [path, key])
		return ""
	return v


func _req_int(d: Dictionary, key: String, path: String, min_value: int) -> int:
	if not d.has(key):
		errors.append("%s: missing '%s'" % [path, key])
		return min_value
	var v: Variant = d[key]
	if not (v is float or v is int):
		errors.append("%s: '%s' must be a number" % [path, key])
		return min_value
	var f: float = float(v)
	if f != floorf(f):
		errors.append("%s: '%s' must be a whole number (got %s)" % [path, key, str(v)])
		return min_value
	var i: int = int(f)
	if i < min_value:
		errors.append("%s: '%s' must be >= %d (got %d)" % [path, key, min_value, i])
		return min_value
	return i


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return null
	var json := JSON.new()
	var err: Error = json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
