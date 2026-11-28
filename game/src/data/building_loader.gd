class_name BuildingLoader
extends RefCounted
## Loads building JSON into ContentDb (split out of ContentDb on 2026-11-28,
## when superweapons, P3-03, added limits, rank requirements and abilities).


static func load_building(db: ContentDb, path: String) -> void:
	var parsed: Variant = db.read_json(path)
	if not parsed is Dictionary:
		db.errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var b := BuildingDef.new()
	b.id = db.req_string(src, "id", path)
	b.faction = db.req_string(src, "faction", path)
	b.name = db.req_string(src, "name", path)
	b.armor_class = str(src.get("armor_class", "structure"))
	b.max_hp = db.req_int(src, "max_hp", path, 1)
	b.cost = db.req_int(src, "cost", path, 0)
	var fp: Variant = src.get("footprint_cells", [])
	if fp is Array and (fp as Array).size() == 2:
		b.footprint_w = maxi(1, int(fp[0]))
		b.footprint_h = maxi(1, int(fp[1]))
	else:
		db.errors.append("%s: 'footprint_cells' must be [w, h]" % path)
	b.build_ticks = ContentDb.ms_to_ticks(db.req_int(src, "build_time_ms", path, 1))
	b.power = int(src.get("power", 0))
	if src.has("vision_cm"):
		b.vision = Fx.from_ratio(db.req_int(src, "vision_cm", path, 0), 100)
	b.requires = db.string_list(src, "requires", path)
	b.produces = db.string_list(src, "produces", path)
	b.dropoff = bool(src.get("dropoff", false))
	b.free_unit = str(src.get("free_unit", ""))
	b.garrison_capacity = int(src.get("garrison_capacity", 0))
	for weapon_id: Variant in src.get("weapons", []):
		var w: WeaponDef = db.get_weapon(str(weapon_id))
		if w == null:
			db.errors.append("%s: unknown weapon '%s'" % [path, str(weapon_id)])
		else:
			b.weapons.append(w)
	b.capture_ticks = ContentDb.ms_to_ticks(int(src.get("capture_s", 0)) * 1000) if int(src.get("capture_s", 0)) > 0 else 0
	b.income = int(src.get("income_per_10s", 0))
	if src.has("heal_aura") and src["heal_aura"] is Dictionary:
		var ha: Dictionary = src["heal_aura"]
		b.heal_radius = Fx.from_ratio(int(ha.get("radius_cm", 0)), 100)
		b.heal_percent_per_s = int(ha.get("percent_per_s", 0))
		b.heal_classes = db.string_list(ha, "classes", path)
	b.limit = int(src.get("limit", 0))
	b.requires_rank = int(src.get("requires_rank", 1))
	for a: Variant in src.get("abilities", []):
		var ad: AbilityDef = UnitLoader.parse_ability(db, a, path)
		if ad != null:
			b.abilities.append(ad)
	var visual: Variant = src.get("visual", {})
	if visual is Dictionary:
		b.model_path = str((visual as Dictionary).get("model", ""))
		b.icon_path = str((visual as Dictionary).get("icon", ""))
	if path.get_file().get_basename() != b.id:
		db.errors.append("%s: file name must match id '%s'" % [path, b.id])
	if db.buildings.has(b.id) or db.units.has(b.id):
		db.errors.append("%s: duplicate id '%s'" % [path, b.id])
	db.buildings[b.id] = b
