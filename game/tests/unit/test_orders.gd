extends TestCase
# Guard and patrol orders (P1-24b).

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
	return w


func _spawn(world: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> int:
	return world.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m))


func _command(world: SimWorld, c: SimCommand, player: int = 1) -> void:
	c.player_id = player
	_seq += 1
	c.seq = _seq
	c.tick = world.tick
	world.queue_command(c)


func _dist_m(world: SimWorld, a: int, x_m: int, y_m: int) -> float:
	var e: SimEntity = world.get_entity(a)
	return Fx.to_float(Fx.length(e.x - Fx.from_int(x_m), e.y - Fx.from_int(y_m)))


func test_patrol_goes_back_and_forth() -> void:
	var w := _world()
	var tank: int = _spawn(w, "us_mbt", 1, 20, 100)
	_command(w, SimCommand.make_patrol([tank], Fx.from_int(80), Fx.from_int(100)))
	var reached_far: bool = false
	var came_back: bool = false
	for i: int in 900:
		w.step()
		if _dist_m(w, tank, 80, 100) < 2.0:
			reached_far = true
		if reached_far and _dist_m(w, tank, 20, 100) < 2.0:
			came_back = true
			break
	assert_true(reached_far, "the patrol never reached its far end")
	assert_true(came_back, "the patrol never came back to its start")
	assert_eq(w.get_entity(tank).order, SimEntity.Order.PATROL)


func test_patrol_stops_to_fight() -> void:
	var w := _world()
	var tank: int = _spawn(w, "us_mbt", 1, 20, 100)
	var enemy: int = _spawn(w, "kp_infantry_squad", 2, 60, 105)
	_command(w, SimCommand.make_patrol([tank], Fx.from_int(120), Fx.from_int(100)))
	for i: int in 300:
		w.step()
	var e: SimEntity = w.get_entity(enemy)
	assert_true(e == null or e.hp < e.max_hp, "the patrol drove past an enemy without firing")


func test_guard_follows_its_ward() -> void:
	var w := _world()
	var ward: int = _spawn(w, "us_logistics_truck", 1, 50, 50)
	var guard: int = _spawn(w, "us_mbt", 1, 40, 50)
	_command(w, SimCommand.make_guard([guard], ward))
	w.step()
	_command(w, SimCommand.make_move([ward], Fx.from_int(140), Fx.from_int(120)))
	for i: int in 600:
		w.step()
	var g: SimEntity = w.get_entity(guard)
	var t: SimEntity = w.get_entity(ward)
	var gap: float = Fx.to_float(Fx.length(g.x - t.x, g.y - t.y))
	assert_true(gap < 14.0, "the guard is %.1f m from its ward" % gap)
	assert_eq(g.order, SimEntity.Order.GUARD)


func test_guard_attacks_enemies_near_the_ward_only() -> void:
	var w := _world()
	var ward: int = _spawn(w, "us_logistics_truck", 1, 60, 60)
	var guard: int = _spawn(w, "us_mbt", 1, 55, 60)
	var near: int = _spawn(w, "kp_infantry_squad", 2, 75, 70)    # ~18 m from the ward
	var far: int = _spawn(w, "kp_infantry_squad", 2, 60, 150)    # 90 m away
	_command(w, SimCommand.make_guard([guard], ward))
	for i: int in 300:
		w.step()
	var n: SimEntity = w.get_entity(near)
	assert_true(n == null or n.hp < n.max_hp, "the guard ignored an enemy next to its ward")
	var f: SimEntity = w.get_entity(far)
	assert_true(f != null and f.hp == f.max_hp, "the guard chased an enemy far from its ward")
	assert_true(_dist_m(w, guard, 60, 60) < 30.0, "the guard wandered away from its ward")


func test_guard_ends_when_the_ward_dies() -> void:
	var w := _world()
	var ward: int = _spawn(w, "us_logistics_truck", 1, 60, 60)
	var guard: int = _spawn(w, "us_mbt", 1, 55, 60)
	_command(w, SimCommand.make_guard([guard], ward))
	w.step()
	w.apply_damage(w.get_entity(ward), 1000000, "anti_tank", 0)
	for i: int in 3:
		w.step()
	assert_eq(w.get_entity(guard).order, SimEntity.Order.IDLE)


func test_cannot_guard_an_enemy() -> void:
	var w := _world()
	var guard: int = _spawn(w, "us_mbt", 1, 55, 60)
	var enemy: int = _spawn(w, "kp_mbt", 2, 70, 60)
	_command(w, SimCommand.make_guard([guard], enemy))
	w.step()
	assert_true(w.get_entity(guard).order != SimEntity.Order.GUARD)


func test_commands_round_trip_through_dict() -> void:
	var g := SimCommand.make_guard([3, 1], 7)
	var back := SimCommand.from_dict(g.to_dict())
	assert_eq(back.type, SimCommand.Type.GUARD)
	assert_eq(back.target_entity, 7)
	var p := SimCommand.make_patrol([2], Fx.from_int(10), Fx.from_int(20))
	var back2 := SimCommand.from_dict(p.to_dict())
	assert_eq(back2.type, SimCommand.Type.PATROL)
	assert_eq(back2.target_y, Fx.from_int(20))


func _guard_and_patrol_hash() -> int:
	var w := _world()
	var a: int = _spawn(w, "us_mbt", 1, 20, 100)
	var b: int = _spawn(w, "us_mbt", 1, 24, 104)
	var ward: int = _spawn(w, "us_logistics_truck", 1, 30, 30)
	var g: int = _spawn(w, "us_ifv", 1, 26, 30)
	_spawn(w, "kp_infantry_squad", 2, 70, 100)
	_spawn(w, "kp_infantry_squad", 2, 40, 45)
	_command(w, SimCommand.make_patrol([a, b], Fx.from_int(110), Fx.from_int(100)))
	_command(w, SimCommand.make_guard([g], ward), 1)
	for i: int in 400:
		w.step()
	return w.state_hash()


func test_guard_and_patrol_are_deterministic() -> void:
	assert_eq(_guard_and_patrol_hash(), _guard_and_patrol_hash())
