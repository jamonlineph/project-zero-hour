class_name RulesLoader
extends RefCounted
## Loads game/data/rules.json into ContentDb.rules, the skirmish start kit and
## credit choices (split out of ContentDb in P3-13b to keep it small).


static func load_rules(db: ContentDb, path: String) -> void:
	var parsed: Variant = db.read_json(path)
	if not parsed is Dictionary:
		db.errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	db.rules.veterancy_xp_multipliers = int_list(db, src, "veterancy_xp_multipliers", path, 3)
	db.rules.veterancy_damage_bonus = int_list(db, src, "veterancy_damage_bonus_percent", path, 4)
	db.rules.veterancy_armor_bonus = int_list(db, src, "veterancy_armor_bonus_percent", path, 4)
	db.rules.self_repair_rank = db.req_int(src, "veterancy_self_repair_rank", path, 0)
	db.rules.self_repair_percent_per_2s = db.req_int(src, "veterancy_self_repair_percent_per_2s", path, 0)
	db.rules.commander_rank_xp = int_list(db, src, "commander_rank_xp", path, 5)
	db.rules.building_kill_xp_percent = db.req_int(src, "building_kill_xp_percent", path, 0)
	db.rules.crush_percent_per_s = db.req_int(src, "crush_percent_per_s", path, 0)
	var fund: Variant = src.get("sovereign_fund", {})
	if not fund is Dictionary:
		db.errors.append("%s: 'sovereign_fund' must be an object" % path)
		fund = {}
	db.rules.fund_faction = str((fund as Dictionary).get("faction", ""))
	db.rules.fund_interval_ticks = ContentDb.ms_to_ticks(int((fund as Dictionary).get("interval_s", 60)) * 1000)
	db.rules.fund_percent = int((fund as Dictionary).get("percent", 0))
	db.rules.fund_cap = int((fund as Dictionary).get("cap", 0))
	db.rules.fund_cap_doubler = str((fund as Dictionary).get("cap_doubled_by", ""))
	var interop: Dictionary = src.get("interoperability", {}) if src.get("interoperability", {}) is Dictionary else {}
	db.rules.interop_faction = str(interop.get("faction", ""))
	db.rules.interop_radius = Fx.from_ratio(int(interop.get("radius_cm", 2500)), 100)
	db.rules.interop_min_types = int(interop.get("min_types", 3))
	db.rules.interop_reload_percent = clampi(int(interop.get("reload_percent", 0)), 0, 50)
	db.rules.interop_doubler = str(interop.get("doubled_by", ""))
	db.start_kit = src.get("start_kit", [])
	if src.has("skirmish_credits"):
		db.skirmish_credits = int_list(db, src, "skirmish_credits", path, (src["skirmish_credits"] as Array).size())


static func int_list(db: ContentDb, d: Dictionary, key: String, path: String, size: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var v: Variant = d.get(key, [])
	if not v is Array or (v as Array).size() != size:
		db.errors.append("%s: '%s' must be a list of %d whole numbers" % [path, key, size])
		out.resize(size)
		return out
	for item: Variant in v:
		out.append(int(item))
	return out
