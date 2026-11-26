extends TestCase
# Desktop controls (P1-23): control-group logic. Camera bookmarks, Space-drag
# panning, hover and cursor states are checked in smoke_main.gd.


func _world_with(ids_count: int) -> SimWorld:
	var w := SimWorld.new(3, 64, 64)
	var def := UnitDef.new()
	def.id = "dummy"
	def.max_hp = 10
	def.radius = Fx.ONE
	for i: int in ids_count:
		w.spawn_unit(def, 1, Fx.from_int(10 + i * 4), Fx.from_int(20))
	return w


func test_assign_and_members() -> void:
	var w := _world_with(3)
	var g := ControlGroups.new()
	g.assign(2, [3, 1])
	assert_eq(g.members(2, w), [1, 3] as Array[int])
	assert_true(g.has_group(2))
	assert_false(g.has_group(3))


func test_members_skip_entities_that_are_gone() -> void:
	var w := _world_with(3)
	var g := ControlGroups.new()
	g.assign(1, [1, 2, 3])
	w.get_entity(2).dead = true
	w._remove_dead()
	assert_eq(g.members(1, w), [1, 3] as Array[int])


func test_double_tap_only_for_the_same_group_in_time() -> void:
	var g := ControlGroups.new()
	assert_false(g.recall(4, 1000))
	assert_true(g.recall(4, 1000 + ControlGroups.DOUBLE_TAP_MS))
	assert_false(g.recall(5, 1100 + ControlGroups.DOUBLE_TAP_MS))
	assert_false(g.recall(5, 2000 + ControlGroups.DOUBLE_TAP_MS * 3))


func test_center_is_the_average_position() -> void:
	var w := _world_with(2)   # units at x = 10 and 14 m, y = 20 m
	var g := ControlGroups.new()
	g.assign(1, [1, 2])
	var c: Vector3 = g.center(1, w)
	assert_true(absf(c.x - 12.0) < 0.001 and absf(c.z - 20.0) < 0.001, "center %s" % c)
	assert_eq(g.center(9, w), null)


func test_number_keys_map_to_groups() -> void:
	assert_eq(ControlGroups.group_for_key(KEY_1), 1)
	assert_eq(ControlGroups.group_for_key(KEY_9), 9)
	assert_eq(ControlGroups.group_for_key(KEY_KP_3), 3)
	assert_eq(ControlGroups.group_for_key(KEY_0), 0)
	assert_eq(ControlGroups.group_for_key(KEY_A), 0)
