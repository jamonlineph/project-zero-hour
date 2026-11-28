extends TestCase
# Jets (P3-04b): fighters for America, the UAE and the EU, North Korea's
# strike jet from its hardened airstrip. Jets can't loiter: when their order
# is done they fly home, even with ammo left; parked, they hold their fire.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(97, 240, 240)
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


func _cmd(w: SimWorld, c: SimCommand, player: int = 1) -> void:
	c.player_id = player
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


## A jet built at a fresh airfield, so it knows its home. Player 1 flies
## America's stealth fighter, player 2 North Korea's strike jet.
func _jet(w: SimWorld, player: int) -> Array[SimEntity]:
	var plant: String = "us_microreactor" if player == 1 else "kp_power_plant"
	var field: String = "us_airbase" if player == 1 else "kp_airstrip"
	var jet: String = "us_stealth_fighter" if player == 1 else "kp_strike_jet"
	var x: int = 6 if player == 1 else 90
	w.spawn_building(_content().get_building(plant), player, x, 4, true)
	var base: SimEntity = w.get_entity(w.spawn_building(_content().get_building(field), player, x, 20, true))
	var id: int = ProductionSystem.spawn_from(w, base, _content().get_unit(jet))
	return [w.get_entity(id), base]


func test_jets_and_airfields_are_data() -> void:
	for pair: Array in [["us_airbase", "us_stealth_fighter"], ["ae_airbase", "ae_fighter"],
			["eu_airbase", "eu_fighter"], ["kp_airstrip", "kp_strike_jet"]]:
		var u: UnitDef = _content().get_unit(pair[1])
		assert_true(u != null and u.jet and u.flying and u.armor_class == "aircraft", pair[1])
		assert_true(_content().get_building(pair[0]).produces.has(pair[1]), "%s doesn't build %s" % pair)
	assert_true(AiPlayer.from_preset(_content(), "kp_default", 2).build_order.has("kp_airstrip"))


func test_a_jet_flies_home_when_its_order_is_done() -> void:
	var w := _world()
	var pair: Array[SimEntity] = _jet(w, 1)
	var jet: SimEntity = pair[0]
	var base: SimEntity = pair[1]
	_cmd(w, SimCommand.make_move([jet.id] as Array[int], Fx.from_int(150), Fx.from_int(150)))
	var far: bool = false
	for i: int in 30 * SimWorld.TICK_RATE:
		w.step()
		if Fx.length(jet.x - Fx.from_int(150), jet.y - Fx.from_int(150)) < Fx.from_int(6):
			far = true
	assert_true(far, "the jet never reached its destination")
	assert_true(jet.aircraft.docked, "the jet loitered instead of flying home")
	assert_true(Fx.length(jet.x - base.x, jet.y - base.y) < Fx.from_int(30))


func test_a_helicopter_still_hovers_where_it_was_sent() -> void:
	var w := _world()
	w.spawn_building(_content().get_building("us_microreactor"), 1, 6, 4, true)
	var base: SimEntity = w.get_entity(w.spawn_building(_content().get_building("us_airbase"), 1, 6, 20, true))
	var heli: SimEntity = w.get_entity(ProductionSystem.spawn_from(w, base, _content().get_unit("us_attack_heli")))
	_cmd(w, SimCommand.make_move([heli.id] as Array[int], Fx.from_int(150), Fx.from_int(150)))
	_run(w, 30 * SimWorld.TICK_RATE)
	assert_true(Fx.length(heli.x - Fx.from_int(150), heli.y - Fx.from_int(150)) < Fx.from_int(8), "a helicopter flew home")


func test_a_strike_jet_attacks_then_rearms_at_its_airstrip() -> void:
	var w := _world()
	var pair: Array[SimEntity] = _jet(w, 2)
	var jet: SimEntity = pair[0]
	var tank: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit("us_mbt"), 1, Fx.from_int(200), Fx.from_int(160)))
	tank.weapons.clear()
	tank.max_hp = 1000000
	tank.hp = tank.max_hp
	_run(w, 2)
	_cmd(w, SimCommand.make_attack_move([jet.id] as Array[int], Fx.from_int(200), Fx.from_int(160)), 2)
	var hit: bool = false
	var emptied: bool = false
	for i: int in 60 * SimWorld.TICK_RATE:
		w.step()
		hit = hit or tank.hp < tank.max_hp
		emptied = emptied or AirSystem.out_of_ammo(jet)
	assert_true(hit, "the strike jet never hit the tank")
	assert_true(emptied, "the strike jet never used up its rockets")
	assert_true(jet.aircraft.docked, "it didn't come home")
	_run(w, 30 * SimWorld.TICK_RATE)
	assert_false(AirSystem.out_of_ammo(jet), "it didn't rearm")


func test_parked_jets_hold_their_fire() -> void:
	var w := _world()
	var jet: SimEntity = _jet(w, 1)[0]
	_run(w, 2 * SimWorld.TICK_RATE)
	assert_true(jet.aircraft.docked)
	var enemy: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit("kp_ifv"), 2, jet.x + Fx.from_int(20), jet.y))
	enemy.weapons.clear()
	_run(w, 3 * SimWorld.TICK_RATE)
	assert_eq(enemy.hp, enemy.max_hp, "a parked jet fired")


func test_fighters_shoot_down_helicopters() -> void:
	var w := _world()
	var jet: SimEntity = _jet(w, 1)[0]
	# Close enough for the fighter to see it from the airbase.
	var heli: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit("us_attack_heli"), 2, Fx.from_int(70), Fx.from_int(50)))
	heli.weapons.clear()
	_run(w, 2)
	_cmd(w, SimCommand.make_attack([jet.id] as Array[int], heli.id))
	_run(w, 30 * SimWorld.TICK_RATE)
	assert_true(heli.dead or heli.hp < heli.max_hp, "the fighter didn't hit the helicopter")


func _jet_hash() -> int:
	var w := _world()
	var jet: SimEntity = _jet(w, 2)[0]
	w.spawn_unit(_content().get_unit("us_mbt"), 1, Fx.from_int(200), Fx.from_int(160))
	_cmd(w, SimCommand.make_attack_move([jet.id] as Array[int], Fx.from_int(200), Fx.from_int(160)), 2)
	_run(w, 40 * SimWorld.TICK_RATE)
	return w.state_hash()


func test_jets_are_deterministic() -> void:
	assert_eq(_jet_hash(), _jet_hash())
