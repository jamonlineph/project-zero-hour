extends TestCase
# Determinism is what makes replays and lockstep multiplayer possible: the
# same seed and the same commands must always produce the same state hash.


func _def() -> UnitDef:
	var d := UnitDef.new()
	d.id = "det_unit"
	d.max_hp = 50
	d.speed = Fx.from_ratio(7, 10)
	d.radius = Fx.from_int(1)
	return d


## Builds a world and a fixed, irregular command script.
func _run(seed_value: int, ticks: int, commands: Array[SimCommand]) -> Array[int]:
	var world := SimWorld.new(seed_value, 200, 200)
	var def: UnitDef = _def()
	for i: int in 12:
		world.spawn_unit(def, 1 + i % 2, Fx.from_int(20 + i * 7), Fx.from_int(30 + (i * 13) % 50))
	for c: SimCommand in commands:
		world.queue_command(SimCommand.from_dict(c.to_dict()))
	var hashes: Array[int] = []
	for t: int in ticks:
		world.step()
		hashes.append(world.state_hash())
	return hashes


func _script() -> Array[SimCommand]:
	var cmds: Array[SimCommand] = []
	var seq: int = 0
	for t: int in [0, 3, 3, 10, 25, 40]:
		seq += 1
		var c := SimCommand.make_move([1, 3, 5, 7], Fx.from_int(40 + t), Fx.from_int(150 - t))
		c.player_id = 1
		c.seq = seq
		c.tick = t
		cmds.append(c)
		var d := SimCommand.make_move([2, 4, 6], Fx.from_int(160 - t), Fx.from_int(20 + t))
		d.player_id = 2
		d.seq = seq
		d.tick = t
		cmds.append(d)
	var stop := SimCommand.make_stop([3])
	stop.player_id = 1
	stop.seq = 99
	stop.tick = 30
	cmds.append(stop)
	return cmds


func test_same_inputs_same_hashes() -> void:
	var a: Array[int] = _run(777, 200, _script())
	var b: Array[int] = _run(777, 200, _script())
	assert_eq(a.size(), 200)
	for i: int in a.size():
		if a[i] != b[i]:
			assert_eq(b[i], a[i], "desync at tick %d" % (i + 1))
			return


func test_different_seed_changes_hash() -> void:
	var a: Array[int] = _run(1, 5, [])
	var b: Array[int] = _run(2, 5, [])
	assert_ne(a[4], b[4])


func test_command_order_inside_tick_is_canonical() -> void:
	# The same commands queued in a different order must give the same result.
	var forward: Array[SimCommand] = _script()
	var backward: Array[SimCommand] = _script()
	backward.reverse()
	var a: Array[int] = _run(5, 80, forward)
	var b: Array[int] = _run(5, 80, backward)
	assert_eq(a[79], b[79])
