class_name UnitLoader
extends RefCounted
## Loads weapon and unit JSON into ContentDb (split out of ContentDb in P2-11d).
## Weapons first: units refer to them.


static func load_weapon(db: ContentDb, path: String) -> void:
	var parsed: Variant = db.read_json(path)
	if not parsed is Dictionary:
		db.errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var w := WeaponDef.new()
	w.id = db.req_string(src, "id", path)
	w.damage = db.req_int(src, "damage", path, 0)
	w.damage_type = db.req_string(src, "damage_type", path)
	if not db.damage_matrix.has_damage_type(w.damage_type):
		db.errors.append("%s: damage_type '%s' is not in the damage matrix" % [path, w.damage_type])
	w.max_range = Fx.from_ratio(db.req_int(src, "range_cm", path, 1), 100)
	if src.has("min_range_cm"):
		w.min_range = Fx.from_ratio(db.req_int(src, "min_range_cm", path, 0), 100)
	var reload_ms: int = db.req_int(src, "reload_ms", path, 1)
	w.reload_ticks = maxi(1, (reload_ms * SimWorld.TICK_RATE + 999) / 1000)
	w.projectile = str(src.get("projectile", "instant"))
	if not w.projectile in ["instant", "ballistic", "guided"]:
		db.errors.append("%s: projectile must be instant, ballistic or guided" % path)
	if w.projectile != "instant":
		w.projectile_speed = maxi(1, Fx.from_ratio(db.req_int(src, "projectile_speed_cm_per_s", path, 1), 100 * SimWorld.TICK_RATE))
	if src.has("splash_radius_cm"):
		w.splash_radius = Fx.from_ratio(db.req_int(src, "splash_radius_cm", path, 0), 100)
	if src.has("splash_edge_percent"):
		w.splash_edge_percent = db.req_int(src, "splash_edge_percent", path, 0)
	w.needs_spotter = bool(src.get("needs_spotter", false))
	w.drone_attack = bool(src.get("drone_attack", false))
	if src.has("stock"):
		w.stock = db.req_int(src, "stock", path, 1)
		w.restock_ticks = db.req_int(src, "restock_s", path, 1) * SimWorld.TICK_RATE
	if src.has("cone_deg"):
		var cone_deg: int = db.req_int(src, "cone_deg", path, 1)
		w.cone_half = (cone_deg * Fx.ANGLE_FULL) / 720
		if w.projectile != "instant":
			db.errors.append("%s: cone_deg needs an instant weapon" % path)
	if w.min_range >= w.max_range:
		db.errors.append("%s: min_range_cm must be below range_cm" % path)
	if w.splash_edge_percent < 0 or w.splash_edge_percent > 100:
		db.errors.append("%s: splash_edge_percent must be 0-100" % path)
	var targets: Variant = src.get("targets", ["ground"])
	w.targets = PackedStringArray()
	for t: Variant in targets:
		if not DamageMatrix.TARGET_CATEGORIES.has(str(t)):
			db.errors.append("%s: unknown target category '%s'" % [path, str(t)])
		w.targets.append(str(t))
	if path.get_file().get_basename() != w.id:
		db.errors.append("%s: file name must match id '%s'" % [path, w.id])
	db.weapons[w.id] = w


