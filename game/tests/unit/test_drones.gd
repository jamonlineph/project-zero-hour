extends TestCase
# Drone flight, endurance and return to launcher (P2-01).

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(size_m: int = 200) -> SimWorld:
	var w := SimWorld.new(9, size_m, size_m)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.content = _content()
	return w


func _drone(w: SimWorld, x_m: int, y_m: int, player: int = 1) -> SimEntity:
	var id: int = w.spawn_unit(_content().get_unit("us_recon_drone"), player, Fx.from_int(x_m), Fx.from_int(y_m))
	return w.get_entity(id)


func _move(w: SimWorld, ids: Array[int], x_m: int, y_m: int) -> void:
	var c := SimCommand.make_move(ids, Fx.from_int(x_m), Fx.from_int(y_m))
	c.player_id = 1
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func test_recon_drones_have_endurance_and_fly() -> void:
	var us: UnitDef = _content().get_unit("us_recon_drone")
	var kp: UnitDef = _content().get_unit("kp_recon_drone")
	assert_eq(us.endurance_ticks, 90 * SimWorld.TICK_RATE)
	assert_eq(kp.endurance_ticks, 120 * SimWorld.TICK_RATE)
	assert_true(us.flying and kp.flying)
	assert_false(_content().get_unit("us_mbt").flying)


func test_drones_fly_straight_over_obstacles() -> void:
	var w := _world()
	w.map.add_obstacle_m(90, 0, 10, 200)   # a wall across the whole map
	var d: SimEntity = _drone(w, 50, 100)
	_move(w, [d.id], 150, 100)
	w.step()
	assert_eq(d.mover.path.size(), 1, "a flyer gets one straight leg, not a ground path")
	for i: int in 200:
		w.step()
	assert_true(Fx.to_float(Fx.length(d.x - Fx.from_int(150), d.y - Fx.from_int(100))) < 1.0, "the drone did not cross the wall")


func test_flyers_are_not_pushed_by_ground_units() -> void:
	var w := _world()
	var tank: int = w.spawn_unit(_content().get_unit("us_mbt"), 1, Fx.from_int(60), Fx.from_int(60))
	var d: SimEntity = _drone(w, 60, 60)
	var before := Vector2i(d.x, d.y)
	for i: int in 10:
		w.step()
	assert_eq(Vector2i(d.x, d.y), before)
	assert_true(w.get_entity(tank) != null)


func test_drone_without_launcher_crashes_when_empty() -> void:
	var w := _world()
	var d: SimEntity = _drone(w, 50, 50)
	d.drone.endurance = 30
	var crashed: bool = false
	for i: int in 40:
		w.step()
		for ev: Dictionary in w.events:
			if ev["type"] == "died" and ev.get("cause", "") == "crashed" and ev["id"] == d.id:
				crashed = true
	assert_true(crashed, "no crash event")
	assert_eq(w.get_entity(d.id), null)


func test_drone_returns_home_at_twenty_percent_and_recharges() -> void:
	var w := _world()
	var center: BuildingDef = _content().get_building("us_drone_center")
	var home: int = w.spawn_building(center, 1, 10, 10, true)
	assert_true(home != 0)
	var d: SimEntity = _drone(w, 30, 40)
	d.drone.home_id = home
	_move(w, [d.id], 150, 150)
	for i: int in 30:
		w.step()
	# Drain it to just above the return threshold, then let it fly on.
	d.drone.endurance = d.drone.endurance_max * DroneSystem.RETURN_PERCENT / 100 + 2
	for i: int in 5:
		w.step()
	assert_true(d.drone.returning, "the drone did not turn for home at 20%")
	for i: int in 600:
		w.step()
		if d.drone.docked:
			break
	assert_true(d.drone.docked, "the drone never docked at its launcher")
	for i: int in DroneSystem.RECHARGE_TICKS + 5:
		w.step()
	assert_eq(d.drone.endurance, d.drone.endurance_max)
	assert_false(d.drone.returning)


func test_returning_drone_ignores_other_orders() -> void:
	var w := _world()
	var home: int = w.spawn_building(_content().get_building("us_drone_center"), 1, 10, 10, true)
	var d: SimEntity = _drone(w, 100, 100)
	d.drone.home_id = home
	d.drone.endurance = d.drone.endurance_max / 10
	w.step()
	assert_true(d.drone.returning)
	_move(w, [d.id], 190, 190)
	w.step()
	var hp: Vector2i = w.approach_point(w.get_entity(home), d.x, d.y)
	assert_eq(Vector2i(d.mover.target_x, d.mover.target_y), hp, "a returning drone took a new order")


func test_produced_drones_remember_their_launcher() -> void:
	var w := _world()
	var home: int = w.spawn_building(_content().get_building("us_drone_center"), 1, 20, 20, true)
	var id: int = ProductionSystem.spawn_from(w, w.get_entity(home), _content().get_unit("us_recon_drone"))
	assert_eq(w.get_entity(id).drone.home_id, home)


func _flight_hash() -> int:
	var w := _world()
	var home: int = w.spawn_building(_content().get_building("us_drone_center"), 1, 10, 10, true)
	var ids: Array[int] = []
	for i: int in 4:
		var d: SimEntity = _drone(w, 30 + i * 3, 40)
		d.drone.home_id = home
		d.drone.endurance = 200 + i * 50
		ids.append(d.id)
	_move(w, ids, 160, 120)
	for i: int in 600:
		w.step()
	return w.state_hash()


func test_drone_flight_is_deterministic() -> void:
	assert_eq(_flight_hash(), _flight_hash())
