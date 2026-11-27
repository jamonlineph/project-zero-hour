extends TestCase
# Skirmish AI v0 (P1-31).

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _duel(seed_value: int, levels: Array = ["normal", "normal"]) -> SimRunner:
	var sc: Dictionary = (_content().scenarios["ai_duel"] as Dictionary).duplicate(true)
	for i: int in 2:
		(sc["players"] as Array)[i]["difficulty"] = levels[i]
	var runner := SimRunner.new()
	runner.world = MatchSetup.build_from(_content(), sc, seed_value)
	runner.players = [1, 2]
	runner.local_players = []
	runner.local_player_id = 0
	runner.add_ai_from_scenario(_content(), sc)
	runner.start()
	return runner


func test_presets_load() -> void:
	assert_true(_content().ai_presets.has("us_default"))
	var ai: AiPlayer = AiPlayer.from_preset(_content(), "kp_default", 2)
	assert_eq(ai.build_order[0], "kp_power_plant")
	assert_eq(ai.first_attack_tick, 200 * SimWorld.TICK_RATE)


func test_ai_builds_an_economy_and_an_army() -> void:
	var runner := _duel(1)
	for i: int in SimWorld.TICK_RATE * 150:
		runner.try_step()
	var world: SimWorld = runner.world
	var buildings: int = 0
	var army: int = 0
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id != 1:
			continue
		if e.building != null and e.building.built:
			buildings += 1
		elif e.mover != null and not e.weapons.is_empty():
			army += 1
	assert_true(buildings >= 4, "AI has only %d finished buildings after 2.5 min" % buildings)
	assert_true(army >= 3, "AI has only %d combat units after 2.5 min" % army)
	runner.free()


func test_ai_duel_ends_with_a_winner() -> void:
	var runner := _duel(3)
	var limit: int = SimWorld.TICK_RATE * 60 * 30
	var started: int = Time.get_ticks_msec()
	while not runner.world.game_over and runner.world.tick < limit:
		runner.try_step()
	print("        AI duel: game over at %d:%02d game time (winner team %d), %.1f s real time" % [
		runner.world.tick / SimWorld.TICK_RATE / 60, (runner.world.tick / SimWorld.TICK_RATE) % 60,
		runner.world.winner_team, (Time.get_ticks_msec() - started) / 1000.0])
	assert_true(runner.world.game_over, "no winner within 30 minutes of game time")
	runner.free()


func test_ai_is_deterministic() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var runner := _duel(5)
		for i: int in SimWorld.TICK_RATE * 60:
			runner.try_step()
		hashes.append(runner.world.state_hash())
		runner.free()
	assert_eq(hashes[0], hashes[1])


func test_easy_is_slower_and_attacks_later() -> void:
	var easy: AiPlayer = AiPlayer.from_preset(_content(), "us_default", 1, "easy")
	var normal: AiPlayer = AiPlayer.from_preset(_content(), "us_default", 1, "normal")
	assert_true(easy.think_interval > normal.think_interval)
	assert_true(easy.first_attack_tick > normal.first_attack_tick)
	assert_true(easy.counters.is_empty(), "easy should not counter-build")
	assert_false(normal.counters.is_empty())


func test_counter_bonus_follows_what_the_ai_sees() -> void:
	var w := SimWorld.new(3, 200, 200)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	var ai: AiPlayer = AiPlayer.from_preset(_content(), "us_default", 1)
	w.spawn_unit(_content().get_unit("us_rifle_squad"), 1, Fx.from_int(100), Fx.from_int(100))
	for i: int in 6:
		w.spawn_unit(_content().get_unit("kp_recon_drone"), 2, Fx.from_int(110 + i), Fx.from_int(100))
	w.step()
	var bonus: Dictionary[String, int] = AiStrategy.counter_bonus(w, ai)
	assert_eq(bonus.get("us_laser_cuas", 0), 2, "6 visible drones should add 2 weight to the laser vehicle")
	assert_false(bonus.has("us_at_team"), "no tanks were seen")


func test_normal_ai_uses_powers_and_researches() -> void:
	var runner := _duel(7)
	var powers_used: int = 0
	var researched: int = 0
	for i: int in SimWorld.TICK_RATE * 60 * 8:
		runner.try_step()
		for ev: Dictionary in runner.world.events:
			if ev["type"] == "power_used":
				powers_used += 1
			elif ev["type"] == "researched":
				researched += 1
		if runner.world.game_over:
			break
	assert_true(powers_used >= 2, "the AIs used %d commander powers in 8 minutes" % powers_used)
	assert_true(researched >= 1, "no AI researched an upgrade")
	runner.free()


func _base_world() -> SimWorld:
	var w := SimWorld.new(3, 200, 200)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		w.get_player(pid).team = pid
		w.get_player(pid).faction = "us" if pid == 1 else "kp"
	w.spawn_building(_content().get_building("us_command_hq"), 1, 10, 40, true)
	w.spawn_building(_content().get_building("us_microreactor"), 1, 10, 60, true)
	return w


func _produced(cmds: Array[SimCommand], def_id: String) -> int:
	var n: int = 0
	for c: SimCommand in cmds:
		if c.type == SimCommand.Type.PRODUCE and c.def_id == def_id:
			n += 1
	return n


func test_ai_keeps_at_most_max_spotters_recon_drones() -> void:
	var w := _base_world()
	w.get_player(1).credits = 20000
	w.spawn_building(_content().get_building("us_drone_center"), 1, 30, 40, true)
	var ai: AiPlayer = AiPlayer.from_preset(_content(), "us_default", 1)
	assert_eq(ai.max_spotters, 2)
	assert_true(_produced(ai.think(w), "us_recon_drone") >= 1, "no drone was queued with none in the field")
	var w2 := _base_world()
	w2.get_player(1).credits = 20000
	w2.spawn_building(_content().get_building("us_drone_center"), 1, 30, 40, true)
	for i: int in 2:
		w2.spawn_unit(_content().get_unit("us_recon_drone"), 1, Fx.from_int(60 + i * 4), Fx.from_int(100))
	var ai2: AiPlayer = AiPlayer.from_preset(_content(), "us_default", 1)
	assert_eq(_produced(ai2.think(w2), "us_recon_drone"), 0, "queued a third recon drone")


func test_a_stalled_army_attacks_without_a_full_wave() -> void:
	var w := _base_world()
	w.get_player(1).credits = 0
	var tank: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit("us_mbt"), 1, Fx.from_int(60), Fx.from_int(100)))
	w.spawn_building(_content().get_building("kp_power_plant"), 2, 85, 85, true)
	var ai: AiPlayer = AiPlayer.from_preset(_content(), "us_default", 1)
	ai.think(w)   # first think picks this match's timings
	ai._first_attack = 0
	var attacked_at: int = -1
	while w.tick < AiPlayer.STALL_TICKS + 60 and attacked_at < 0:
		w.tick += 1
		for c: SimCommand in ai.think(w):
			if c.type == SimCommand.Type.ATTACK_MOVE and c.entity_ids.has(tank.id):
				attacked_at = w.tick
	assert_true(attacked_at >= AiPlayer.STALL_TICKS, "one tank attacked before the army stalled (tick %d)" % attacked_at)
	assert_true(attacked_at <= AiPlayer.STALL_TICKS + ai.think_interval, "a stalled army never attacked")