static func load_unit(db: ContentDb, path: String) -> void:
	var parsed: Variant = db.read_json(path)
	if not parsed is Dictionary:
		db.errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var u := UnitDef.new()
	u.id = db.req_string(src, "id", path)
	u.faction = db.req_string(src, "faction", path)
	u.role = db.req_string(src, "role", path)
	u.name = db.req_string(src, "name", path)
	u.armor_class = db.req_string(src, "armor_class", path)
	u.max_hp = db.req_int(src, "max_hp", path, 1)
	u.cost = db.req_int(src, "cost", path, 0)
	u.speed = Fx.from_ratio(db.req_int(src, "speed_cm_per_s", path, 0), 100 * SimWorld.TICK_RATE)
	u.radius = Fx.from_ratio(db.req_int(src, "radius_cm", path, 1), 100)
	if src.has("vision_cm"):
		u.vision = Fx.from_ratio(db.req_int(src, "vision_cm", path, 0), 100)
	# Optional. Missing or 0 means the unit turns instantly (infantry, drones).
	if src.has("turn_rate_deg_per_s"):
		var deg_per_s: int = db.req_int(src, "turn_rate_deg_per_s", path, 0)
		if deg_per_s > 0:
			# Round up so slow turners never get a turn rate of 0.
			var per_tick: int = (deg_per_s * Fx.ANGLE_FULL + 360 * SimWorld.TICK_RATE - 1) / (360 * SimWorld.TICK_RATE)
			u.turn_rate = mini(per_tick, Fx.ANGLE_FULL)
	if src.has("build_time_ms"):
		u.build_ticks = ContentDb.ms_to_ticks(db.req_int(src, "build_time_ms", path, 1))
	u.requires = db.string_list(src, "requires", path)
	u.builder = bool(src.get("builder", false))
	u.flying = bool(src.get("flying", u.armor_class == "drone"))
	u.fiber_optic = bool(src.get("fiber_optic", false))
	u.spotter = bool(src.get("spotter", false))
	u.crusher = bool(src.get("crusher", false))
	for a: Variant in src.get("abilities", []):
		var ad: AbilityDef = _ability(db, a, path)
		if ad != null:
			u.abilities.append(ad)
	if src.has("launcher"):
		var l: Variant = src["launcher"]
		if not l is Dictionary or not (l as Dictionary).has("unit"):
			db.errors.append("%s: 'launcher' must be an object with a unit" % path)
		else:
			u.launch_unit = str(l["unit"])
			u.launch_count = maxi(1, int(l.get("count", 1)))
			u.launch_range = Fx.from_ratio(int(l.get("range_cm", 0)), 100)
			u.launch_cooldown_ticks = ContentDb.ms_to_ticks(int(l.get("cooldown_s", 30)) * 1000)
	u.aps_charges = int(src.get("aps_charges", 0))
	u.cage_hits = int(src.get("cage_hits", 0))
	u.decoy_of = str(src.get("decoy_of", ""))
	u.requires_unlock = str(src.get("requires_unlock", ""))
	var jam: Variant = src.get("jammer", null)
	if jam is Dictionary:
		u.jam_radius = Fx.from_ratio(db.req_int(jam, "radius_cm", path, 1), 100)
		u.jam_strength = int((jam as Dictionary).get("strength", 1))
		if (jam as Dictionary).has("spoof_radius_cm"):
			u.spoof_radius = Fx.from_ratio(db.req_int(jam, "spoof_radius_cm", path, 1), 100)
			u.spoof_range = Fx.from_ratio(db.req_int(jam, "spoof_range_cm", path, 1), 100)
			u.spoof_cooldown_ticks = db.req_int(jam, "spoof_cooldown_s", path, 1) * SimWorld.TICK_RATE
	if src.has("endurance_s"):
		u.endurance_ticks = db.req_int(src, "endurance_s", path, 1) * SimWorld.TICK_RATE
	var g: Variant = src.get("gatherer", null)
	if g is Dictionary:
		u.gatherer = true
		u.gather_capacity = db.req_int(g, "capacity", path, 1)
		u.gather_load_ticks = ContentDb.ms_to_ticks(db.req_int(g, "load_ms", path, 1))
		u.gather_unload_ticks = ContentDb.ms_to_ticks(db.req_int(g, "unload_ms", path, 1))
	if db.damage_matrix.armor_classes.size() > 0 and not db.damage_matrix.armor_classes.has(u.armor_class):
		db.errors.append("%s: armor_class '%s' is not in the damage matrix" % [path, u.armor_class])
	for weapon_id: Variant in src.get("weapons", []):
		var w: WeaponDef = db.get_weapon(str(weapon_id))
		if w == null:
			db.errors.append("%s: unknown weapon '%s'" % [path, str(weapon_id)])
		else:
			u.weapons.append(w)
	var visual: Variant = src.get("visual", {})
	if visual is Dictionary:
		u.model_path = str((visual as Dictionary).get("model", ""))
		u.icon_path = str((visual as Dictionary).get("icon", ""))
	else:
		db.errors.append("%s: 'visual' must be an object" % path)
	if u.endurance_ticks > 0 and not u.flying:
		db.errors.append("%s: endurance_s only makes sense for flying units" % path)
	if u.vision <= 0 and u.decoy_of == "":
		db.errors.append("%s: vision_cm must be positive" % path)
	if path.get_file().get_basename() != u.id:
		db.errors.append("%s: file name must match id '%s'" % [path, u.id])
	if db.units.has(u.id):
		db.errors.append("%s: duplicate unit id '%s'" % [path, u.id])
	db.units[u.id] = u


## One entry of a unit's "abilities" list (P3-02f), or null if it's broken.
static func _ability(db: ContentDb, src: Variant, path: String) -> AbilityDef:
	if not src is Dictionary:
		db.errors.append("%s: each ability must be an object" % path)
		return null
	var d: Dictionary = src
	var a := AbilityDef.new()
	a.id = str(d.get("id", ""))
	a.kind = str(d.get("kind", ""))
	if a.id == "" or not AbilityDef.KINDS.has(a.kind):
		db.errors.append("%s: ability '%s' needs an id and a kind (%s)" % [path, a.id, ", ".join(AbilityDef.KINDS)])
		return null
	a.name = str(d.get("name", a.id))
	a.description = str(d.get("description", ""))
	a.range = Fx.from_ratio(int(d.get("range_cm", 0)), 100)
	a.cooldown_ticks = ContentDb.ms_to_ticks(int(d.get("cooldown_s", 60)) * 1000)
	a.strike_id = str(d.get("strike", ""))
	a.count = maxi(1, int(d.get("count", 1)))
	a.duration_ticks = ContentDb.ms_to_ticks(int(d.get("duration_s", 0)) * 1000)
	if a.kind == "strike" and a.strike_id == "":
		db.errors.append("%s: strike ability '%s' needs a strike" % [path, a.id])
	return a
