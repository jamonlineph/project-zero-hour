extends TestCase
# Grid pathfinding (P1-04).


func _def() -> UnitDef:
	var d := UnitDef.new()
	d.id = "walker"
	d.max_hp = 100
	d.speed = Fx.from_int(1)
	d.radius = Fx.from_int(1)
	return d


func _wall_map() -> SimMap:
	# 40 x 40 m (20 x 20 cells) with a wall at x 20-22 m from y 0 to 30 m.
	var map := SimMap.new(40, 40)
	map.add_obstacle_m(20, 0, 2, 30)
	return map


func _path_is_walkable(map: SimMap, start: Vector2i, path: Array[Vector2i]) -> bool:
	var pf := Pathfinder.new(map)
	var prev: Vector2i = map.cell_of(start.x, start.y)
	for p: Vector2i in path:
		var c: Vector2i = map.cell_of(p.x, p.y)
		c = Vector2i(clampi(c.x, 0, map.width_cells - 1), clampi(c.y, 0, map.height_cells - 1))
		if not pf._line_of_sight(map.padded_index(prev.x, prev.y), map.padded_index(c.x, c.y)):
			return false
		prev = c
	return true


func test_straight_path_in_open_ground_is_one_waypoint() -> void:
	var pf := Pathfinder.new(SimMap.new(40, 40))
	var path: Array[Vector2i] = pf.find_path(Fx.from_int(3), Fx.from_int(3), Fx.from_int(30), Fx.from_int(20))
	assert_eq(path, [Vector2i(Fx.from_int(30), Fx.from_int(20))] as Array[Vector2i])


func test_goes_around_a_wall() -> void:
	var map := _wall_map()
	var pf := Pathfinder.new(map)
	var start := Vector2i(Fx.from_int(10), Fx.from_int(10))
	var path: Array[Vector2i] = pf.find_path(start.x, start.y, Fx.from_int(30), Fx.from_int(10))
	assert_true(path.size() >= 2, "expected a detour, got %s" % str(path))
	assert_eq(path[path.size() - 1], Vector2i(Fx.from_int(30), Fx.from_int(10)))
	assert_true(_path_is_walkable(map, start, path), "path crosses the wall: %s" % str(path))
	# The detour has to pass below the wall's end (y >= 30 m).
	var lowest: int = 0
	for p: Vector2i in path:
		lowest = maxi(lowest, p.y)
	assert_true(lowest >= Fx.from_int(30), "detour did not go around the wall end")


func test_unreachable_goal_ends_at_nearest_reachable_cell() -> void:
	var map := SimMap.new(40, 40)
	map.add_obstacle_m(26, 0, 2, 40)          # full-height wall: right side unreachable
	var pf := Pathfinder.new(map)
	var path: Array[Vector2i] = pf.find_path(Fx.from_int(5), Fx.from_int(20), Fx.from_int(35), Fx.from_int(20))
	var last: Vector2i = path[path.size() - 1]
	var cell: Vector2i = map.cell_of(last.x, last.y)
	assert_eq(cell.x, 12, "should stop at the last cell before the wall")
	assert_true(map.is_passable(cell.x, cell.y))


func test_goal_inside_a_rock_stops_next_to_it() -> void:
	var map := SimMap.new(40, 40)
	map.add_obstacle_m(18, 18, 6, 6)
	var pf := Pathfinder.new(map)
	var path: Array[Vector2i] = pf.find_path(Fx.from_int(4), Fx.from_int(20), Fx.from_int(21), Fx.from_int(21))
	var last: Vector2i = path[path.size() - 1]
	var cell: Vector2i = map.cell_of(last.x, last.y)
	assert_true(map.is_passable(cell.x, cell.y))
	assert_true(absi(cell.x - 10) <= 2 and absi(cell.y - 10) <= 2, "ended far from the rock: %s" % cell)


