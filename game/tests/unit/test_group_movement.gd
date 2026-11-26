extends TestCase
# Group movement (P1-05) and separation (P1-06).


func _def(radius_m: int = 1) -> UnitDef:
	var d := UnitDef.new()
	d.id = "squad"
	d.max_hp = 100
	d.speed = Fx.from_ratio(1, 2)
	d.radius = Fx.from_int(radius_m)
	return d


func _sandbox_world() -> SimWorld:
	var db := ContentDb.new()
	db.load_all()
	return SimWorld.from_map(3, db.get_map("sandbox"))


func _order(world: SimWorld, ids: Array[int], x_m: int, y_m: int) -> void:
	var c := SimCommand.make_move(ids, Fx.from_int(x_m), Fx.from_int(y_m))
	c.player_id = 1
	c.seq = world.tick + 1
	c.tick = world.tick
	world.queue_command(c)


func _spawn_block(world: SimWorld, x_m: int, y_m: int, cols: int, rows: int, spacing_m: int) -> Array[int]:
	var ids: Array[int] = []
	for r: int in rows:
		for c: int in cols:
			ids.append(world.spawn_unit(_def(), 1, Fx.from_int(x_m + c * spacing_m), Fx.from_int(y_m + r * spacing_m)))
	return ids


func _run(world: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		world.step()


func test_group_order_needs_few_searches() -> void:
	var world := _sandbox_world()
	var ids: Array[int] = _spawn_block(world, 24, 58, 3, 3, 3)
	var before: int = world.pathfinder.searches_run
	_order(world, ids, 100, 64)
	_run(world, 3)
	var searches: int = world.pathfinder.searches_run - before
	assert_true(searches <= 3, "a compact group of 9 ran %d searches" % searches)


func test_compact_group_keeps_its_layout() -> void:
	var world := SimWorld.new(1, 120, 120)
	var ids: Array[int] = _spawn_block(world, 10, 10, 2, 2, 4)
	var start: Array[Vector2i] = []
	for id: int in ids:
		start.append(Vector2i(world.get_entity(id).x, world.get_entity(id).y))
	_order(world, ids, 80, 90)
	_run(world, 400)
	var first := Vector2i(world.get_entity(ids[0]).x, world.get_entity(ids[0]).y)
	for i: int in ids.size():
		var e: SimEntity = world.get_entity(ids[i])
		var rel_now := Vector2i(e.x, e.y) - first
		var rel_then: Vector2i = start[i] - start[0]
		assert_true(absi(rel_now.x - rel_then.x) < Fx.ONE / 2 and absi(rel_now.y - rel_then.y) < Fx.ONE / 2,
			"unit %d moved out of formation: %s vs %s" % [i, rel_now, rel_then])


func test_spread_group_ends_in_distinct_open_slots() -> void:
	var world := _sandbox_world()
	var ids: Array[int] = []
	for i: int in 8:
		ids.append(world.spawn_unit(_def(), 1, Fx.from_int(6 + i * 14), Fx.from_int(6)))
	_order(world, ids, 30, 64)
	_run(world, 600)
	for id: int in ids:
		var e: SimEntity = world.get_entity(id)
		assert_false(e.mover.has_target, "unit %d never arrived" % id)
		var c: Vector2i = world.map.cell_of(e.x, e.y)
		assert_true(world.map.is_passable(c.x, c.y))
	_assert_no_big_overlaps(world, ids)


func test_group_crosses_the_ridge_without_entering_rock() -> void:
	var world := _sandbox_world()
	var ids: Array[int] = _spawn_block(world, 24, 58, 3, 3, 3)
	_order(world, ids, 100, 64)
	for t: int in 500:
		world.step()
		for id: int in ids:
			var e: SimEntity = world.get_entity(id)
			var c: Vector2i = world.map.cell_of(e.x, e.y)
			assert_true(world.map.is_passable(c.x, c.y), "tick %d: unit %d in rock at %s" % [world.tick, id, c])
			if not world.map.is_passable(c.x, c.y):
				return
	for id: int in ids:
		assert_true(world.get_entity(id).x > Fx.from_int(80), "unit %d did not cross" % id)


func test_stacked_units_separate() -> void:
	var world := SimWorld.new(1, 60, 60)
	var ids: Array[int] = []
	for i: int in 6:
		ids.append(world.spawn_unit(_def(), 1, Fx.from_int(30), Fx.from_int(30)))
	_run(world, 30)
	_assert_no_big_overlaps(world, ids)


func test_moving_unit_nudges_idle_unit_aside() -> void:
	var world := SimWorld.new(1, 60, 60)
	var idle: int = world.spawn_unit(_def(), 1, Fx.from_int(30), Fx.from_int(30))
	var mover: int = world.spawn_unit(_def(), 1, Fx.from_int(10), Fx.from_ratio(301, 10))
	_order(world, [mover], 50, 30)
	_run(world, 120)
	assert_false(world.get_entity(mover).mover.has_target, "the moving unit got stuck")
	var e: SimEntity = world.get_entity(idle)
	assert_true(Fx.length(e.x - Fx.from_int(30), e.y - Fx.from_int(30)) > 0, "idle unit was never pushed")


func test_pushes_never_enter_rock() -> void:
	var world := SimWorld.new(1, 40, 40)
	world.set_map(SimMap.new(40, 40))
	world.map.add_obstacle_m(20, 0, 4, 40)
	world.pathfinder = Pathfinder.new(world.map)
	var ids: Array[int] = []
	for i: int in 5:
		ids.append(world.spawn_unit(_def(), 1, Fx.from_ratio(195, 10), Fx.from_int(20)))
	_run(world, 40)
	for id: int in ids:
		var e: SimEntity = world.get_entity(id)
		var c: Vector2i = world.map.cell_of(e.x, e.y)
		assert_true(world.map.is_passable(c.x, c.y), "unit %d pushed into rock" % id)


func test_group_movement_is_deterministic() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var world := _sandbox_world()
		var ids: Array[int] = _spawn_block(world, 24, 58, 4, 3, 2)
		_order(world, ids, 100, 64)
		_run(world, 200)
		hashes.append(world.state_hash())
	assert_eq(hashes[0], hashes[1])


func _assert_no_big_overlaps(world: SimWorld, ids: Array[int]) -> void:
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: SimEntity = world.get_entity(ids[i])
			var b: SimEntity = world.get_entity(ids[j])
			var overlap: int = a.radius + b.radius - Fx.length(b.x - a.x, b.y - a.y)
			assert_true(overlap <= a.radius / 10, "units %d and %d overlap by %d" % [ids[i], ids[j], overlap])
