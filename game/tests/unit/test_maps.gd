extends TestCase
# Skirmish maps (P2-11b, P2-12): exact mirror fairness, and Riverside's river,
# bridges and town.

var _content: ContentDb


func _db() -> ContentDb:
	if _content == null:
		_content = ContentDb.new()
		assert_true(_content.load_all(), ", ".join(_content.errors))
	return _content


func _skirmish_maps() -> Array[MapDef]:
	var out: Array[MapDef] = []
	for id: String in _db().maps:
		if _db().maps[id].skirmish:
			out.append(_db().maps[id])
	return out


## Rectangle rows [x, y, w, h, ...] mirrored across the middle, as sorted strings.
func _mirrored_rects(rows: Array[PackedInt32Array], width: int, mirror: bool) -> Array[String]:
	var out: Array[String] = []
	for r: PackedInt32Array in rows:
		var m: PackedInt32Array = r.duplicate()
		if mirror:
			m[0] = width - r[0] - r[2]
		out.append(str(m))
	out.sort()
	return out


func test_riverside_and_twin_ridge_are_skirmish_maps() -> void:
	var ids: Array[String] = []
	for m: MapDef in _skirmish_maps():
		ids.append(m.id)
	assert_true(ids.has("riverside"), "Riverside is not offered for skirmish")
	assert_true(ids.has("twin_ridge"))
	assert_false(ids.has("sandbox"), "the sandbox is not mirror-fair")


func test_skirmish_maps_are_exact_mirrors() -> void:
	for m: MapDef in _skirmish_maps():
		var w: int = m.cells_x()
		for y: int in m.cells_y():
			for x: int in w / 2:
				if not m.heights_cm.is_empty():
					assert_eq(m.heights_cm[y * w + x], m.heights_cm[y * w + w - 1 - x],
						"%s: heights differ at cell (%d, %d) and its mirror" % [m.id, x, y])
		var map: SimMap = m.make_sim_map()
		for y: int in map.height_cells:
			for x: int in map.width_cells / 2:
				assert_eq(map.is_passable(x, y), map.is_passable(map.width_cells - 1 - x, y),
					"%s: passability differs at cell (%d, %d) and its mirror" % [m.id, x, y])
		assert_eq(m.start_positions.size(), 2)
		assert_eq(m.start_positions[1], Vector2i(m.width_m - m.start_positions[0].x, m.start_positions[0].y))
		assert_eq(_mirrored_rects(m.obstacles_m, m.width_m, true), _mirrored_rects(m.obstacles_m, m.width_m, false),
			"%s: obstacles are not mirrored" % m.id)
		assert_eq(_mirrored_rects(m.civilian_buildings_m, m.width_m, true),
			_mirrored_rects(m.civilian_buildings_m, m.width_m, false), "%s: houses are not mirrored" % m.id)
		var sites: Array[String] = []
		var mirrored: Array[String] = []
		for s: PackedInt32Array in m.supply_sites:
			sites.append(str([s[0], s[1], s[2]]))
			mirrored.append(str([m.width_m - s[0], s[1], s[2]]))
		sites.sort()
		mirrored.sort()
		assert_eq(mirrored, sites, "%s: supply sites are not mirrored" % m.id)


func test_riverside_river_blocks_except_at_the_bridges() -> void:
	var m: MapDef = _db().get_map("riverside")
	assert_eq(m.width_m, 256)
	assert_true(m.has_water())
	var map: SimMap = m.make_sim_map()
	var mid: int = map.width_cells / 2
	var open_rows: Array[int] = []
	for y: int in map.height_cells:
		if map.is_passable(mid, y):
			open_rows.append(y)
	assert_false(open_rows.is_empty(), "the river has no crossing")
	for y: int in open_rows:
		var on_bridge: bool = false
		for b: PackedInt32Array in m.bridges_m:
			if y * 2 >= b[1] and y * 2 < b[1] + b[3]:
				on_bridge = true
		assert_true(on_bridge, "the river can be crossed at y = %d m, away from the bridges" % (y * 2))
	# Each bridge is wide enough for vehicles (at least 10 m of open cells).
	for b: PackedInt32Array in m.bridges_m:
		var open: int = 0
		for y: int in range(b[1] / 2, (b[1] + b[3]) / 2):
			if map.is_passable(mid, y):
				open += 1
		assert_true(open * 2 >= 10, "the bridge at y %d m is only %d m wide" % [b[1], open * 2])


func test_riverside_everything_is_reachable_from_both_starts() -> void:
	var m: MapDef = _db().get_map("riverside")
	var map: SimMap = m.make_sim_map()
	var start: Vector2i = m.start_positions[0] / 2 + Vector2i(8, 0)   # in front of the HQ
	var reached := _flood(map, start)
	var east: Vector2i = m.start_positions[1] / 2 - Vector2i(8, 0)
	assert_true(reached.has(east), "the east base can't be reached from the west")
	for s: PackedInt32Array in m.supply_sites:
		# The site's own 2x2 cells are blocked; a neighbor must be reachable.
		var ok: bool = false
		for d: Vector2i in [Vector2i(-2, 0), Vector2i(1, 0), Vector2i(0, -2), Vector2i(0, 1)]:
			if reached.has(Vector2i(s[0] / 2, s[1] / 2) + d):
				ok = true
		assert_true(ok, "supply site at (%d, %d) m can't be reached" % [s[0], s[1]])


func test_houses_block_movement() -> void:
	# Houses are neutral buildings placed by MatchSetup (P3-05), not static
	# obstacles, so check a match built on the map.
	var m: MapDef = _db().get_map("riverside")
	assert_false(m.civilian_buildings_m.is_empty())
	var w: SimWorld = MatchSetup.build_from(_db(), MatchConfig.skirmish(_db(), "riverside", "us", 10000), 1)
	var houses: int = 0
	for id: int in w.entity_ids:
		if w.entities[id].def_id == "civilian_house":
			houses += 1
	assert_eq(houses, m.civilian_buildings_m.size(), "not every house was placed")
	var h: PackedInt32Array = m.civilian_buildings_m[0]
	assert_false(w.map.is_passable((h[0] + h[2] / 2) / 2, (h[1] + h[3] / 2) / 2), "a house doesn't block")


func _flood(map: SimMap, from: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {from: true}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if map.in_bounds(n.x, n.y) and not seen.has(n) and map.is_passable(n.x, n.y):
				seen[n] = true
				queue.append(n)
	return seen
