extends TestCase
# Active protection and cage armor (P2-06).

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(seed_value: int = 21) -> SimWorld:
	var w := SimWorld.new(seed_value, 200, 200)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.content = _content()
	return w


func _spawn(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


## A guided anti-tank missile heading for `t` from 60 m away.
func _missile(w: SimWorld, t: SimEntity, attacker_id: int = 0, player: int = 2) -> SimProjectile:
	var p := SimProjectile.new()
	p.id = w.next_projectile_id()
	p.player_id = player
	p.attacker_id = attacker_id
	p.target_id = t.id
	p.guided = true
	p.x = t.x - Fx.from_int(60)
	p.y = t.y
	p.dest_x = t.x
	p.dest_y = t.y
	p.speed = Fx.from_int(4)
	p.damage = 150
	p.damage_type = "anti_tank"
	p.targets = PackedStringArray(["ground"])
	w.projectiles.append(p)
	return p


func test_data_gives_tanks_their_protection() -> void:
	assert_eq(_content().get_unit("us_mbt").aps_charges, 2)
	assert_eq(_content().get_unit("kp_mbt").cage_hits, 2)
	assert_true(_content().get_weapon("kp_loitering_munition").drone_attack)


func test_aps_intercepts_most_missiles_and_spends_charges() -> void:
	var intercepted: int = 0
	var tries: int = 0
	for s: int in 40:
		var w := _world(100 + s)
		var tank: SimEntity = _spawn(w, "us_mbt", 1, 100, 100)
		_missile(w, tank)
		for i: int in 30:
			w.step()
			for ev: Dictionary in w.events:
				if ev["type"] == "intercepted":
					intercepted += 1
		tries += 1
		assert_eq(tank.aps_charges, 1, "one charge per missile")
	assert_true(intercepted >= 30 and intercepted <= 40, "%d of %d missiles intercepted (expected about 90%%)" % [intercepted, tries])


func test_no_charges_no_interception_and_charges_reload() -> void:
	var w := _world()
	var tank: SimEntity = _spawn(w, "us_mbt", 1, 100, 100)
	tank.aps_charges = 0
	var hp: int = tank.hp
	_missile(w, tank)
	for i: int in 30:
		w.step()
	assert_true(tank.hp < hp, "a missile was stopped with no charges left")
	for i: int in ProtectionSystem.RELOAD_TICKS:
		w.step()
	assert_eq(tank.aps_charges, 1, "a charge did not reload after 20 s")
	for i: int in ProtectionSystem.RELOAD_TICKS + 5:
		w.step()
	assert_eq(tank.aps_charges, 2)


func test_unguided_shots_are_not_intercepted() -> void:
	var w := _world()
	var tank: SimEntity = _spawn(w, "us_mbt", 1, 100, 100)
	tank.weapons.clear()
	var enemy: SimEntity = _spawn(w, "kp_mbt", 2, 70, 100)
	enemy.vision = Fx.from_int(60)
	var intercepted: int = 0
	for i: int in 150:
		w.step()
		for ev: Dictionary in w.events:
			if ev["type"] in ["intercepted", "intercept_failed"]:
				intercepted += 1
	assert_eq(intercepted, 0)
	assert_true(tank.hp < tank.max_hp, "the cannon never hit")
	assert_eq(tank.aps_charges, 2)


func test_cage_softens_the_first_drone_hits_only() -> void:
	var w := _world()
	var tank: SimEntity = _spawn(w, "kp_mbt", 2, 100, 100)
	var full: int = w.damage_matrix.apply(200, "anti_tank", "heavy_armor")
	var hp: int = tank.hp
	w.apply_damage(tank, 200, "anti_tank", 0, true)
	assert_eq(hp - tank.hp, w.damage_matrix.apply(200 * ProtectionSystem.CAGE_PERCENT / 100, "anti_tank", "heavy_armor"))
	w.apply_damage(tank, 200, "anti_tank", 0, true)
	assert_eq(tank.cage_hits, 0)
	hp = tank.hp
	w.apply_damage(tank, 200, "anti_tank", 0, true)
	assert_eq(hp - tank.hp, full, "the third drone hit was still softened")
	var t2: SimEntity = _spawn(w, "kp_mbt", 2, 120, 100)
	hp = t2.hp
	w.apply_damage(t2, 200, "anti_tank", 0, false)
	assert_eq(hp - t2.hp, full, "cage armor softened a non-drone hit")
	assert_eq(t2.cage_hits, 2)


func test_loitering_munitions_count_as_drone_hits() -> void:
	var w := _world()
	var tank: SimEntity = _spawn(w, "kp_mbt", 2, 150, 100)
	tank.weapons.clear()
	var team: SimEntity = _spawn(w, "us_at_team", 1, 50, 100)
	team.weapons[0] = SimWeapon.from_def(_content().get_weapon("kp_loitering_munition"))
	team.vision = Fx.from_int(120)
	for i: int in 300:
		w.step()
		if tank.cage_hits < 2:
			break
	assert_eq(tank.cage_hits, 1, "a loitering munition hit did not use a cage hit")


func test_ifv_kit_gives_working_protection() -> void:
	var w := _world()
	var ifv: SimEntity = _spawn(w, "us_ifv", 1, 100, 100)
	Upgrades.apply_effects(ifv, _content().get_upgrade("us_ifv_aps_kit"))
	assert_eq(ifv.aps_charges, 2)
	_missile(w, ifv)
	var checked: bool = false
	for i: int in 30:
		w.step()
		for ev: Dictionary in w.events:
			if ev["type"] in ["intercepted", "intercept_failed"]:
				checked = true
	assert_true(checked, "the kit's protection never fired")


func _protection_hash() -> int:
	var w := _world(77)
	var tank: SimEntity = _spawn(w, "us_mbt", 1, 100, 100)
	for i: int in 6:
		_missile(w, tank)
		for t: int in 40:
			w.step()
	return w.state_hash()


func test_protection_is_deterministic() -> void:
	assert_eq(_protection_hash(), _protection_hash())
