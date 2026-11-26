extends TestCase
# Interceptable strikes (P2-07): missiles and strike jets as entities, and
# air defense with a limited interceptor stock.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(seed_value: int = 31) -> SimWorld:
	var w := SimWorld.new(seed_value, 256, 256)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.content = _content()
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		w.get_player(pid).team = pid
	return w


func _spawn(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func _launch(w: SimWorld, strike_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	var id: int = StrikeSystem.launch(w, _content().get_strike(strike_id), player, Fx.from_int(x_m), Fx.from_int(y_m))
	return w.get_entity(id)


func _run_until_gone(w: SimWorld, id: int, max_ticks: int) -> int:
	for i: int in max_ticks:
		w.step()
		if w.get_entity(id) == null:
			return i
	return -1


func test_strikes_load() -> void:
	assert_eq(_content().get_strike("guided_rocket").kind, "missile")
	assert_eq(_content().get_strike("strike_jet").kind, "aircraft")
	assert_eq(_content().get_strike("strike_jet").count, 4)
	assert_eq(_content().get_weapon("sam_interceptor").stock, 4)


func test_missile_flies_in_and_hits_its_target() -> void:
	var w := _world()
	var tank: SimEntity = _spawn(w, "kp_mbt", 2, 200, 128)
	tank.weapons.clear()
	var m: SimEntity = _launch(w, "guided_rocket", 1, 200, 128)
	assert_eq(m.armor_class, "aircraft")
	assert_eq(m.x, 0, "player 1 has no base, so the strike comes from the west edge")
	assert_true(_run_until_gone(w, m.id, 600) >= 0, "the missile never arrived")
	assert_true(tank.hp < tank.max_hp, "the missile did no damage")


func test_strike_jet_bombs_and_leaves() -> void:
	var w := _world()
	var squads: Array[SimEntity] = []
	for i: int in 4:
		var s: SimEntity = _spawn(w, "kp_infantry_squad", 2, 180 + (i % 2) * 6, 120 + (i / 2) * 6)
		s.weapons.clear()
		squads.append(s)
	var jet: SimEntity = _launch(w, "strike_jet", 1, 183, 123)
	var delivered_at: int = -1
	for i: int in 1200:
		w.step()
		if delivered_at < 0 and jet.strike.delivered:
			delivered_at = i
		if w.get_entity(jet.id) == null:
			break
	assert_true(delivered_at >= 0, "the jet never dropped its bombs")
	assert_eq(w.get_entity(jet.id), null, "the jet did not leave the map")
	var hurt: int = 0
	for s: SimEntity in squads:
		if w.get_entity(s.id) == null or s.hp < s.max_hp:
			hurt += 1
	assert_true(hurt >= 2, "only %d squads were hit by four bombs" % hurt)


func test_air_defense_shoots_strikes_down_and_spends_stock() -> void:
	var w := _world()
	var sam: SimEntity = w.get_entity(w.spawn_building(_content().get_building("kp_sam_site"), 2, 70, 60, true))
	w.spawn_building(_content().get_building("kp_power_plant"), 2, 90, 90, true)
	var target: SimEntity = _spawn(w, "kp_infantry_squad", 2, 150, 128)
	target.weapons.clear()
	var m: SimEntity = _launch(w, "guided_rocket", 1, 150, 128)
	var killed: bool = false
	for i: int in 600:
		w.step()
		for ev: Dictionary in w.events:
			if ev["type"] == "died" and ev["id"] == m.id:
				killed = true
		if w.get_entity(m.id) == null:
			break
	assert_true(killed, "air defense did not shoot the missile down")
	assert_eq(target.hp, target.max_hp, "the intercepted missile still did damage")
	assert_true(sam.weapons[0].stock < sam.weapons[0].stock_max, "no interceptor was spent")


func test_interceptor_stock_runs_out_and_restocks() -> void:
	var w := _world()
	var sam: SimEntity = w.get_entity(w.spawn_building(_content().get_building("kp_sam_site"), 2, 70, 60, true))
	w.spawn_building(_content().get_building("kp_power_plant"), 2, 90, 90, true)
	var weapon: SimWeapon = sam.weapons[0]
	for i: int in 8:
		_launch(w, "heavy_rocket", 1, 150, 110 + i * 4)
	var fired: int = 0
	for i: int in 200:
		w.step()
		for ev: Dictionary in w.events:
			if ev["type"] == "fired" and ev["attacker"] == sam.id:
				fired += 1
	assert_true(fired <= weapon.stock_max + 1, "fired %d interceptors from a stock of %d" % [fired, weapon.stock_max])
	var before: int = weapon.stock
	for i: int in weapon.restock_ticks + 2:
		w.step()
	assert_true(weapon.stock > before or weapon.stock == weapon.stock_max, "the stock never refilled")


func test_strikes_do_not_count_for_victory() -> void:
	var w := _world()
	w.victory_rule = "units"
	var p2: SimEntity = _spawn(w, "kp_infantry_squad", 2, 200, 200)
	p2.weapons.clear()
	_launch(w, "strike_jet", 1, 10, 10)   # player 1 owns nothing but a jet in flight
	for i: int in SimWorld.TICK_RATE + 2:
		w.step()
	assert_true(w.get_player(1).defeated, "a strike in flight kept its player alive")


func _strike_hash() -> int:
	var w := _world(44)
	w.spawn_building(_content().get_building("kp_sam_site"), 2, 70, 60, true)
	w.spawn_building(_content().get_building("kp_power_plant"), 2, 90, 90, true)
	for i: int in 6:
		_spawn(w, "kp_infantry_squad", 2, 160 + i * 3, 128).weapons.clear()
		_launch(w, "heavy_rocket", 1, 165, 128)
	_launch(w, "strike_jet", 1, 170, 120)
	for i: int in 900:
		w.step()
	return w.state_hash()


func test_strikes_are_deterministic() -> void:
	assert_eq(_strike_hash(), _strike_hash())
