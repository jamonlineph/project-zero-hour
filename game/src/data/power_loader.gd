class_name PowerLoader
extends RefCounted
## Loads commander powers, strikes and upgrades into ContentDb (split out of
## ContentDb in P2-11d).


static func load_power(db: ContentDb, path: String) -> void:
	var parsed: Variant = db.read_json(path)
	if not parsed is Dictionary:
		db.errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var p := PowerDef.new()
	p.id = db.req_string(src, "id", path)
	p.faction = db.req_string(src, "faction", path)
	p.name = db.req_string(src, "name", path)
	p.description = str(src.get("description", ""))
	p.tier = db.req_int(src, "tier", path, 1)
	p.kind = db.req_string(src, "kind", path)
	if not PowerDef.KINDS.has(p.kind):
		db.errors.append("%s: unknown kind '%s'" % [path, p.kind])
	p.targeted = bool(src.get("targeted", not p.kind in ["reinforce", "cyber", "unlock", "cyber_defense", "procurement_rush"]))
	p.cooldown_ticks = int(src.get("cooldown_s", 0)) * SimWorld.TICK_RATE
	p.radius = Fx.from_ratio(int(src.get("radius_cm", 0)), 100)
	p.duration_ticks = int(src.get("duration_s", 0)) * SimWorld.TICK_RATE
	p.count = int(src.get("count", 1))
	p.percent = int(src.get("percent", 0))
	p.strike_id = str(src.get("strike", ""))
	p.unit_id = str(src.get("unit", ""))
	p.needs_spotted = bool(src.get("needs_spotted", false))
	p.group = str(src.get("group", ""))
	p.grants_upgrade = str(src.get("grants_upgrade", ""))
	p.extra_in_group = str(src.get("extra_in_group", ""))
	if path.get_file().get_basename() != p.id:
		db.errors.append("%s: file name must match id '%s'" % [path, p.id])
	db.powers[p.id] = p


static func load_strike(db: ContentDb, path: String) -> void:
	var parsed: Variant = db.read_json(path)
	if not parsed is Dictionary:
		db.errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var s := StrikeDef.new()
	s.id = db.req_string(src, "id", path)
	s.name = db.req_string(src, "name", path)
	s.kind = str(src.get("kind", "missile"))
	if not s.kind in ["missile", "aircraft"]:
		db.errors.append("%s: kind must be missile or aircraft" % path)
	s.max_hp = db.req_int(src, "max_hp", path, 1)
	s.speed = Fx.from_ratio(db.req_int(src, "speed_cm_per_s", path, 1), 100 * SimWorld.TICK_RATE)
	s.radius = Fx.from_ratio(int(src.get("radius_cm", 100)), 100)
	s.vision = Fx.from_ratio(int(src.get("vision_cm", 0)), 100)
	var pl: Variant = src.get("payload", {})
	if pl is Dictionary:
		s.damage = db.req_int(pl, "damage", path, 0)
		s.damage_type = db.req_string(pl, "damage_type", path)
		if not db.damage_matrix.has_damage_type(s.damage_type):
			db.errors.append("%s: damage_type '%s' is not in the damage matrix" % [path, s.damage_type])
		s.splash_radius = Fx.from_ratio(int(pl.get("splash_radius_cm", 0)), 100)
		s.splash_edge_percent = int(pl.get("splash_edge_percent", 50))
		s.count = maxi(1, int(pl.get("count", 1)))
		s.spread = Fx.from_ratio(int(pl.get("spread_cm", 0)), 100)
	else:
		db.errors.append("%s: 'payload' must be an object" % path)
	if path.get_file().get_basename() != s.id:
		db.errors.append("%s: file name must match id '%s'" % [path, s.id])
	db.strikes[s.id] = s


static func load_upgrade(db: ContentDb, path: String) -> void:
	var parsed: Variant = db.read_json(path)
	if not parsed is Dictionary:
		db.errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var u := UpgradeDef.new()
	u.id = db.req_string(src, "id", path)
	u.faction = db.req_string(src, "faction", path)
	u.name = db.req_string(src, "name", path)
	u.scope = str(src.get("scope", "global"))
	if not u.scope in ["global", "unit"]:
		db.errors.append("%s: scope must be global or unit" % path)
	u.cost = db.req_int(src, "cost", path, 0)
	u.granted = bool(src.get("granted", false))
	if u.scope == "global" and not u.granted:
		u.research_ticks = ContentDb.ms_to_ticks(db.req_int(src, "research_time_ms", path, 1))
		u.researched_at = db.req_string(src, "researched_at", path)
	u.requires = db.string_list(src, "requires", path)
	u.requires_rank = int(src.get("requires_rank", 1))
	u.applies_to = db.string_list(src, "applies_to", path)
	var fx: Variant = src.get("effects", {})
	if fx is Dictionary:
		for k: Variant in fx:
			if not UpgradeDef.EFFECT_KEYS.has(str(k)):
				db.errors.append("%s: unknown effect '%s'" % [path, str(k)])
			else:
				u.effects[str(k)] = int(fx[k])
	u.attachment = str(src.get("attachment", ""))
	if u.attachment != "" and not u.attachment.begins_with("upg_"):
		db.errors.append("%s: attachment node names start with upg_" % path)
	if path.get_file().get_basename() != u.id:
		db.errors.append("%s: file name must match id '%s'" % [path, u.id])
	db.upgrades[u.id] = u
