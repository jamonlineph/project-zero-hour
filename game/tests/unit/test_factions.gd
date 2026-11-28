extends TestCase
# Every faction offered in skirmish (MatchConfig.FACTIONS) is complete and
# playable: start kit, AI preset, production paths, powers (P3-02a adds the
# UAE).

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func test_the_uae_is_playable() -> void:
	assert_true(MatchConfig.FACTIONS.has("ae"))
	assert_eq(MatchConfig.default_enemy("us"), "kp")
	assert_eq(MatchConfig.default_enemy("kp"), "us")
	var sc: Dictionary = MatchConfig.skirmish(_content(), "twin_ridge", "ae", 10000, false, "normal", "us")
	assert_eq((sc["players"] as Array)[0]["faction"], "ae")
	assert_eq((sc["players"] as Array)[1]["faction"], "us")
	assert_eq((sc["players"] as Array)[1]["ai"], "us_default")


func test_every_faction_has_a_start_kit_and_ai_preset() -> void:
	for f: String in MatchConfig.FACTIONS:
		for item: Variant in _content().start_kit:
			var id: String = str((item as Array)[0]).replace("{f}", f)
			assert_true(_content().units.has(id) or _content().buildings.has(id), "%s: start kit item %s is missing" % [f, id])
		assert_true(_content().ai_presets.has(f + "_default"), "%s has no AI preset" % f)


func test_ai_presets_only_use_their_own_factions_content() -> void:
	for f: String in MatchConfig.FACTIONS:
		var ai: AiPlayer = AiPlayer.from_preset(_content(), f + "_default", 1)
		for b: String in ai.build_order:
			var def: BuildingDef = _content().get_building(b)
			assert_true(def != null and def.faction == f, "%s: build order has %s" % [f, b])
		for u: String in ai.unit_mix:
			assert_true(_produced_by(f, u), "%s: no %s building produces %s" % [f, f, u])
		assert_true(_produced_by(f, ai.gatherer_unit), "%s: gatherer %s can't be built" % [f, ai.gatherer_unit])
		for p: String in ai.power_priority:
			var pd: PowerDef = _content().powers.get(p)
			assert_true(pd != null and pd.faction == f, "%s: power %s" % [f, p])
		for r: String in ai.research:
			assert_true(_content().upgrades.has(r), "%s: unknown research %s" % [f, r])


func test_every_factions_drop_off_comes_with_a_free_truck() -> void:
	# The UAE and EU hubs once lacked it and their early economy ran at half
	# speed, which lost them nearly every AI game (2026-11-28).
	for f: String in MatchConfig.FACTIONS:
		var ai: AiPlayer = AiPlayer.from_preset(_content(), f + "_default", 1)
		var found: bool = false
		for id: String in _content().buildings:
			var b: BuildingDef = _content().buildings[id]
			if b.faction == f and b.dropoff:
				assert_eq(b.free_unit, ai.gatherer_unit, "%s's %s gives no free truck" % [f, id])
				found = true
		assert_true(found, "%s has no drop-off building" % f)


func test_every_unit_can_be_built_by_its_faction() -> void:
	for id: String in _content().units:
		var u: UnitDef = _content().units[id]
		if not MatchConfig.FACTIONS.has(u.faction) or u.cost == 0 or u.decoy_of != "":
			continue   # power-only units (wingmen, decoys) and unplayable factions
		assert_true(_produced_by(u.faction, id), "nothing of the %s builds %s" % [u.faction, id])
		if u.requires_unlock != "":
			var pd: PowerDef = _content().powers.get(u.requires_unlock)
			assert_true(pd != null and pd.faction == u.faction, "%s: unlock %s is missing" % [id, u.requires_unlock])


func test_every_faction_has_powers_in_tiers_1_and_3() -> void:
	for f: String in MatchConfig.FACTIONS:
		var tiers: Dictionary[int, int] = {}
		for id: String in _content().powers:
			var p: PowerDef = _content().powers[id]
			if p.faction == f:
				tiers[p.tier] = tiers.get(p.tier, 0) + 1
		assert_true(tiers.get(1, 0) >= 1 and tiers.get(3, 0) >= 2, "%s power tree: %s" % [f, tiers])


func test_uae_against_north_korea_builds_and_fights() -> void:
	var sc: Dictionary = MatchConfig.skirmish(_content(), "twin_ridge", "ae", 10000, true, "normal", "kp")
	var runner := SimRunner.new()
	runner.world = MatchSetup.build_from(_content(), sc, 5)
	runner.players = [1, 2]
	runner.local_players = []
	runner.local_player_id = 0
	runner.add_ai_from_scenario(_content(), sc)
	runner.start()
	# Count what the UAE trained, not what survived: North Korea's early
	# infantry raids can kill a small first army (a balance matter, P3-02g).
	var trained: int = 0
	var fought: bool = false
	for i: int in SimWorld.TICK_RATE * 150:
		runner.try_step()
		for ev: Dictionary in runner.world.events:
			if ev.get("type") == "produced" and int(ev.get("player", 0)) == 1:
				var def: UnitDef = _content().get_unit(str(ev["def_id"]))
				if def != null and not def.weapons.is_empty():
					trained += 1
			elif ev.get("type") == "died" and int(ev.get("player", 0)) == 2:
				fought = true
	var world: SimWorld = runner.world
	var buildings: int = 0
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == 1 and e.def_id.begins_with("ae_") and e.building != null and e.building.built:
			buildings += 1
	assert_true(buildings >= 4, "the UAE AI has only %d finished buildings after 2.5 min" % buildings)
	assert_true(trained >= 3, "the UAE AI trained only %d combat units in 2.5 min" % trained)
	assert_true(fought, "the UAE killed nothing in 2.5 min")
	runner.free()


func _produced_by(faction: String, unit_id: String) -> bool:
	for id: String in _content().buildings:
		var b: BuildingDef = _content().buildings[id]
		if b.faction == faction and b.produces.has(unit_id):
			return true
	return false


func test_uae_strike_powers_launch_interceptable_strikes() -> void:
	var w := SimWorld.new(29, 256, 256)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.content = _content()
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "ae" if pid == 1 else "kp"
		p.rank = 5
		p.credits = 10000
	var seq: int = 0
	for power: String in ["ae_drone_swarm", "ae_standoff_strike"]:
		for c: SimCommand in [SimCommand.make_choose_power(power), SimCommand.make_use_power(power, Fx.from_int(180), Fx.from_int(128))]:
			c.player_id = 1
			seq += 1
			c.seq = seq
			c.tick = w.tick
			w.queue_command(c)
			w.step()
	var drones: int = 0
	var missiles: int = 0
	for id: int in w.entity_ids:
		var e: SimEntity = w.entities[id]
		if e.strike != null and e.player_id == 1:
			if e.def_id == "swarm_drone":
				drones += 1
			elif e.def_id == "standoff_missile":
				missiles += 1
	assert_eq(drones, 24, "the drone swarm")
	assert_eq(missiles, 4, "the stand-off strike")
