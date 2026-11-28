extends TestCase
# EU interoperability (P3-12c): an EU unit near two other unit types of its
# own side reloads 15% faster (30% with the rank-5 unlock); a group of one or
# two types, and other factions, don't.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(faction: String = "eu") -> SimWorld:
	var w := SimWorld.new(89, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = faction if pid == 1 else "kp"
		p.rank = 5
	return w


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func test_the_rule_is_data() -> void:
	var r: SimRules = _content().rules
	assert_eq(r.interop_faction, "eu")
	assert_eq(r.interop_min_types, 3)
	assert_eq(r.interop_reload_percent, 15)
	assert_eq(r.interop_radius, Fx.from_int(25))
	assert_eq(_content().get_power(r.interop_doubler).tier, 5)


func test_three_types_together_reload_faster() -> void:
	var w := _world()
	var tank := _unit(w, "eu_mbt", 1, 100, 100)
	_unit(w, "eu_rifle_squad", 1, 110, 100)
	_run(w, SimWorld.TICK_RATE)
	assert_false(tank.interop, "two types gave the bonus")
	_unit(w, "eu_at_team", 1, 100, 110)
	_run(w, SimWorld.TICK_RATE)
	assert_true(tank.interop, "three types didn't give the bonus")
	var gun: SimWeapon = tank.weapons[0]
	assert_eq(InteropSystem.reload_ticks(w, tank, gun), (gun.reload_ticks * 85) / 100)
	CommanderPowers.apply_command(w, _choose("eu_unlock_interop"))
	assert_eq(InteropSystem.reload_ticks(w, tank, gun), (gun.reload_ticks * 70) / 100, "the unlock didn't double it")


func test_too_far_apart_or_unarmed_doesnt_count() -> void:
	var w := _world()
	var tank := _unit(w, "eu_mbt", 1, 100, 100)
	_unit(w, "eu_rifle_squad", 1, 110, 100)
	_unit(w, "eu_at_team", 1, 160, 160)   # far away
	_unit(w, "eu_logistics_truck", 1, 100, 106)   # unarmed
	_run(w, SimWorld.TICK_RATE)
	assert_false(tank.interop)


func test_other_factions_never_get_it() -> void:
	var w := _world("us")
	var tank := _unit(w, "us_mbt", 1, 100, 100)
	_unit(w, "us_rifle_squad", 1, 110, 100)
	_unit(w, "us_at_team", 1, 100, 110)
	_run(w, SimWorld.TICK_RATE)
	assert_false(tank.interop)


func test_it_fires_more_often_in_a_fight() -> void:
	assert_true(_shots(true) > _shots(false), "a mixed group didn't fire more often")


func _shots(mixed: bool) -> int:
	var w := _world()
	var tank := _unit(w, "eu_mbt", 1, 100, 100)
	if mixed:   # the squads shoot too, but only the tank's shots are counted
		_unit(w, "eu_rifle_squad", 1, 96, 104)
		_unit(w, "eu_at_team", 1, 96, 96)
	var target := _unit(w, "kp_mbt", 2, 140, 100)
	target.weapons.clear()
	target.max_hp = 1000000
	target.hp = target.max_hp
	var shots: int = 0
	for i: int in 60 * SimWorld.TICK_RATE:
		w.step()
		for ev: Dictionary in w.events:
			if ev.get("type") == "fired" and ev.get("attacker") == tank.id:
				shots += 1
	return shots


func _choose(power: String) -> SimCommand:
	var c := SimCommand.make_choose_power(power)
	c.player_id = 1
	return c


func _interop_hash() -> int:
	var w := _world()
	_unit(w, "eu_mbt", 1, 100, 100)
	_unit(w, "eu_rifle_squad", 1, 110, 100)
	_unit(w, "eu_at_team", 1, 100, 110)
	_unit(w, "kp_mbt", 2, 140, 100)
	_run(w, 30 * SimWorld.TICK_RATE)
	return w.state_hash()


func test_interop_is_deterministic() -> void:
	assert_eq(_interop_hash(), _interop_hash())
