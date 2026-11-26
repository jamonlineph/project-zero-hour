extends TestCase
# Decoys (P2-08).

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(17, 200, 200)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.content = _content()
	return w


func _spawn(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func test_decoy_data() -> void:
	var d: UnitDef = _content().get_unit("kp_decoy_tank")
	assert_eq(d.decoy_of, "kp_mbt")
	assert_eq(d.max_hp, 1)
	assert_eq(d.model_path, _content().get_unit("kp_mbt").model_path, "a decoy must look like the real tank")


func test_enemies_shoot_unrevealed_decoys_and_one_hit_kills() -> void:
	var w := _world()
	var decoy: SimEntity = _spawn(w, "kp_decoy_tank", 2, 100, 100)
	var tank: SimEntity = _spawn(w, "us_mbt", 1, 60, 100)   # 40 m away: in range, not close enough to tell
	tank.vision = Fx.from_int(60)
	_run(w, 60)
	assert_eq(w.get_entity(decoy.id), null, "the enemy tank never fired at the decoy")


func test_close_enemies_see_through_decoys_and_ignore_them() -> void:
	var w := _world()
	var decoy: SimEntity = _spawn(w, "kp_decoy_tank", 2, 100, 100)
	var squad: SimEntity = _spawn(w, "us_rifle_squad", 1, 90, 100)   # 10 m: inside the reveal range
	squad.weapons.clear()
	_run(w, 2)
	assert_true(DecoySystem.revealed_to(decoy, w.team_of(1)), "a unit 10 m away did not see through the decoy")
	var tank: SimEntity = _spawn(w, "us_mbt", 1, 60, 100)
	tank.vision = Fx.from_int(60)
	_run(w, 60)
	assert_true(w.get_entity(decoy.id) != null, "a revealed decoy was still shot at")


func test_recon_drone_flyover_reveals_but_far_drones_do_not() -> void:
	var w := _world()
	var decoy: SimEntity = _spawn(w, "kp_decoy_tank", 2, 100, 100)
	var drone: SimEntity = _spawn(w, "us_recon_drone", 1, 100, 140)
	drone.drone.endurance = 100000
	_run(w, 3)
	assert_false(DecoySystem.revealed_to(decoy, w.team_of(1)), "a drone 40 m away saw through the decoy")
	var c := SimCommand.make_move([drone.id], Fx.from_int(100), Fx.from_int(100))
	c.player_id = 1
	c.seq = 1
	c.tick = w.tick
	w.queue_command(c)
	_run(w, 60)
	assert_true(DecoySystem.revealed_to(decoy, w.team_of(1)), "a recon drone flying over did not reveal the decoy")


func test_reveal_is_per_team_and_own_side_is_unaffected() -> void:
	var w := _world()
	w.player_team[3] = 3
	var decoy: SimEntity = _spawn(w, "kp_decoy_tank", 2, 100, 100)
	_spawn(w, "us_rifle_squad", 1, 92, 100).weapons.clear()
	_spawn(w, "kp_infantry_squad", 2, 95, 100).weapons.clear()   # its own side, close by
	_run(w, 2)
	assert_true(DecoySystem.revealed_to(decoy, w.team_of(1)))
	assert_false(DecoySystem.revealed_to(decoy, 3), "revealed to a team that never came close")


func _decoy_hash() -> int:
	var w := _world()
	for i: int in 4:
		_spawn(w, "kp_decoy_tank", 2, 120, 80 + i * 12)
	_spawn(w, "kp_mbt", 2, 125, 140).weapons.clear()
	for i: int in 3:
		_spawn(w, "us_mbt", 1, 70, 90 + i * 10).vision = Fx.from_int(60)
	_run(w, 300)
	return w.state_hash()


func test_decoys_are_deterministic() -> void:
	assert_eq(_decoy_hash(), _decoy_hash())
