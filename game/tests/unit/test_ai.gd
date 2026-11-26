extends TestCase
# Skirmish AI v0 (P1-31).

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _duel(seed_value: int) -> SimRunner:
	var runner := SimRunner.new()
	runner.world = MatchSetup.build(_content(), "ai_duel", seed_value)
	runner.players = [1, 2]
	runner.local_players = []
	runner.local_player_id = 0
	runner.add_ai_from_scenario(_content(), _content().scenarios["ai_duel"])
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
