extends TestCase
# Save and load (P3-22): a loaded save reaches exactly the saved state, and
# the match then plays on exactly as the original does (AI state included).

const TEST_DIR: String = "user://test_saves/"

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


## Player 1 human, player 2 AI, on Twin Ridge.
func _runner(scenario: Dictionary, seed_value: int) -> SimRunner:
	var r := SimRunner.new()
	r.world = MatchSetup.build_from(_content(), scenario, seed_value)
	r.local_player_id = 1
	r.players = [1, 2]
	r.local_players = [1, 2]
	r.scenario_data = scenario
	r.seed_value = seed_value
	r.add_ai_from_scenario(_content(), scenario)
	r.start()
	return r


func _step(r: SimRunner, ticks: int) -> void:
	for i: int in ticks:
		r.try_step()


func _own(r: SimRunner, suffix: String) -> int:
	for id: int in r.world.entity_ids:
		var e: SimEntity = r.world.entities[id]
		if e.player_id == 1 and e.def_id.ends_with(suffix):
			return id
	return 0


func _clean() -> void:
	var d := DirAccess.open(TEST_DIR)
	if d != null:
		for f: String in d.get_files():
			d.remove(f)


func test_load_reaches_the_saved_state_and_plays_on_the_same() -> void:
	SaveGame.dir = TEST_DIR
	_clean()
	var scenario: Dictionary = MatchConfig.skirmish(_content(), "twin_ridge", "us", 10000)
	var a := _runner(scenario, 4242)
	_step(a, 30)
	# The human builds a power plant and sends the engineer around.
	var eng: int = _own(a, "_engineer")
	assert_true(eng != 0)
	var hq: SimEntity = a.world.get_entity(_own(a, "_command_hq"))
	a.submit(SimCommand.make_build([eng], "us_microreactor", hq.x + Fx.from_int(14), hq.y + Fx.from_int(14)))
	_step(a, 300)
	a.submit(SimCommand.make_move([eng], hq.x, hq.y - Fx.from_int(10)))
	_step(a, 600)
	var path: String = SaveGame.save(a, "test")
	assert_true(path != "", "the game was not saved")
	var data: Dictionary = SaveGame.read(path)
	assert_eq(int(data["end_tick"]), a.world.tick)

	var b := _runner(data["scenario_data"], int(data["seed"]))
	var loader := SaveLoader.new()
	loader.begin(b, data)
	var guard: int = 0
	while not loader.advance(200) and guard < 100:
		guard += 1
	assert_true(loader.matches(), "the loaded game differs from the saved one")
	assert_eq(b.world.state_hash(), a.world.state_hash())
	# Play on: the AI must make the same moves in both.
	_step(a, 900)
	_step(b, 900)
	assert_eq(b.world.tick, a.world.tick)
	assert_eq(b.world.state_hash(), a.world.state_hash(), "the loaded game played on differently")
	a.free()
	b.free()
	_clean()
	SaveGame.dir = "user://saves/"


func test_saves_are_listed_newest_first_and_bad_files_are_skipped() -> void:
	SaveGame.dir = TEST_DIR
	_clean()
	var scenario: Dictionary = MatchConfig.skirmish(_content(), "twin_ridge", "us", 10000)
	var a := _runner(scenario, 1)
	_step(a, 20)
	var first: String = SaveGame.save(a)
	_step(a, 20)
	var second: String = SaveGame.save(a)
	var junk := FileAccess.open(TEST_DIR + "junk.json", FileAccess.WRITE)
	junk.store_string("{\"not\": \"a save\"}")
	junk.close()
	var saves: Array[Dictionary] = SaveGame.list()
	assert_eq(saves.size(), 2, "the junk file was listed")
	assert_eq(saves[0]["path"], second)
	assert_eq(saves[1]["path"], first)
	assert_eq(saves[0]["map"], "twin_ridge")
	assert_true(SaveGame.read(TEST_DIR + "junk.json").is_empty())
	a.free()
	_clean()
	SaveGame.dir = "user://saves/"
