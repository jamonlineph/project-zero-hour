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

var _hasher: SimHash = null

var units: Dictionary[String, UnitDef] = {}
var buildings: Dictionary[String, BuildingDef] = {}
var weapons: Dictionary[String, WeaponDef] = {}
var maps: Dictionary[String, MapDef] = {}
var scenarios: Dictionary[String, Dictionary] = {}   ## raw scenario data, see MatchSetup
var ai_presets: Dictionary[String, Dictionary] = {}  ## raw AI presets, see AiPlayer
## The cross-device determinism check (P1-37); see data/determinism_check.json.
var determinism_check: Dictionary = {}
## Skirmish setup data from rules.json (see MatchConfig).
var start_kit: Array = []
var skirmish_credits: PackedInt32Array = [10000]
var damage_matrix: DamageMatrix = DamageMatrix.new()
var rules: SimRules = SimRules.new()
## Hash of every content file's text, in load order. Replays and multiplayer
## refuse to mix different content (P1-20).
var content_hash: int = 0
var errors: PackedStringArray = []


## Loads everything listed in the index. Returns false if any error occurred;
## the messages are in `errors`.
func load_all(index_path: String = INDEX_PATH) -> bool:
	units.clear()
	buildings.clear()
	weapons.clear()
	maps.clear()
	scenarios.clear()
	ai_presets.clear()
	determinism_check = {}
	damage_matrix = DamageMatrix.new()
	rules = SimRules.new()
	errors.clear()
	_hasher = SimHash.new()
	var index: Variant = _read_json(index_path)
	if not index is Dictionary:
		errors.append("%s: expected a JSON object" % index_path)
		return false
	if (index as Dictionary).has("rules"):
		_load_rules(str(index["rules"]))
	# Order matters: units refer to weapons; weapons refer to damage types.
	if (index as Dictionary).has("damage_matrix"):
		_load_damage_matrix(str(index["damage_matrix"]))
	for path: Variant in (index as Dictionary).get("weapons", []):
		_load_weapon(str(path))
	for path: Variant in (index as Dictionary).get("units", []):
		_load_unit(str(path))
	for path: Variant in (index as Dictionary).get("buildings", []):
		_load_building(str(path))
	for path: Variant in (index as Dictionary).get("maps", []):
		_load_map(str(path))
	var check_path: String = str((index as Dictionary).get("determinism_check", ""))
	if check_path != "":
		var check: Variant = _read_json(check_path)
		if check is Dictionary:
			determinism_check = check
		else:
			errors.append("%s: expected a JSON object" % check_path)
	for path: Variant in (index as Dictionary).get("scenarios", []):
		_load_scenario(str(path))
	for path: Variant in (index as Dictionary).get("ai", []):
		_load_ai_preset(str(path))
	_check_references()
	content_hash = _hasher.value
	return errors.is_empty()


func get_unit(id: String) -> UnitDef:
	return units.get(id, null)


func get_map(id: String) -> MapDef:
	return maps.get(id, null)


func get_weapon(id: String) -> WeaponDef:
	return weapons.get(id, null)


func get_building(id: String) -> BuildingDef:
	return buildings.get(id, null)


## Cost of a unit or building id (0 if unknown).
func cost_of(id: String) -> int:
	if units.has(id):
		return units[id].cost
	if buildings.has(id):
		return buildings[id].cost
	return 0


