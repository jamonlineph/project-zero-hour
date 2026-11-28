extends TestCase
# Aircraft (P3-04a): attack helicopters run out of ammo, fly home to their
# airbase, rearm and repair there; rifles, machine guns and autocannons can
# shoot at them, tank guns can't.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(61, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "us" if pid == 1 else "kp"
		p.credits = 20000
	return w


## A helicopter produced at a fresh airbase, so it knows its home.
func _heli(w: SimWorld) -> Array[SimEntity]:
	w.spawn_building(_content().get_building("us_microreactor"), 1, 4, 4, true)
	var base: SimEntity = w.get_entity(w.spawn_building(_content().get_building("us_airbase"), 1, 10, 30, true))
	var id: int = ProductionSystem.spawn_from(w, base, _content().get_unit("us_attack_heli"))
	return [w.get_entity(id), base]


func _ammo(e: SimEntity) -> int:
	var n: int = 0
	for wpn: SimWeapon in e.weapons:
		if wpn.stock_max > 0:
			n += wpn.stock
	return n


func _cmd(w: SimWorld, c: SimCommand) -> void:
	c.player_id = 1
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func test_helicopters_and_airbases_are_data() -> void:
	for f: String in ["us", "ae", "eu"]:
		var u: UnitDef = _content().get_unit(f + "_attack_heli")
		assert_true(u != null and u.flying and u.armor_class == "aircraft", "%s helicopter" % f)
		assert_true(u.rearm_ticks > 0)
		assert_true(_content().get_building(f + "_airbase").produces.has(f + "_attack_heli"))
	assert_eq(_content().get_weapon("heli_missiles").restock_ticks, 0, "helicopter missiles must not refill in the air")


func test_out_of_ammo_it_flies_home_rearms_and_repairs() -> void:
	var w := _world()
	var pair: Array[SimEntity] = _heli(w)
	var heli: SimEntity = pair[0]
	var base: SimEntity = pair[1]
	assert_eq(heli.aircraft.home_id, base.id)
	var full: int = _ammo(heli)
	assert_true(full > 0)
	# Fly out and use everything up.
	_cmd(w, SimCommand.make_move([heli.id], Fx.from_int(180), Fx.from_int(180)))
	for i: int in 200:
		w.step()
	for wpn: SimWeapon in heli.weapons:
		wpn.stock = 0
	heli.hp = heli.max_hp / 2
	w.step()
	assert_true(heli.aircraft.returning, "an empty helicopter didn't head home")
	for i: int in 30 * SimWorld.TICK_RATE:
		w.step()
	assert_true(heli.aircraft.docked, "it never parked at its airbase")
	assert_eq(_ammo(heli), full, "it didn't rearm")
	assert_false(heli.aircraft.returning)
	assert_true(heli.hp > heli.max_hp / 2, "it wasn't repaired")


func test_ammo_never_refills_in_the_air() -> void:
	var w := _world()
	var heli: SimEntity = _heli(w)[0]
	heli.aircraft.home_id = 0   # no airbase
	for wpn: SimWeapon in heli.weapons:
		wpn.stock = 0
	for i: int in 60 * SimWorld.TICK_RATE:
		w.step()
	assert_eq(_ammo(heli), 0, "ammo came back without an airbase")


func test_rifles_and_autocannons_can_shoot_aircraft_but_tank_guns_cannot() -> void:
	assert_true(DamageMatrix.can_target(_content().get_weapon("assault_rifles").targets, "aircraft"))
	assert_true(DamageMatrix.can_target(_content().get_weapon("kp_ifv_autocannon").targets, "aircraft"))
	assert_true(DamageMatrix.can_target(_content().get_weapon("sam_interceptor").targets, "aircraft"))
	assert_false(DamageMatrix.can_target(_content().get_weapon("tank_cannon_125").targets, "aircraft"))
	assert_false(DamageMatrix.can_target(_content().get_weapon("heli_missiles").targets, "aircraft"))


func _air_hash() -> int:
	var w := _world()
	var heli: SimEntity = _heli(w)[0]
	w.spawn_unit(_content().get_unit("kp_mbt"), 2, Fx.from_int(120), Fx.from_int(120))
	_cmd(w, SimCommand.make_attack_move([heli.id], Fx.from_int(120), Fx.from_int(120)))
	for i: int in 40 * SimWorld.TICK_RATE:
		w.step()
	return w.state_hash()


func test_aircraft_are_deterministic() -> void:
	assert_eq(_air_hash(), _air_hash())


func test_every_faction_builds_anti_air_and_counters_aircraft_with_it() -> void:
	for f: String in MatchConfig.FACTIONS:
		var id: String = f + "_shorad"
		var u: UnitDef = _content().get_unit(id)
		assert_true(u != null, "%s has no anti-air vehicle" % f)
		assert_true(DamageMatrix.can_target(u.weapons[0].targets, "aircraft"), "%s can't shoot aircraft" % id)
		var built: bool = false
		for bid: String in _content().buildings:
			if _content().buildings[bid].faction == f and _content().buildings[bid].produces.has(id):
				built = true
		assert_true(built, "nothing builds %s" % id)
		var ai: AiPlayer = AiPlayer.from_preset(_content(), f + "_default", 1)
		assert_true(ai.counters.has("aircraft") and ai.counters["aircraft"].has(id), "%s's AI doesn't counter aircraft" % f)
