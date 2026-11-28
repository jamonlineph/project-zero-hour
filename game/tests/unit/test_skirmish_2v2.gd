extends TestCase
# 2v2 skirmish (P3-23b): you and a computer ally against two computers on a
# four-start map; player n starts at start n, allies share a team.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func test_the_config_has_two_teams_of_two() -> void:
	var sc: Dictionary = MatchConfig.skirmish_2v2(_content(), "pine_ridge", "eu", 10000, false, "hard", "kp", "rusher")
	var players: Array = sc["players"]
	assert_eq(players.size(), 4)
	var teams: Dictionary = {}
	for p: Dictionary in players:
		teams[int(p["id"])] = int(p["team"])
	assert_eq(teams, {1: 1, 2: 2, 3: 1, 4: 2})
	assert_false(players[0].has("ai"), "you were given an AI")
	assert_eq(players[2]["ai"], "eu_default", "the ally isn't of your faction")
	assert_eq(players[1]["ai"], "kp_default")
	assert_eq(players[3]["difficulty"], "hard")
	assert_eq(players[3]["personality"], "rusher")
	assert_true(MatchConfig.skirmish_2v2(_content(), "pine_ridge", "eu", 10000, true)["players"][0].has("ai"))


func test_every_player_starts_at_its_own_start() -> void:
	var sc: Dictionary = MatchConfig.skirmish_2v2(_content(), "pine_ridge", "us", 10000)
	var world: SimWorld = MatchSetup.build_from(_content(), sc, 3)
	var map: MapDef = _content().get_map("pine_ridge")
	for pid: int in [1, 2, 3, 4]:
		var hq: SimEntity = null
		for id: int in world.entity_ids:
			var e: SimEntity = world.entities[id]
			if e.player_id == pid and e.def_id.ends_with("_command_hq"):
				hq = e
		assert_true(hq != null, "player %d has no HQ" % pid)
		var start: Vector2i = map.start_positions[pid - 1]
		assert_true(Fx.length(hq.x - Fx.from_int(start.x), hq.y - Fx.from_int(start.y)) < Fx.from_int(10),
			"player %d's HQ is far from its start" % pid)
	assert_false(world.are_enemies(1, 3), "allies are enemies")
	assert_true(world.are_enemies(1, 2) and world.are_enemies(3, 4))


func test_four_computers_play_a_2v2() -> void:
	var sc: Dictionary = MatchConfig.skirmish_2v2(_content(), "pine_ridge", "us", 10000, true, "normal", "kp")
	var runner := SimRunner.new()
	runner.world = MatchSetup.build_from(_content(), sc, 11)
	runner.players = [1, 2, 3, 4]
	runner.local_players = []
	runner.local_player_id = 0
	runner.add_ai_from_scenario(_content(), sc)
	runner.start()
	assert_eq(runner.ai_players.size(), 4)
	for i: int in 150 * SimWorld.TICK_RATE:
		runner.try_step()
	var built: Dictionary[int, int] = {}
	for id: int in runner.world.entity_ids:
		var e: SimEntity = runner.world.entities[id]
		if e.building != null and e.building.built and e.player_id != 0:
			built[e.player_id] = built.get(e.player_id, 0) + 1
	for pid: int in [1, 2, 3, 4]:
		assert_true(built.get(pid, 0) >= 3, "player %d built only %d buildings" % [pid, built.get(pid, 0)])
	runner.free()
