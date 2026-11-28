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
var upgrades: Dictionary[String, UpgradeDef] = {}
var strikes: Dictionary[String, StrikeDef] = {}
var powers: Dictionary[String, PowerDef] = {}
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
	upgrades.clear()
	strikes.clear()
	powers.clear()
	damage_matrix = DamageMatrix.new()
	rules = SimRules.new()
	errors.clear()
	_hasher = SimHash.new()
	var index: Variant = read_json(index_path)
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
		BuildingLoader.load_building(self, str(path))
	for path: Variant in (index as Dictionary).get("maps", []):
		_load_map(str(path))
	for path: Variant in (index as Dictionary).get("upgrades", []):
		_load_upgrade(str(path))
	for path: Variant in (index as Dictionary).get("strikes", []):
		_load_strike(str(path))
	for path: Variant in (index as Dictionary).get("powers", []):
		_load_power(str(path))
	var check_path: String = str((index as Dictionary).get("determinism_check", ""))
	if check_path != "":
		var check: Variant = read_json(check_path)
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


func _load_scenario(path: String) -> void:
	var parsed: Variant = read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var id: String = req_string(src, "id", path)
	if path.get_file().get_basename() != id:
		errors.append("%s: file name must match id '%s'" % [path, id])
	scenarios[id] = src


func _load_ai_preset(path: String) -> void:
	var parsed: Variant = read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var id: String = req_string(src, "id", path)
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
	for u: UnitDef in units.values():
		if u.decoy_of != "" and not units.has(u.decoy_of):
			errors.append("unit %s imitates unknown unit '%s'" % [u.id, u.decoy_of])
	for p: PowerDef in powers.values():
		if p.strike_id != "" and not strikes.has(p.strike_id):
			errors.append("power %s launches unknown strike '%s'" % [p.id, p.strike_id])
		if p.unit_id != "" and not units.has(p.unit_id):
			errors.append("power %s uses unknown unit '%s'" % [p.id, p.unit_id])
	for p: PowerDef in powers.values():
		if p.grants_upgrade != "" and not upgrades.has(p.grants_upgrade):
			errors.append("power %s grants unknown upgrade '%s'" % [p.id, p.grants_upgrade])
	for u: UnitDef in units.values():
		if u.requires_unlock != "" and not powers.has(u.requires_unlock):
			errors.append("unit %s requires unknown power '%s'" % [u.id, u.requires_unlock])
	for up: UpgradeDef in upgrades.values():
		if up.scope == "global" and not up.granted and not buildings.has(up.researched_at):
			errors.append("upgrade %s is researched at unknown building '%s'" % [up.id, up.researched_at])
		for r: String in up.requires:
			if not buildings.has(r):
				errors.append("upgrade %s requires unknown building '%s'" % [up.id, r])
		for a: String in up.applies_to:
			if not units.has(a):
				errors.append("upgrade %s applies to unknown unit '%s'" % [up.id, a])
	for id: String in scenarios:
		var sc: Dictionary = scenarios[id]
		if not maps.has(str(sc.get("map", ""))):
			errors.append("scenario %s uses unknown map '%s'" % [id, str(sc.get("map", ""))])
		for spawn: Variant in sc.get("spawns", []):
			var def_id: String = str((spawn as Dictionary).get("def", ""))
			if not units.has(def_id) and not buildings.has(def_id):
				errors.append("scenario %s spawns unknown '%s'" % [id, def_id])


