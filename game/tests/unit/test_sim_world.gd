extends TestCase


func _tank_def() -> UnitDef:
	var d := UnitDef.new()
	d.id = "test_tank"
	d.armor_class = "heavy_armor"
	d.max_hp = 100
	d.speed = Fx.from_int(1)        # 1 m per tick
	d.radius = Fx.from_int(2)
	return d


func _move(world: SimWorld, player: int, seq: int, ids: Array[int], x_m: int, y_m: int) -> SimCommand:
	var c := SimCommand.make_move(ids, Fx.from_int(x_m), Fx.from_int(y_m))
	c.player_id = player
	c.seq = seq
	c.tick = world.tick
	world.queue_command(c)
	return c


func test_unit_moves_and_stops_exactly_on_target() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_tank_def(), 1, Fx.from_int(10), Fx.from_int(10))
	_move(world, 1, 1, [id], 20, 10)
	for i: int in 15:
		world.step()
	var e: SimEntity = world.get_entity(id)
	assert_eq(e.x, Fx.from_int(20))
	assert_eq(e.y, Fx.from_int(10))
	assert_false(e.mover.has_target)


func test_moves_at_most_speed_per_tick() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_tank_def(), 1, Fx.from_int(10), Fx.from_int(10))
	_move(world, 1, 1, [id], 50, 50)
	world.step()
	var e: SimEntity = world.get_entity(id)
	var moved: int = Fx.length(e.x - e.prev_x, e.y - e.prev_y)
	assert_true(moved <= Fx.from_int(1), "moved %d" % moved)
	assert_true(moved > 0)


func test_cannot_command_other_players_units() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_tank_def(), 1, Fx.from_int(10), Fx.from_int(10))
	_move(world, 2, 1, [id], 30, 30)
	world.step()
	var e: SimEntity = world.get_entity(id)
	assert_false(e.mover.has_target)
	assert_eq(e.x, Fx.from_int(10))


func test_stop_clears_target() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_tank_def(), 1, Fx.from_int(10), Fx.from_int(10))
	_move(world, 1, 1, [id], 60, 10)
	world.step()
	var c := SimCommand.make_stop([id])
	c.player_id = 1
	c.seq = 2
	c.tick = world.tick
	world.queue_command(c)
	world.step()
	assert_false(world.get_entity(id).mover.has_target)


func test_group_move_spreads_targets() -> void:
	var world := SimWorld.new(1, 100, 100)
	var ids: Array[int] = []
	for i: int in 4:
		ids.append(world.spawn_unit(_tank_def(), 1, Fx.from_int(10 + i * 5), Fx.from_int(10)))
	_move(world, 1, 1, ids, 50, 50)
	world.step()
	var seen: Dictionary = {}
	for id: int in ids:
		var m: SimMover = world.get_entity(id).mover
		var key: String = "%d,%d" % [m.target_x, m.target_y]
		assert_false(seen.has(key), "two units got the same target")
		seen[key] = true


func test_targets_are_clamped_to_map() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_tank_def(), 1, Fx.from_int(10), Fx.from_int(10))
	_move(world, 1, 1, [id], 500, -20)
	world.step()
	var m: SimMover = world.get_entity(id).mover
	assert_eq(m.target_x, world.map_width)
	assert_eq(m.target_y, 0)


func test_commands_for_past_ticks_are_dropped() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_tank_def(), 1, Fx.from_int(10), Fx.from_int(10))
	world.step()
	var c := SimCommand.make_move([id], Fx.from_int(50), Fx.from_int(50))
	c.player_id = 1
	c.tick = 0   # already in the past
	world.queue_command(c)
	world.step()
	assert_false(world.get_entity(id).mover.has_target)