func _load_building(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var b := BuildingDef.new()
	b.id = _req_string(src, "id", path)
	b.faction = _req_string(src, "faction", path)
	b.name = _req_string(src, "name", path)
	b.armor_class = str(src.get("armor_class", "structure"))
	b.max_hp = _req_int(src, "max_hp", path, 1)
	b.cost = _req_int(src, "cost", path, 0)
	var fp: Variant = src.get("footprint_cells", [])
	if fp is Array and (fp as Array).size() == 2:
		b.footprint_w = maxi(1, int(fp[0]))
		b.footprint_h = maxi(1, int(fp[1]))
	else:
		errors.append("%s: 'footprint_cells' must be [w, h]" % path)
	b.build_ticks = _ms_to_ticks(_req_int(src, "build_time_ms", path, 1))
	b.power = int(src.get("power", 0))
	if src.has("vision_cm"):
		b.vision = Fx.from_ratio(_req_int(src, "vision_cm", path, 0), 100)
	b.requires = _string_list(src, "requires", path)
	b.produces = _string_list(src, "produces", path)
	b.dropoff = bool(src.get("dropoff", false))
	b.free_unit = str(src.get("free_unit", ""))
	for weapon_id: Variant in src.get("weapons", []):
		var w: WeaponDef = get_weapon(str(weapon_id))
		if w == null:
			errors.append("%s: unknown weapon '%s'" % [path, str(weapon_id)])
		else:
			b.weapons.append(w)
	var visual: Variant = src.get("visual", {})
	if visual is Dictionary:
		b.model_path = str((visual as Dictionary).get("model", ""))
		b.icon_path = str((visual as Dictionary).get("icon", ""))
	if path.get_file().get_basename() != b.id:
		errors.append("%s: file name must match id '%s'" % [path, b.id])
	if buildings.has(b.id) or units.has(b.id):
		errors.append("%s: duplicate id '%s'" % [path, b.id])
	buildings[b.id] = b


func _load_scenario(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var id: String = _req_string(src, "id", path)
	if path.get_file().get_basename() != id:
		errors.append("%s: file name must match id '%s'" % [path, id])
	scenarios[id] = src


func _load_ai_preset(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var id: String = _req_string(src, "id", path)
	for b: Variant in src.get("build_order", []):
		if not buildings.has(str(b)):
			errors.append("%s: build_order has unknown building '%s'" % [path, str(b)])
	for u: Variant in (src.get("unit_mix", {}) as Dictionary):
		if not units.has(str(u)):
			errors.append("%s: unit_mix has unknown unit '%s'" % [path, str(u)])
	if path.get_file().get_basename() != id:
		errors.append("%s: file name must match id '%s'" % [path, id])
	ai_presets[id] = src


## Every id one file mentions must exist in another.
func _check_references() -> void:
	for u: UnitDef in units.values():
		for r: String in u.requires:
			if not buildings.has(r):
				errors.append("unit %s requires unknown building '%s'" % [u.id, r])
	for b: BuildingDef in buildings.values():
		for r: String in b.requires:
			if not buildings.has(r):
				errors.append("building %s requires unknown building '%s'" % [b.id, r])
		for p: String in b.produces:
			if not units.has(p):
				errors.append("building %s produces unknown unit '%s'" % [b.id, p])
		if b.free_unit != "" and not units.has(b.free_unit):
			errors.append("building %s gives unknown unit '%s'" % [b.id, b.free_unit])
	for id: String in scenarios:
		var sc: Dictionary = scenarios[id]
		if not maps.has(str(sc.get("map", ""))):
			errors.append("scenario %s uses unknown map '%s'" % [id, str(sc.get("map", ""))])
		for spawn: Variant in sc.get("spawns", []):
			var def_id: String = str((spawn as Dictionary).get("def", ""))
			if not units.has(def_id) and not buildings.has(def_id):
				errors.append("scenario %s spawns unknown '%s'" % [id, def_id])


func _string_list(d: Dictionary, key: String, path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var v: Variant = d.get(key, [])
	if not v is Array:
		errors.append("%s: '%s' must be a list" % [path, key])
		return out
	for item: Variant in v:
		out.append(str(item))
	return out


static func _ms_to_ticks(ms: int) -> int:
	return maxi(1, (ms * SimWorld.TICK_RATE + 999) / 1000)


func _load_rules(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	rules.veterancy_xp_multipliers = _int_list(src, "veterancy_xp_multipliers", path, 3)
	rules.veterancy_damage_bonus = _int_list(src, "veterancy_damage_bonus_percent", path, 4)
	rules.veterancy_armor_bonus = _int_list(src, "veterancy_armor_bonus_percent", path, 4)
	rules.self_repair_rank = _req_int(src, "veterancy_self_repair_rank", path, 0)
	rules.self_repair_percent_per_2s = _req_int(src, "veterancy_self_repair_percent_per_2s", path, 0)
	rules.commander_rank_xp = _int_list(src, "commander_rank_xp", path, 5)
	rules.building_kill_xp_percent = _req_int(src, "building_kill_xp_percent", path, 0)
	start_kit = src.get("start_kit", [])
	if src.has("skirmish_credits"):
		skirmish_credits = _int_list(src, "skirmish_credits", path, (src["skirmish_credits"] as Array).size())


func _int_list(d: Dictionary, key: String, path: String, size: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var v: Variant = d.get(key, [])
	if not v is Array or (v as Array).size() != size:
		errors.append("%s: '%s' must be a list of %d whole numbers" % [path, key, size])
		out.resize(size)
		return out
	for item: Variant in v:
		out.append(int(item))
	return out


func _load_damage_matrix(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var classes: Variant = src.get("armor_classes", [])
	var types: Variant = src.get("damage_types", {})
	if not classes is Array or (classes as Array).is_empty() or not types is Dictionary:
		errors.append("%s: needs 'armor_classes' (list) and 'damage_types' (object)" % path)
		return
	for c: Variant in classes:
		damage_matrix.armor_classes.append(str(c))
	for damage_type: Variant in types:
		var row: Variant = types[damage_type]
		if not row is Array or (row as Array).size() != damage_matrix.armor_classes.size():
			errors.append("%s: '%s' needs one percent per armor class" % [path, damage_type])
			continue
		for i: int in damage_matrix.armor_classes.size():
			var v: Variant = row[i]
			if not (v is float or v is int) or float(v) != floorf(float(v)) or float(v) < 0.0:
				errors.append("%s: '%s' has an invalid percent" % [path, damage_type])
				break
			damage_matrix.set_percent(str(damage_type), damage_matrix.armor_classes[i], int(v))


func _load_weapon(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var w := WeaponDef.new()
	w.id = _req_string(src, "id", path)
	w.damage = _req_int(src, "damage", path, 0)
	w.damage_type = _req_string(src, "damage_type", path)
	if not damage_matrix.has_damage_type(w.damage_type):
		errors.append("%s: damage_type '%s' is not in the damage matrix" % [path, w.damage_type])
	w.max_range = Fx.from_ratio(_req_int(src, "range_cm", path, 1), 100)
	if src.has("min_range_cm"):
		w.min_range = Fx.from_ratio(_req_int(src, "min_range_cm", path, 0), 100)
	var reload_ms: int = _req_int(src, "reload_ms", path, 1)
	w.reload_ticks = maxi(1, (reload_ms * SimWorld.TICK_RATE + 999) / 1000)
	w.projectile = str(src.get("projectile", "instant"))
	if not w.projectile in ["instant", "ballistic", "guided"]:
		errors.append("%s: projectile must be instant, ballistic or guided" % path)
	if w.projectile != "instant":
		w.projectile_speed = maxi(1, Fx.from_ratio(_req_int(src, "projectile_speed_cm_per_s", path, 1), 100 * SimWorld.TICK_RATE))
	if src.has("splash_radius_cm"):
		w.splash_radius = Fx.from_ratio(_req_int(src, "splash_radius_cm", path, 0), 100)
	if src.has("splash_edge_percent"):
		w.splash_edge_percent = _req_int(src, "splash_edge_percent", path, 0)
	if src.has("cone_deg"):
		var cone_deg: int = _req_int(src, "cone_deg", path, 1)
		w.cone_half = (cone_deg * Fx.ANGLE_FULL) / 720
		if w.projectile != "instant":
			errors.append("%s: cone_deg needs an instant weapon" % path)
	var targets: Variant = src.get("targets", ["ground"])
	w.targets = PackedStringArray()
	for t: Variant in targets:
		if not DamageMatrix.TARGET_CATEGORIES.has(str(t)):
			errors.append("%s: unknown target category '%s'" % [path, str(t)])
		w.targets.append(str(t))
	if path.get_file().get_basename() != w.id:
		errors.append("%s: file name must match id '%s'" % [path, w.id])
	weapons[w.id] = w


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
	for start: Variant in src.get("start_positions_m", []):
		if start is Array and (start as Array).size() == 2:
			m.start_positions.append(Vector2i(int(start[0]), int(start[1])))
		else:
			errors.append("%s: start positions must be [x_m, y_m]" % path)
	for site: Variant in src.get("supply_sites_m", []):
		if site is Array and (site as Array).size() == 3:
			m.supply_sites.append(PackedInt32Array([int(site[0]), int(site[1]), int(site[2])]))
		else:
			errors.append("%s: supply sites must be [x_m, y_m, amount]" % path)
	# Map folders: res://data/maps/<id>/map.json (P1-30). The folder name is the id.
	var name_from_path: String = path.get_base_dir().get_file() if path.get_file() == "map.json" \
			else path.get_file().get_basename()
	if name_from_path != m.id:
		errors.append("%s: folder or file name must match id '%s'" % [path, m.id])
	m.max_step_cm = int(src.get("max_step_cm", m.max_step_cm))
	if src.has("water_level_cm"):
		m.water_level_cm = int(src["water_level_cm"])
	if src.has("height"):
		_load_heights(m, path.get_base_dir().path_join(str(src["height"])), int(src.get("height_scale_cm", 0)), path)
	maps[m.id] = m


## Reads a raw 16-bit little-endian heightmap: one sample per 2 m cell, row by
## row from the map's (0, 0) corner. 65535 = height_scale_cm. Raw bytes, not a
## PNG, because Godot re-encodes imported images; raw data is exact everywhere.
func _load_heights(m: MapDef, file: String, scale_cm: int, path: String) -> void:
	if scale_cm <= 0:
		errors.append("%s: 'height_scale_cm' must be positive when 'height' is set" % path)
		return
	if not FileAccess.file_exists(file):
		errors.append("%s: height file %s not found" % [path, file])
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(file)
	var count: int = m.cells_x() * m.cells_y()
	if bytes.size() != count * 2:
		errors.append("%s: %s has %d bytes, expected %d (%d x %d cells, 2 bytes each)" % [
			path, file.get_file(), bytes.size(), count * 2, m.cells_x(), m.cells_y()])
		return
	m.heights_cm.resize(count)
	for i: int in count:
		var v: int = bytes.decode_u16(i * 2)
		m.heights_cm[i] = (v * scale_cm) / 65535
		if _hasher != null:
			_hasher.add_int(v)


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
	if src.has("vision_cm"):
		u.vision = Fx.from_ratio(_req_int(src, "vision_cm", path, 0), 100)
	# Optional. Missing or 0 means the unit turns instantly (infantry, drones).
	if src.has("turn_rate_deg_per_s"):
		var deg_per_s: int = _req_int(src, "turn_rate_deg_per_s", path, 0)
		if deg_per_s > 0:
			# Round up so slow turners never get a turn rate of 0.
			var per_tick: int = (deg_per_s * Fx.ANGLE_FULL + 360 * SimWorld.TICK_RATE - 1) / (360 * SimWorld.TICK_RATE)
			u.turn_rate = mini(per_tick, Fx.ANGLE_FULL)
	if src.has("build_time_ms"):
		u.build_ticks = _ms_to_ticks(_req_int(src, "build_time_ms", path, 1))
	u.requires = _string_list(src, "requires", path)
	u.builder = bool(src.get("builder", false))
	u.flying = bool(src.get("flying", u.armor_class == "drone"))
	if src.has("endurance_s"):
		u.endurance_ticks = _req_int(src, "endurance_s", path, 1) * SimWorld.TICK_RATE
	var g: Variant = src.get("gatherer", null)
	if g is Dictionary:
		u.gatherer = true
		u.gather_capacity = _req_int(g, "capacity", path, 1)
		u.gather_load_ticks = _ms_to_ticks(_req_int(g, "load_ms", path, 1))
		u.gather_unload_ticks = _ms_to_ticks(_req_int(g, "unload_ms", path, 1))
	if damage_matrix.armor_classes.size() > 0 and not damage_matrix.armor_classes.has(u.armor_class):
		errors.append("%s: armor_class '%s' is not in the damage matrix" % [path, u.armor_class])
	for weapon_id: Variant in src.get("weapons", []):
		var w: WeaponDef = get_weapon(str(weapon_id))
		if w == null:
			errors.append("%s: unknown weapon '%s'" % [path, str(weapon_id)])
		else:
			u.weapons.append(w)
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
	var text: String = FileAccess.get_file_as_string(path)
	if _hasher != null:
		_hasher.add_string(path)
		_hasher.add_string(text)
	var err: Error = json.parse(text)
	if err != OK:
		errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