func string_list(d: Dictionary, key: String, path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var v: Variant = d.get(key, [])
	if not v is Array:
		errors.append("%s: '%s' must be a list" % [path, key])
		return out
	for item: Variant in v:
		out.append(str(item))
	return out


static func ms_to_ticks(ms: int) -> int:
	return maxi(1, (ms * SimWorld.TICK_RATE + 999) / 1000)


func _load_rules(path: String) -> void:
	var parsed: Variant = read_json(path)
	if not parsed is Dictionary:
		errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	rules.veterancy_xp_multipliers = _int_list(src, "veterancy_xp_multipliers", path, 3)
	rules.veterancy_damage_bonus = _int_list(src, "veterancy_damage_bonus_percent", path, 4)
	rules.veterancy_armor_bonus = _int_list(src, "veterancy_armor_bonus_percent", path, 4)
	rules.self_repair_rank = req_int(src, "veterancy_self_repair_rank", path, 0)
	rules.self_repair_percent_per_2s = req_int(src, "veterancy_self_repair_percent_per_2s", path, 0)
	rules.commander_rank_xp = _int_list(src, "commander_rank_xp", path, 5)
	rules.building_kill_xp_percent = req_int(src, "building_kill_xp_percent", path, 0)
	rules.crush_percent_per_s = req_int(src, "crush_percent_per_s", path, 0)
	var fund: Variant = src.get("sovereign_fund", {})
	if not fund is Dictionary:
		errors.append("%s: 'sovereign_fund' must be an object" % path)
		fund = {}
	rules.fund_faction = str((fund as Dictionary).get("faction", ""))
	rules.fund_interval_ticks = ms_to_ticks(int((fund as Dictionary).get("interval_s", 60)) * 1000)
	rules.fund_percent = int((fund as Dictionary).get("percent", 0))
	rules.fund_cap = int((fund as Dictionary).get("cap", 0))
	rules.fund_cap_doubler = str((fund as Dictionary).get("cap_doubled_by", ""))
	var interop: Dictionary = src.get("interoperability", {}) if src.get("interoperability", {}) is Dictionary else {}
	rules.interop_faction = str(interop.get("faction", ""))
	rules.interop_radius = Fx.from_ratio(int(interop.get("radius_cm", 2500)), 100)
	rules.interop_min_types = int(interop.get("min_types", 3))
	rules.interop_reload_percent = clampi(int(interop.get("reload_percent", 0)), 0, 50)
	rules.interop_doubler = str(interop.get("doubled_by", ""))
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
	var parsed: Variant = read_json(path)
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


func get_power(id: String) -> PowerDef:
	return powers.get(id, null)


## A faction's power tree, by tier then id.
func powers_for(faction: String) -> Array[PowerDef]:
	var out: Array[PowerDef] = []
	for p: PowerDef in powers.values():
		if p.faction == faction:
			out.append(p)
	out.sort_custom(func(a: PowerDef, b: PowerDef) -> bool:
		return a.tier < b.tier or (a.tier == b.tier and a.id < b.id))
	return out


func get_strike(id: String) -> StrikeDef:
	return strikes.get(id, null)


func get_upgrade(id: String) -> UpgradeDef:
	return upgrades.get(id, null)


## Upgrades researched at `building_id`, in id order.
func upgrades_at(building_id: String) -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	var ids: Array = upgrades.keys()
	ids.sort()
	for id: String in ids:
		if upgrades[id].researched_at == building_id:
			out.append(upgrades[id])
	return out


func _load_weapon(path: String) -> void:
	UnitLoader.load_weapon(self, path)


func _load_unit(path: String) -> void:
	UnitLoader.load_unit(self, path)


func _load_map(path: String) -> void:
	MapLoader.load_map(self, path)


func _load_power(path: String) -> void:
	PowerLoader.load_power(self, path)


func _load_strike(path: String) -> void:
	PowerLoader.load_strike(self, path)


func _load_upgrade(path: String) -> void:
	PowerLoader.load_upgrade(self, path)


## Adds raw data to the content hash (height files).
func hash_int(v: int) -> void:
	if _hasher != null:
		_hasher.add_int(v)


func req_string(d: Dictionary, key: String, path: String) -> String:
	var v: Variant = d.get(key)
	if not v is String or (v as String).is_empty():
		errors.append("%s: '%s' must be a non-empty string" % [path, key])
		return ""
	return v


func req_int(d: Dictionary, key: String, path: String, min_value: int) -> int:
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


func read_json(path: String) -> Variant:
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
