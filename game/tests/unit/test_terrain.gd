extends TestCase
# Terrain and map folders (P1-30): loading height files, cliffs and water in
# the sim, and the view's terrain mesh matching the sim's heights.

const SCRATCH_DIR: String = "user://test_maps/scratch"


func _db() -> ContentDb:
	var db := ContentDb.new()
	assert_true(db.load_all(), ", ".join(db.errors))
	return db


func test_sandbox_is_a_folder_with_heights() -> void:
	var m: MapDef = _db().get_map("sandbox")
	assert_eq(m.heights_cm.size(), m.cells_x() * m.cells_y())
	for v: int in m.heights_cm:
		assert_true(v >= 0 and v <= 800, "height %d cm out of range" % v)


func test_sim_heights_match_the_file() -> void:
	var m: MapDef = _db().get_map("sandbox")
	var map: SimMap = m.make_sim_map()
	for i: int in [0, 100, 2000, m.heights_cm.size() - 1]:
		var cx: int = i % m.cells_x()
		var cy: int = i / m.cells_x()
		assert_eq(map.height_at(cx, cy), (m.heights_cm[i] * Fx.ONE) / 100)


func test_sandbox_hills_block_nothing_new() -> void:
	# The sandbox's hills are gentle and its raised rocks sit inside obstacles,
	# so passability must equal the obstacles alone (golden replays rely on it).
	var m: MapDef = _db().get_map("sandbox")
	var with_terrain: int = m.make_sim_map().blocked_count()
	var flat := MapDef.new()
	flat.width_m = m.width_m
	flat.height_m = m.height_m
	flat.obstacles_m = m.obstacles_m
	assert_eq(with_terrain, flat.make_sim_map().blocked_count())


func test_cliff_tops_are_blocked_not_the_ground_below() -> void:
	# 4 x 4 cells: the right half is a 3 m plateau.
	var m := MapDef.new()
	m.width_m = 8
	m.height_m = 8
	m.max_step_cm = 100
	for y: int in 4:
		for x: int in 4:
			m.heights_cm.append(300 if x >= 2 else 0)
	var map: SimMap = m.make_sim_map()
	for y: int in 4:
		assert_true(map.is_passable(1, y), "the ground below the cliff must stay open")
		assert_false(map.is_passable(2, y), "the cliff edge must be blocked")
		assert_true(map.is_passable(3, y), "the plateau behind the edge stays open")


func test_gentle_slopes_stay_open_and_water_blocks() -> void:
	var m := MapDef.new()
	m.width_m = 8
	m.height_m = 2
	m.max_step_cm = 100
	m.water_level_cm = 50
	m.heights_cm = PackedInt32Array([0, 60, 120, 180])   # 60 cm steps
	var map: SimMap = m.make_sim_map()
	assert_false(map.is_passable(0, 0), "below the water level")
	for x: int in range(1, 4):
		assert_true(map.is_passable(x, 0), "a 60 cm step is not a cliff (cell %d)" % x)


func test_height_file_of_the_wrong_size_is_an_error() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH_DIR))
	var json := {"id": "scratch", "name": "Scratch", "width_m": 16, "height_m": 16,
		"height": "height.r16", "height_scale_cm": 500}
	var f := FileAccess.open(SCRATCH_DIR + "/map.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(json))
	f.close()
	var h := FileAccess.open(SCRATCH_DIR + "/height.r16", FileAccess.WRITE)
	h.store_buffer(PackedByteArray([1, 2, 3]))   # 8 x 8 cells need 128 bytes
	h.close()
	var db := ContentDb.new()
	db._load_map(SCRATCH_DIR + "/map.json")
	assert_true(db.errors.size() == 1 and db.errors[0].contains("expected 128"), str(db.errors))


func test_height_file_scales_exactly() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH_DIR))
	var json := {"id": "scratch", "name": "Scratch", "width_m": 16, "height_m": 16,
		"height": "height.r16", "height_scale_cm": 1000}
	var f := FileAccess.open(SCRATCH_DIR + "/map.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(json))
	f.close()
	var bytes := PackedByteArray()
	bytes.resize(128)   # 8 x 8 cells, all 0 except the second
	bytes.fill(0)
	bytes.encode_u16(2, 65535)
	bytes.encode_u16(4, 32768)
	var h := FileAccess.open(SCRATCH_DIR + "/height.r16", FileAccess.WRITE)
	h.store_buffer(bytes)
	h.close()
	var db := ContentDb.new()
	db._load_map(SCRATCH_DIR + "/map.json")
	assert_true(db.errors.is_empty(), str(db.errors))
	var heights: PackedInt32Array = db.maps["scratch"].heights_cm
	assert_eq(heights.size(), 64)
	assert_eq(heights[0], 0)
	assert_eq(heights[1], 1000)
	assert_eq(heights[2], 500)   # 32768 * 1000 / 65535, rounded down


func test_terrain_mesh_matches_sim_heights() -> void:
	var db := _db()
	var m: MapDef = db.get_map("sandbox")
	var world := SimWorld.from_map(1, m)
	var fog := FogOfWar.new()
	fog.setup(world, 1)
	var terrain := TerrainView.new()
	terrain.build(m, fog)
	# generate_normals() may reorder vertices, so find each cell center by position.
	var verts: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(10, 20), Vector2i(31, 31), Vector2i(63, 63)]:
		var cx: float = cell.x * 2.0 + 1.0
		var cz: float = cell.y * 2.0 + 1.0
		var found: bool = false
		for v: Vector3 in verts:
			if absf(v.x - cx) < 0.001 and absf(v.z - cz) < 0.001:
				var sim_y: float = Fx.to_float(world.map.height_at(cell.x, cell.y))
				assert_true(absf(v.y - sim_y) < 0.011, "cell %s: view %.3f m, sim %.3f m" % [cell, v.y, sim_y])
				found = true
				break
		assert_true(found, "no terrain vertex at the center of cell %s" % cell)
	terrain.free()
	fog.free()