func test_no_corner_cutting() -> void:
	# Two rocks touching only at a corner: the diagonal gap between them is closed.
	var map := SimMap.new(20, 20)
	map.add_obstacle_m(8, 8, 2, 2)     # cell (4, 4)
	map.add_obstacle_m(10, 10, 2, 2)   # cell (5, 5)
	var pf := Pathfinder.new(map)
	assert_false(pf._line_of_sight(map.padded_index(5, 4), map.padded_index(4, 5)))


func test_same_search_twice_gives_same_path() -> void:
	var db := ContentDb.new()
	db.load_all()
	var map: SimMap = db.get_map("sandbox").make_sim_map()
	var a: Array[Vector2i] = Pathfinder.new(map).find_path(Fx.from_int(20), Fx.from_int(30), Fx.from_int(110), Fx.from_int(40))
	var pf := Pathfinder.new(map)
	pf.find_path(Fx.from_int(100), Fx.from_int(100), Fx.from_int(5), Fx.from_int(5))  # reuse buffers
	var b: Array[Vector2i] = pf.find_path(Fx.from_int(20), Fx.from_int(30), Fx.from_int(110), Fx.from_int(40))
	assert_eq(a, b)


func test_units_route_through_the_ridge_gap() -> void:
	var db := ContentDb.new()
	db.load_all()
	var world := SimWorld.from_map(1, db.get_map("sandbox"))
	# From (30, 50) to (100, 50) the gap at y 56-74 is much shorter than going
	# around the ridge's top end at y < 10.
	var id: int = world.spawn_unit(_def(), 1, Fx.from_int(30), Fx.from_int(50))
	var c := SimCommand.make_move([id], Fx.from_int(100), Fx.from_int(50))
	c.player_id = 1
	c.tick = 0
	world.queue_command(c)
	var passed_gap: bool = false
	for i: int in 300:
		world.step()
		var e: SimEntity = world.get_entity(id)
		var cell: Vector2i = world.map.cell_of(e.x, e.y)
		assert_true(world.map.is_passable(cell.x, cell.y), "walked into rock at tick %d, cell %s" % [world.tick, cell])
		if cell.x >= 31 and cell.x <= 33:
			passed_gap = passed_gap or (e.y >= Fx.from_int(56) and e.y <= Fx.from_int(74))
	var e: SimEntity = world.get_entity(id)
	assert_eq([e.x, e.y], [Fx.from_int(100), Fx.from_int(50)])
	assert_true(passed_gap, "unit did not use the gap in the ridge")


func test_group_orders_are_spread_over_ticks() -> void:
	var world := SimWorld.new(1, 100, 100)
	var ids: Array[int] = []
	for i: int in 20:
		ids.append(world.spawn_unit(_def(), 1, Fx.from_int(5 + i * 3), Fx.from_int(5)))
	var c := SimCommand.make_move(ids, Fx.from_int(50), Fx.from_int(80))
	c.player_id = 1
	c.tick = 0
	world.queue_command(c)
	world.step()
	var waiting: int = 0
	for id: int in ids:
		if world.get_entity(id).mover.needs_path:
			waiting += 1
	assert_eq(waiting, 20 - PathingSystem.MAX_SEARCHES_PER_TICK)
	var ticks_needed: int = (20 + PathingSystem.MAX_SEARCHES_PER_TICK - 1) / PathingSystem.MAX_SEARCHES_PER_TICK
	for i: int in ticks_needed - 1:
		world.step()
	for id: int in ids:
		assert_false(world.get_entity(id).mover.needs_path)


func _check_tables(map: SimMap, pf: Pathfinder, label: String) -> void:
	# Table lookups must match a cell-by-cell scan for every cell and direction.
	pf._sync_tables()
	var walk: PackedByteArray = map.walk
	var pw: int = map.padded_width
	var mismatches: int = 0
	for y: int in map.height_cells:
		for x: int in map.width_cells:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				for goal: Vector2i in [Vector2i(-5, -5), Vector2i(x + d.x * 3, y + d.y * 3)]:
					var a: int = pf._jump_straight(x, y, d.x, d.y, goal.x, goal.y, walk, pw)
					var b: int = pf._jump_straight_scan(x, y, d.x, d.y, goal.x, goal.y)
					if a != b:
						mismatches += 1
	assert_eq(mismatches, 0, "JPS+ table mismatches (%s)" % label)


