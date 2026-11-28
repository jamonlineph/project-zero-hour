extends TestCase
# Stealth and detection (P3-09): North Korea's infiltrators can't be seen or
# shot until a detector (sniper team, recon drone) or any unit gets close,
# or they fire; the view hides them too.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(71, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		w.get_player(pid).team = pid
	return w


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func test_the_units_are_data() -> void:
	assert_true(_content().get_unit("kp_infiltrators").stealth)
	assert_eq(_content().get_unit("kp_infiltrators").abilities[0].kind, "disable")
	assert_eq(_content().get_unit("us_sniper_team").detection, Fx.from_int(45))
	for f: String in ["us", "kp", "ae", "eu"]:
		assert_true(_content().get_unit(f + "_recon_drone").detection > 0, "%s recon drones should detect" % f)


func test_an_infiltrator_cant_be_shot_until_detected() -> void:
	var w := _world()
	var spy := _unit(w, "kp_infiltrators", 2, 120, 120)
	spy.weapons.clear()   # it holds its fire, so it stays hidden
	var squad := _unit(w, "us_rifle_squad", 1, 120, 145)   # 25 m: in rifle range and sight, beyond 6 m
	_run(w, 60)
	assert_eq(spy.hp, spy.max_hp, "a hidden infiltrator was shot")
	assert_false(w.is_detected(1, spy))
	var sniper := _unit(w, "us_sniper_team", 1, 120, 160)   # 40 m: inside its 45 m detection
	sniper.weapons.clear()
	_run(w, 60)
	assert_true(w.is_detected(1, spy), "the sniper team didn't detect it")
	assert_true(spy.hp < spy.max_hp, "the detected infiltrator wasn't shot")
	assert_false(w.is_detected(1, squad) == false, "ordinary units are always detected")


func test_getting_close_or_firing_gives_it_away() -> void:
	var w := _world()
	var spy := _unit(w, "kp_infiltrators", 2, 120, 120)
	var target := _unit(w, "us_logistics_truck", 1, 120, 140)
	target.weapons.clear()
	_run(w, 2)
	assert_false(w.is_detected(1, spy))
	_run(w, 45)   # it opens fire on the truck
	assert_true(spy.revealed_until > w.tick, "firing didn't reveal it")
	assert_true(w.is_detected(1, spy))
	var w2 := _world()
	var spy2 := _unit(w2, "kp_infiltrators", 2, 120, 120)
	spy2.weapons.clear()
	var near := _unit(w2, "us_engineer", 1, 120, 124)
	near.weapons.clear()
	_run(w2, 2)
	assert_true(w2.is_detected(1, spy2), "a unit 4 m away didn't see it")


func test_the_view_hides_an_undetected_infiltrator() -> void:
	var w := _world()
	var spy := _unit(w, "kp_infiltrators", 2, 120, 120)
	spy.weapons.clear()
	_unit(w, "us_rifle_squad", 1, 120, 145)
	_run(w, 20)
	var view := GameView.new()
	view.world = w
	view.local_player_id = 1
	assert_false(view.is_shown(spy), "the view showed a hidden infiltrator")
	_unit(w, "us_sniper_team", 1, 120, 160)
	_run(w, 2)
	assert_true(view.is_shown(spy))
	view.free()
