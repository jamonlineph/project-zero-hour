extends TestCase
# Crushing (P3-07): tanks driving into enemy infantry hurt them; parked
# tanks, side brushes, friends, vehicles and garrisons are safe.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(41, 200, 200)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		w.get_player(pid).team = pid
	return w


## A unit that won't shoot, so only crushing can hurt anything.
func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	var e: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))
	e.weapons.clear()
	return e


func _move(w: SimWorld, e: SimEntity, x_m: int, y_m: int) -> void:
	var c := SimCommand.make_move([e.id], Fx.from_int(x_m), Fx.from_int(y_m))
	c.player_id = e.player_id
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func test_main_battle_tanks_are_crushers() -> void:
	assert_true(_content().get_unit("us_mbt").crusher)
	assert_true(_content().get_unit("kp_mbt").crusher)
	assert_false(_content().get_unit("us_rifle_squad").crusher)
	assert_false(_content().get_unit("kp_decoy_tank").crusher, "a decoy shouldn't hurt anyone")
	assert_eq(_content().damage_matrix.percent("crush", "infantry"), 100)
	assert_eq(_content().damage_matrix.percent("crush", "light_vehicle"), 0)


func test_a_tank_driving_into_infantry_crushes_it() -> void:
	var w := _world()
	var tank := _unit(w, "us_mbt", 1, 40, 100)
	var squad := _unit(w, "kp_infantry_squad", 2, 60, 100)
	_move(w, tank, 150, 100)
	_run(w, 15 * 8)
	assert_true(squad.dead, "a squad in a tank's path survived (%d / %d hp)" % [squad.hp, squad.max_hp])
	assert_eq(tank.hp, tank.max_hp)


func test_parked_tanks_side_brushes_and_friends_are_safe() -> void:
	var w := _world()
	# A parked tank with an enemy squad walking right past it.
	var parked := _unit(w, "kp_mbt", 2, 100, 40)
	var walker := _unit(w, "us_rifle_squad", 1, 80, 42)
	_move(w, walker, 140, 42)
	# A tank driving past a squad standing beside its path.
	var passing := _unit(w, "us_mbt", 1, 40, 150)
	var beside := _unit(w, "kp_infantry_squad", 2, 70, 155)
	_move(w, passing, 120, 150)
	# A tank driving into its own side's squad.
	var tank := _unit(w, "us_mbt", 1, 40, 100)
	var friend := _unit(w, "us_rifle_squad", 1, 60, 100)
	_move(w, tank, 150, 100)
	_run(w, 15 * 8)
	assert_eq(walker.hp, walker.max_hp, "a parked tank crushed a squad walking past")
	assert_eq(beside.hp, beside.max_hp, "a squad was crushed by a tank brushing past its side")
	assert_eq(friend.hp, friend.max_hp, "a tank crushed its own side's squad")
	assert_eq(parked.hp, parked.max_hp)


func test_vehicles_and_garrisons_are_not_crushed() -> void:
	var w := _world()
	var tank := _unit(w, "us_mbt", 1, 40, 100)
	var truck := _unit(w, "kp_logistics_truck", 2, 60, 100)
	_move(w, tank, 150, 100)
	var house: SimEntity = w.get_entity(w.spawn_structure(_content().get_building("civilian_house"), 100, 150, 10, 8))
	var inside := _unit(w, "kp_infantry_squad", 2, 100, 170)
	var c := SimCommand.make_garrison([inside.id], house.id)
	c.player_id = 2
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)
	_run(w, 15 * 8)
	assert_eq(truck.hp, truck.max_hp, "a tank crushed a truck")
	assert_eq(inside.inside_id, house.id)
	var tank2 := _unit(w, "us_mbt", 1, 100, 120)
	_move(w, tank2, 100, 190)
	_run(w, 15 * 8)
	assert_eq(inside.hp, inside.max_hp, "a squad inside a house was crushed")


func _crush_hash() -> int:
	var w := _world()
	var tank := _unit(w, "us_mbt", 1, 40, 100)
	for i: int in 4:
		_unit(w, "kp_infantry_squad", 2, 56 + i * 3, 98 + i * 2)
	_move(w, tank, 150, 100)
	_run(w, 15 * 6)
	return w.state_hash()


func test_crushing_is_deterministic() -> void:
	assert_eq(_crush_hash(), _crush_hash())
