extends TestCase
# Map grid and passability (P1-03).


func test_size_in_cells_rounds_up() -> void:
	var map := SimMap.new(128, 101)
	assert_eq(map.width_cells, 64)
	assert_eq(map.height_cells, 51)


func test_world_to_cell_conversion() -> void:
	assert_eq(SimMap.cell_coord(0), 0)
	assert_eq(SimMap.cell_coord(Fx.from_ratio(199, 100)), 0)
	assert_eq(SimMap.cell_coord(Fx.from_int(2)), 1)
	assert_eq(SimMap.cell_coord(Fx.from_ratio(-1, 100)), -1)
	assert_eq(SimMap.cell_center(3, 0), Vector2i(Fx.from_int(7), Fx.from_int(1)))
	var map := SimMap.new(20, 20)
	assert_eq(map.cell_of(Fx.from_int(5), Fx.from_int(19)), Vector2i(2, 9))


func test_bounds_are_impassable() -> void:
	var map := SimMap.new(20, 20)
	assert_true(map.is_passable(0, 0))
	assert_true(map.is_passable(9, 9))
	assert_false(map.is_passable(-1, 0))
	assert_false(map.is_passable(10, 0))
	assert_false(map.is_passable(0, 10))


func test_obstacles_block_every_overlapping_cell() -> void:
	var map := SimMap.new(40, 40)
	map.add_obstacle_m(3, 4, 4, 1)   # x 3..7 m, y 4..5 m -> cells x 1..3, y 2
	assert_eq(map.blocked_count(), 3)
	for cx: int in [1, 2, 3]:
		assert_false(map.is_passable(cx, 2), "cell %d,2 should be blocked" % cx)
	assert_true(map.is_passable(0, 2))
	assert_true(map.is_passable(4, 2))
	assert_true(map.is_passable(2, 1))
	assert_true(map.is_passable(2, 3))


func test_footprints_claim_and_release() -> void:
	var map := SimMap.new(40, 40)
	assert_true(map.place_footprint(2, 2, 3, 2, 7))
	assert_eq(map.footprint_owner(4, 3), 7)
	assert_false(map.is_passable(3, 3))
	assert_false(map.place_footprint(4, 3, 2, 2, 8), "overlapping footprint must fail")
	assert_eq(map.footprint_owner(5, 4), 0, "a failed placement must claim nothing")
	assert_eq(map.clear_footprint(7), 6)
	assert_true(map.is_passable(3, 3))


func test_footprint_cannot_cover_rock_or_edge() -> void:
	var map := SimMap.new(20, 20)
	map.add_obstacle_m(4, 4, 2, 2)
	assert_false(map.place_footprint(1, 1, 2, 2, 5))
	assert_false(map.place_footprint(9, 9, 2, 2, 5))
	assert_true(map.place_footprint(5, 5, 2, 2, 5))


func test_footprints_change_the_state_hash() -> void:
	var a := SimWorld.new(1, 40, 40)
	var b := SimWorld.new(1, 40, 40)
	assert_eq(a.state_hash(), b.state_hash())
	b.map.place_footprint(1, 1, 1, 1, 3)
	assert_ne(a.state_hash(), b.state_hash())


func test_sandbox_map_loads_with_its_obstacles() -> void:
	var db := ContentDb.new()
	assert_true(db.load_all(), ", ".join(db.errors))
	var def: MapDef = db.get_map("sandbox")
	assert_true(def != null, "sandbox map missing")
	assert_eq(def.obstacles_m.size(), 10)
	var world := SimWorld.from_map(1, def)
	assert_eq(world.map_width, Fx.from_int(128))
	assert_true(world.map.blocked_count() > 100)
	# The ridge has a gap in the middle at y 56-74 m.
	assert_false(world.map.is_passable(32, 10))
	assert_true(world.map.is_passable(32, 32))


func test_sandbox_units_do_not_start_inside_rocks() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# _ready builds everything; we only need the world, then free the scene.
	main._ready()
	var world: SimWorld = main.get("world")
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var c: Vector2i = world.map.cell_of(e.x, e.y)
		assert_true(world.map.is_passable(c.x, c.y), "unit %d starts on a blocked cell" % id)
	main.free()
