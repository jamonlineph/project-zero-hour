extends TestCase
# Side fairness (P2-11c): mirrored inputs give mirrored results, and the AI
# varies between match seeds.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(seed_value: int = 3) -> SimWorld:
	var w := SimWorld.new(seed_value, 128, 128)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	return w


func test_mirrored_points_give_mirrored_footprints() -> void:
	var w := _world()
	var cells: int = w.map.width_cells
	# Odd and even footprints, at points on a cell edge, a cell center and between.
	for id: String in ["us_command_hq", "us_barracks", "us_sam_site", "us_microreactor", "us_logistics_hub"]:
		var def: BuildingDef = _content().get_building(id)
		for x_cm: int in [2000, 2100, 2050, 3300, 5100, 6300]:
			var x: int = (x_cm * Fx.ONE) / 100
			var west: Vector2i = w.footprint_origin(def, x, Fx.from_int(40))
			var east: Vector2i = w.footprint_origin(def, w.map_width - x, Fx.from_int(40))
			assert_eq(east.x, cells - west.x - def.footprint_w,
				"%s at %d cm and its mirror are not mirrored" % [id, x_cm])
			assert_eq(east.y, west.y)


func test_footprints_stay_centered_on_the_point() -> void:
	var w := _world()
	var def: BuildingDef = _content().get_building("us_barracks")   # 5 x 4 cells
	var o: Vector2i = w.footprint_origin(def, Fx.from_int(31), (4060 * Fx.ONE) / 100)
	var cx: int = o.x * SimMap.CELL + (def.footprint_w * SimMap.CELL) / 2
	var cy: int = o.y * SimMap.CELL + (def.footprint_h * SimMap.CELL) / 2
	assert_eq(cx, Fx.from_int(31), "an odd footprint should center on the cell holding the point")
	assert_eq(cy, Fx.from_int(40), "an even footprint should center on the nearest cell edge")
	# Exactly between two edges, it goes toward the middle of the map.
	o = w.footprint_origin(def, Fx.from_int(31), Fx.from_int(41))
	assert_eq(o.y * SimMap.CELL + (def.footprint_h * SimMap.CELL) / 2, Fx.from_int(42))


func test_exit_cells_are_mirrored() -> void:
	var w := _world()
	var def: BuildingDef = _content().get_building("us_microreactor")   # even width: the exit ties
	var west: SimEntity = w.get_entity(w.spawn_building(def, 1, 10, 20, true))
	var east: SimEntity = w.get_entity(w.spawn_building(def, 2, w.map.width_cells - 10 - def.footprint_w, 20, true))
	var south: int = west.y + Fx.from_int(10)
	var a: Vector2i = w.approach_point(west, west.x, south)
	var b: Vector2i = w.approach_point(east, east.x, south)
	assert_eq(b.x, w.map_width - a.x, "the two bases' units leave from unmirrored cells")
	assert_eq(b.y, a.y)


func _first_attack(seed_value: int) -> int:
	var w := _world(seed_value)
	var ai: AiPlayer = AiPlayer.from_preset(_content(), "us_default", 1)
	ai.think(w)
	return ai._first_attack


func test_ai_varies_between_seeds_and_repeats_within_one() -> void:
	var seen: Dictionary[int, bool] = {}
	var base: int = AiPlayer.from_preset(_content(), "us_default", 1).first_attack_tick
	for s: int in 8:
		var t: int = _first_attack(100 + s)
		assert_eq(t, _first_attack(100 + s), "the same seed gave a different AI")
		assert_true(absi(t - base) <= 15 * SimWorld.TICK_RATE, "first attack moved more than 15 s")
		seen[t] = true
	assert_true(seen.size() > 1, "every seed gave the AI the same first attack time")
