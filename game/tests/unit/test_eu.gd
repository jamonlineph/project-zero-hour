extends TestCase
# The EU (P3-12a): healing auras (medics, logistics trucks), field repair,
# cyber defense, air policing, and an AI that builds and fights.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(rank: int = 1) -> SimWorld:
	var w := SimWorld.new(47, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "eu" if pid == 1 else "kp"
		p.rank = rank
		p.credits = 10000
	return w


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	var e: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))
	e.weapons.clear()
	return e


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func _power(w: SimWorld, power: String, x_m: int = 120, y_m: int = 120) -> void:
	for c: SimCommand in [SimCommand.make_choose_power(power), SimCommand.make_use_power(power, Fx.from_int(x_m), Fx.from_int(y_m))]:
		c.player_id = 1
		_seq += 1
		c.seq = _seq
		c.tick = w.tick
		w.queue_command(c)
		w.step()


func test_the_eu_is_playable() -> void:
	assert_true(MatchConfig.FACTIONS.has("eu"))
	var sc: Dictionary = MatchConfig.skirmish(_content(), "twin_ridge", "eu", 10000, false, "normal", "ae")
	assert_eq((sc["players"] as Array)[0]["faction"], "eu")
	assert_eq((sc["players"] as Array)[1]["ai"], "ae_default")


func test_medics_heal_nearby_infantry_only() -> void:
	var w := _world()
	_unit(w, "eu_medics", 1, 100, 100)
	var squad := _unit(w, "eu_rifle_squad", 1, 105, 100)
	var far := _unit(w, "eu_rifle_squad", 1, 150, 100)
	var apc := _unit(w, "eu_apc", 1, 100, 108)
	var enemy := _unit(w, "kp_infantry_squad", 2, 100, 94)
	for e: SimEntity in [squad, far, apc, enemy]:
		e.hp = e.max_hp / 2
	_run(w, SimWorld.TICK_RATE * 2 + 1)
	var pct: int = _content().get_unit("eu_medics").heal_percent_per_s
	assert_eq(squad.hp, squad.max_hp / 2 + 2 * (squad.max_hp * pct / 100), "%d%% a second" % pct)
	assert_eq(far.hp, far.max_hp / 2, "healed from beyond the aura")
	assert_eq(apc.hp, apc.max_hp / 2, "medics repaired a vehicle")
	assert_eq(enemy.hp, enemy.max_hp / 2, "medics healed an enemy")


func test_auras_dont_stack_and_trucks_repair_vehicles() -> void:
	var w := _world()
	_unit(w, "eu_medics", 1, 100, 100)
	_unit(w, "eu_medics", 1, 102, 100)
	_unit(w, "eu_logistics_truck", 1, 100, 112)
	var squad := _unit(w, "eu_rifle_squad", 1, 104, 102)
	var tank := _unit(w, "eu_mbt", 1, 104, 116)
	squad.hp = 100
	tank.hp = 500
	_run(w, SimWorld.TICK_RATE + 1)
	assert_eq(squad.hp, 100 + squad.max_hp * _content().get_unit("eu_medics").heal_percent_per_s / 100, "two medics healed twice")
	assert_eq(tank.hp, 500 + tank.max_hp / 100, "the truck didn't repair the tank by 1%")


func test_field_repair_restores_own_vehicles_in_the_area() -> void:
	var w := _world()
	var tank := _unit(w, "eu_mbt", 1, 120, 120)
	var outside := _unit(w, "eu_mbt", 1, 200, 200)
	var enemy := _unit(w, "kp_mbt", 2, 125, 120)
	for e: SimEntity in [tank, outside, enemy]:
		e.hp = 300
	_power(w, "eu_field_repair")
	assert_eq(tank.hp, 300 + tank.max_hp * 40 / 100)
	assert_eq(outside.hp, 300)
	assert_eq(enemy.hp, 300, "field repair healed an enemy")


func test_cyber_defense_makes_jamming_miss_us_for_a_while() -> void:
	var w := _world(3)
	_unit(w, "kp_ew_vehicle", 2, 120, 120)
	_run(w, 2)
	assert_true(w.jam_level(1, Fx.from_int(120), Fx.from_int(125)) > 0, "the jammer should cover the point")
	_power(w, "eu_cyber_defense")
	assert_eq(w.jam_level(1, Fx.from_int(120), Fx.from_int(125)), 0, "cyber defense didn't block the jamming")
	_run(w, 30 * SimWorld.TICK_RATE)
	assert_true(w.jam_level(1, Fx.from_int(120), Fx.from_int(125)) > 0, "cyber defense never ended")


func test_air_policing_sends_two_fighters() -> void:
	var w := _world()
	_power(w, "eu_air_policing")
	var n: int = 0
	for id: int in w.entity_ids:
		if w.entities[id].def_id == "eu_patrol_fighter":
			n += 1
			assert_true(w.entities[id].ttl > 0, "patrol fighters must leave after 45 s")
	assert_eq(n, 2)


func test_eu_against_north_korea_builds_and_fights() -> void:
	var sc: Dictionary = MatchConfig.skirmish(_content(), "twin_ridge", "eu", 10000, true, "normal", "kp")
	var runner := SimRunner.new()
	runner.world = MatchSetup.build_from(_content(), sc, 7)
	runner.players = [1, 2]
	runner.local_players = []
	runner.local_player_id = 0
	runner.add_ai_from_scenario(_content(), sc)
	runner.start()
	var trained: int = 0
	for i: int in SimWorld.TICK_RATE * 150:
		runner.try_step()
		for ev: Dictionary in runner.world.events:
			if ev.get("type") == "produced" and int(ev.get("player", 0)) == 1 and str(ev["def_id"]) != "eu_logistics_truck":
				trained += 1
	assert_true(trained >= 3, "the EU AI trained only %d units in 2.5 min" % trained)
	runner.free()


func test_the_ai_uses_field_repair_on_its_damaged_vehicles() -> void:
	var w := _world()
	w.get_player(1).powers.append("eu_field_repair")
	var ai: AiPlayer = AiPlayer.from_preset(_content(), "eu_default", 1)
	var tank := _unit(w, "eu_mbt", 1, 150, 150)
	var cmds: Array[SimCommand] = []
	AiStrategy.powers(w, ai, null, [tank], cmds)
	assert_eq(cmds.size(), 0, "repaired a healthy army")
	tank.hp = 300
	AiStrategy.powers(w, ai, null, [tank], cmds)
	assert_eq(cmds.size(), 1)
	assert_eq(cmds[0].type, SimCommand.Type.USE_POWER)
	assert_eq(cmds[0].target_x, tank.x)