func test_jps_tables_match_scanning() -> void:
	var db := ContentDb.new()
	db.load_all()
	var map: SimMap = db.get_map("sandbox").make_sim_map()
	var pf := Pathfinder.new(map)
	_check_tables(map, pf, "sandbox")
	map.place_footprint(20, 20, 4, 3, 9)       # a building appears
	map.place_footprint(40, 50, 2, 2, 10)
	_check_tables(map, pf, "after placing buildings")
	map.clear_footprint(9)                     # and one is destroyed
	_check_tables(map, pf, "after removing a building")


func test_paths_avoid_new_buildings() -> void:
	var map := SimMap.new(40, 40)
	var pf := Pathfinder.new(map)
	var before: Array[Vector2i] = pf.find_path(Fx.from_int(5), Fx.from_int(20), Fx.from_int(35), Fx.from_int(20))
	assert_eq(before.size(), 1, "open ground should be a straight line")
	map.place_footprint(9, 4, 2, 14, 3)        # a long building across the line
	var start := Vector2i(Fx.from_int(5), Fx.from_int(20))
	var after: Array[Vector2i] = pf.find_path(start.x, start.y, Fx.from_int(35), Fx.from_int(20))
	assert_true(after.size() >= 2, "should detour around the new building")
	assert_true(_path_is_walkable(map, start, after))


func test_search_speed_on_a_256_m_map() -> void:
	# Budget from tasks/BACKLOG.md P1-04: 50 searches per second (about 3-4 per
	# tick) should cost well under 2 ms per tick on a desktop. This test only
	# fails on gross regressions (CI machines vary); it prints the real number.
	var map := SimMap.new(256, 256)
	for i: int in 12:
		map.add_obstacle_m(20 + i * 18, 10 + (i % 3) * 60, 4, 70)
	var pf := Pathfinder.new(map)
	var searches: int = 50
	var started: int = Time.get_ticks_usec()
	var expansions: int = 0
	for i: int in searches:
		pf.find_path(Fx.from_int(4), Fx.from_int(4 + i * 4), Fx.from_int(250), Fx.from_int(250 - i * 4))
		expansions += pf.last_expansions
	var per_search_ms: float = float(Time.get_ticks_usec() - started) / 1000.0 / searches
	print("        pathfinding: %.2f ms per worst-case search (corner to corner through walls), %d cells expanded on average" % [per_search_ms, expansions / searches])
	# Typical orders: 20-60 m moves around the sandbox's rocks.
	var db := ContentDb.new()
	db.load_all()
	var sandbox := Pathfinder.new(db.get_map("sandbox").make_sim_map())
	var rng := SimRng.new(5)
	started = Time.get_ticks_usec()
	for i: int in searches:
		var sx: int = 4 + rng.range_int(120)
		var sy: int = 4 + rng.range_int(120)
		sandbox.find_path(Fx.from_int(sx), Fx.from_int(sy),
			Fx.from_int(clampi(sx + rng.range_int(80) - 40, 1, 127)), Fx.from_int(clampi(sy + rng.range_int(80) - 40, 1, 127)))
	var typical_ms: float = float(Time.get_ticks_usec() - started) / 1000.0 / searches
	print("        pathfinding: %.2f ms per typical search (20-60 m on the sandbox)" % typical_ms)
	# Measured 2.4 ms (worst) and 0.09 ms (typical) on a desktop in P1-04b.
	# These limits leave room for slower CI machines.
	assert_true(per_search_ms < 10.0, "%.2f ms per worst-case search is a regression" % per_search_ms)
	assert_true(typical_ms < 1.0, "%.2f ms per typical search is a regression" % typical_ms)
