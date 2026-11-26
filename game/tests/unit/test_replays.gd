extends TestCase
# Replays (P1-20) and the lockstep scheduler (P1-21).

const REPLAY_DIR: String = "res://tests/replays/"

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func test_golden_replays_match() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(REPLAY_DIR)
	var checked: int = 0
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var replay: Replay = Replay.load_file(REPLAY_DIR + f)
		assert_true(replay != null, "%s could not be read" % f)
		if replay == null:
			continue
		var problems: PackedStringArray = replay.verify(_content(), false)
		assert_true(problems.is_empty(), "%s: %s (run tools/regen_golden_replays.sh if the change was intended)" % [f, ", ".join(problems)])
		checked += 1
	assert_true(checked >= 3, "expected at least 3 golden replays, found %d" % checked)


func test_replay_round_trip_through_json() -> void:
	var runner := _runner()
	var blue: Array[int] = _armed(runner.world, 1)
	runner.submit(SimCommand.make_attack_move(blue, Fx.from_int(100), Fx.from_int(60)))
	for i: int in 300:
		runner.try_step()
	var replay: Replay = runner.make_replay()
	var copy: Replay = Replay.from_dict(JSON.parse_string(JSON.stringify(replay.to_dict())))
	assert_eq(copy.commands.size(), 1)
	assert_true(copy.verify(_content()).is_empty())
	var world: SimWorld = copy.play(_content())
	assert_eq(world.state_hash(), runner.world.state_hash())
	runner.free()


func test_content_hash_detects_changes() -> void:
	var replay := Replay.new()
	replay.scenario_id = "sandbox"
	replay.content_hash = _content().content_hash + 1
	var problems: PackedStringArray = replay.verify(_content())
	assert_eq(problems.size(), 1)


func test_single_player_never_waits() -> void:
	var runner := _runner()
	for i: int in 50:
		assert_true(runner.try_step(), "local game blocked at tick %d" % runner.world.tick)
	assert_eq(runner.world.tick, 50)
	assert_true(runner.hash_log.has(15) and runner.hash_log.has(45))
	runner.free()


func test_commands_run_after_the_input_delay() -> void:
	var runner := _runner()
	runner.input_delay = 3
	runner.start()
	var blue: Array[int] = _armed(runner.world, 1)
	runner.submit(SimCommand.make_stop(blue))
	runner.try_step()
	assert_eq(runner.command_log.size(), 0, "ran before the input delay")
	for i: int in 3:
		runner.try_step()
	assert_eq(runner.command_log.size(), 1)
	assert_eq(int(runner.command_log[0]["tick"]), 3)
	runner.free()


func test_waits_for_a_late_remote_player() -> void:
	# Reference: both players' commands known up front.
	var reference := _runner()
	reference.players = [1, 2]
	reference.local_players = [1, 2]
	reference.start()
	var red_ref: Array[int] = _armed(reference.world, 2)
	reference.receive_batch(2, 5, [_attack_move(red_ref, 28)])
	for i: int in 120:
		reference.try_step()
	# Lockstep: player 2 is remote and its batches arrive late.
	var runner := _runner()
	runner.players = [1, 2]
	runner.local_players = [1]
	runner.start()
	var red: Array[int] = _armed(runner.world, 2)
	var waited: int = 0
	var t: int = 1
	while runner.world.tick < 120:
		if not runner.try_step():
			waited += 1
			# Deliver the missing batch (tick 5 carries the order).
			var cmds: Array[SimCommand] = []
			if t == 5:
				cmds.append(_attack_move(red, 28))
			runner.receive_batch(2, t, cmds)
			t += 1
	assert_true(waited > 0, "the runner never waited for the remote player")
	assert_eq(runner.world.state_hash(), reference.world.state_hash())
	reference.free()
	runner.free()


func _runner() -> SimRunner:
	var runner := SimRunner.new()
	runner.world = MatchSetup.build(_content(), "sandbox", 99)
	runner.scenario_id = "sandbox"
	runner.seed_value = 99
	runner.local_player_id = 1
	return runner


func _armed(world: SimWorld, player: int) -> Array[int]:
	var ids: Array[int] = []
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == player and e.mover != null and not e.weapons.is_empty():
			ids.append(id)
	return ids


func _attack_move(ids: Array[int], x_m: int) -> SimCommand:
	var c := SimCommand.make_attack_move(ids, Fx.from_int(x_m), Fx.from_int(60))
	c.seq = 1
	return c
