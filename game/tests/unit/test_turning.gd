extends TestCase
# Facing and turn rate (P1-02).


func _def(turn_rate: int) -> UnitDef:
	var d := UnitDef.new()
	d.id = "turner"
	d.max_hp = 100
	d.speed = Fx.from_int(1)
	d.turn_rate = turn_rate
	d.radius = Fx.from_int(1)
	return d


func _order(world: SimWorld, id: int, x_m: int, y_m: int) -> void:
	var c := SimCommand.make_move([id], Fx.from_int(x_m), Fx.from_int(y_m))
	c.player_id = 1
	c.seq = world.tick + 1
	c.tick = world.tick
	world.queue_command(c)


func test_turns_no_faster_than_turn_rate() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_def(64), 1, Fx.from_int(50), Fx.from_int(50), 0)
	_order(world, id, 10, 50)   # straight behind: heading 2048
	world.step()
	assert_eq(absi(Fx.angle_diff(0, world.get_entity(id).facing)), 64)


func test_reaches_heading_without_overshoot() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_def(100), 1, Fx.from_int(10), Fx.from_int(10), 0)
	_order(world, id, 10, 90)   # heading 1024 (+Y)
	for i: int in 30:
		world.step()
	assert_eq(world.get_entity(id).facing, 1024)


func test_creeps_while_turning_then_full_speed() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_def(64), 1, Fx.from_int(50), Fx.from_int(50), 0)
	_order(world, id, 10, 50)
	world.step()
	var e: SimEntity = world.get_entity(id)
	var first_step: int = Fx.length(e.x - e.prev_x, e.y - e.prev_y)
	assert_true(first_step <= Fx.from_int(1) / 4 + 1, "moved %d while facing away" % first_step)
	for i: int in 40:
		world.step()
	var later_step: int = Fx.length(e.x - e.prev_x, e.y - e.prev_y)
	assert_true(later_step >= Fx.from_int(1) - 2, "only moved %d once turned" % later_step)


func test_instant_turners_face_heading_immediately() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_def(Fx.ANGLE_FULL), 1, Fx.from_int(50), Fx.from_int(50), 0)
	_order(world, id, 50, 10)   # heading 3072 (-Y)
	world.step()
	assert_eq(world.get_entity(id).facing, 3072)


func test_still_arrives_exactly_on_target() -> void:
	var world := SimWorld.new(1, 100, 100)
	var id: int = world.spawn_unit(_def(40), 1, Fx.from_int(50), Fx.from_int(50), 0)
	_order(world, id, 20, 70)
	for i: int in 200:
		world.step()
	var e: SimEntity = world.get_entity(id)
	assert_eq([e.x, e.y], [Fx.from_int(20), Fx.from_int(70)])
	assert_false(e.mover.has_target)


func test_turn_rate_loads_from_data() -> void:
	var db := ContentDb.new()
	db.load_all()
	# 90 deg/s at 15 ticks/s = 6 deg per tick = 68.27 units, rounded up to 69.
	assert_eq(db.get_unit("us_mbt").turn_rate, 69)
	assert_eq(db.get_unit("us_rifle_squad").turn_rate, Fx.ANGLE_FULL)


func test_view_yaw_points_model_front_along_facing() -> void:
	# Sim angle 0 is +X: the model's +Z front must end up pointing along Godot +X.
	for angle: int in [0, 1024, 2048, 3072, 512]:
		var yaw: float = UnitView.yaw_from_sim_angle(float(angle))
		var front: Vector3 = Basis(Vector3.UP, yaw) * Vector3.MODEL_FRONT
		var a: float = angle * TAU / 4096.0
		var expected := Vector3(cos(a), 0.0, sin(a))
		assert_true(front.distance_to(expected) < 0.001, "angle %d -> %s" % [angle, front])
