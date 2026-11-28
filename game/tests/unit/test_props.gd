extends TestCase
# Scattered scenery (P3-23d): every skirmish map gets props of its biome,
# the same ones every time, and none in a base, on water or on a building.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _props(map_id: String) -> PropsView:
	var p := PropsView.new()
	p.build(_content().get_map(map_id), null)
	return p


func test_each_biome_gets_its_props() -> void:
	for pair: Array in [["riverside", "bush"], ["desert_crossroads", "stone"], ["frostwood", "drift"]]:
		var p := _props(pair[0])
		assert_true(p.counts.get(pair[1], 0) > 10, "%s has only %d %s props" % [pair[0], p.counts.get(pair[1], 0), pair[1]])
		p.free()
	var oasis := _props("desert_crossroads")
	assert_true(oasis.counts.get("palm", 0) > 0, "no palms by the oasis")
	oasis.free()


func test_the_same_map_always_looks_the_same() -> void:
	var a := _props("riverside")
	var b := _props("riverside")
	assert_eq(a.counts, b.counts)
	var ma: MultiMesh = (a.get_child(0) as MultiMeshInstance3D).multimesh
	var mb: MultiMesh = (b.get_child(0) as MultiMeshInstance3D).multimesh
	assert_eq(ma.get_instance_transform(3), mb.get_instance_transform(3))
	a.free()
	b.free()


func test_props_keep_clear_of_bases_and_buildings() -> void:
	for id: String in ["riverside", "old_town", "three_bridges"]:
		var def: MapDef = _content().get_map(id)
		var p := _props(id)
		for mi: Node in p.get_children():
			var mm: MultiMesh = (mi as MultiMeshInstance3D).multimesh
			for i: int in mm.instance_count:
				var at: Vector3 = mm.get_instance_transform(i).origin
				for s: Vector2i in def.start_positions:
					assert_true(Vector2(at.x, at.z).distance_to(Vector2(s)) >= PropsView.BASE_CLEAR_M - 0.01,
						"%s: a prop in a base at %s" % [id, at])
				for r: PackedInt32Array in def.civilian_buildings_m:
					assert_false(at.x > r[0] and at.x < r[0] + r[2] and at.z > r[1] and at.z < r[1] + r[3],
						"%s: a prop inside a house at %s" % [id, at])
		p.free()
