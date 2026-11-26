extends TestCase
# Commander power tree (P2-09): points, tiers, cooldowns and every power.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(rank: int = 1) -> SimWorld:
	var w := SimWorld.new(23, 256, 256)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.content = _content()
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "us" if pid == 1 else "kp"
		p.rank = rank
		p.credits = 10000
	return w


func _cmd(w: SimWorld, c: SimCommand, player: int) -> void:
	c.player_id = player
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _choose(w: SimWorld, power: String, player: int) -> void:
	_cmd(w, SimCommand.make_choose_power(power), player)
	w.step()


func _use(w: SimWorld, power: String, player: int, x_m: int = 128, y_m: int = 128) -> void:
	_cmd(w, SimCommand.make_use_power(power, Fx.from_int(x_m), Fx.from_int(y_m)), player)
	w.step()


func _count(w: SimWorld, pred: Callable) -> int:
	var n: int = 0
	for id: int in w.entity_ids:
		if pred.call(w.entities[id]):
			n += 1
	return n


func test_trees_load_for_both_slice_factions() -> void:
	var us: Array[PowerDef] = _content().powers_for("us")
	var kp: Array[PowerDef] = _content().powers_for("kp")
	assert_eq(us.size(), 5)
	assert_eq(kp.size(), 6)
	assert_eq(us[0].tier, 1, "trees are sorted by tier")


func test_points_and_tiers() -> void:
	var w := _world(1)
	_choose(w, "us_unlock_recon_team", 1)   # tier 3 at rank 1
	assert_false(w.get_player(1).powers.has("us_unlock_recon_team"), "chose a rank-3 power at rank 1")
	_choose(w, "us_satellite_pass", 1)
	_choose(w, "us_precision_rockets", 1)   # no points left
	assert_eq(Array(w.get_player(1).powers), ["us_satellite_pass"])
	w.get_player(1).rank = 3
	_choose(w, "us_precision_rockets", 1)
	_choose(w, "us_cyberattack", 1)
	assert_eq(w.get_player(1).powers.size(), 3)
	assert_eq(CommanderPowers.points(w.get_player(1)), 0)
	_choose(w, "kp_drone_sweep", 1)          # other faction
	assert_false(w.get_player(1).powers.has("kp_drone_sweep"))


func test_unchosen_powers_and_cooldowns() -> void:
	var w := _world(1)
	_use(w, "us_satellite_pass", 1)
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.sensor), 0, "used a power that wasn't chosen")
	_choose(w, "us_satellite_pass", 1)
	_use(w, "us_satellite_pass", 1)
	_use(w, "us_satellite_pass", 1)   # on cooldown
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.sensor), 1)


func test_satellite_pass_reveals_spots_and_expires() -> void:
	var w := _world(1)
	var tank: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit("kp_mbt"), 2, Fx.from_int(200), Fx.from_int(128)))
	_choose(w, "us_satellite_pass", 1)
	_use(w, "us_satellite_pass", 1, 200, 128)
	for i: int in 4:
		w.step()
	assert_true(w.can_see(1, tank.x, tank.y), "the satellite pass revealed nothing")
	assert_true(w.is_spotted(1, tank.x, tank.y), "a satellite pass should count as a spotter")
	var sensor_hp_ok: bool = true
	for i: int in 30:
		w.step()
	for id: int in w.entity_ids:
		if w.entities[id].sensor and w.entities[id].hp != CommanderPowers.SENSOR_HP:
			sensor_hp_ok = false
	assert_true(sensor_hp_ok, "the enemy tank shot at the satellite sensor")
	for i: int in _content().get_power("us_satellite_pass").duration_ticks:
		w.step()
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.sensor), 0, "the pass did not end")


func test_precision_rockets_need_a_spotted_point() -> void:
	var w := _world(3)
	_choose(w, "us_precision_rockets", 1)
	_choose(w, "us_satellite_pass", 1)
	_use(w, "us_precision_rockets", 1, 200, 128)
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.strike != null), 0, "fired at an unspotted point")
	assert_eq(int(w.get_player(1).power_ready.get("us_precision_rockets", 0)), 0, "a failed use started the cooldown")
	_use(w, "us_satellite_pass", 1, 200, 128)
	w.step()
	_use(w, "us_precision_rockets", 1, 200, 128)
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.strike != null), 3)


func test_drone_sweep_crosses_the_map() -> void:
	var w := _world(1)
	var tank: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit("us_mbt"), 1, Fx.from_int(128), Fx.from_int(60)))
	tank.weapons.clear()
	_choose(w, "kp_drone_sweep", 2)
	_use(w, "kp_drone_sweep", 2, 128, 60)
	var seen: bool = false
	for i: int in 300:
		w.step()
		if w.can_see(2, tank.x, tank.y):
			seen = true
	assert_true(seen, "the sweep never revealed the tank under its path")
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.sensor), 0, "the sweep drone did not leave")


func test_reserve_call_up_spawns_squads_at_the_hq() -> void:
	var w := _world(1)
	w.spawn_building(_content().get_building("kp_command_hq"), 2, 100, 50, true)
	_choose(w, "kp_reserve_callup", 2)
	_use(w, "kp_reserve_callup", 2)
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.def_id == "kp_infantry_squad"), 3)


func test_rocket_barrage_launches_24_rockets() -> void:
	var w := _world(3)
	_choose(w, "kp_rocket_barrage", 2)
	_use(w, "kp_rocket_barrage", 2, 60, 128)
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.strike != null and e.player_id == 2), 24)


func test_gps_jamming_jams_an_area_for_a_while() -> void:
	var w := _world(3)
	_choose(w, "kp_gps_jamming", 2)
	_use(w, "kp_gps_jamming", 2, 100, 100)
	w.step()
	assert_true(w.jam_level(1, Fx.from_int(100), Fx.from_int(110)) > 0, "no jamming at the point")
	assert_eq(w.jam_level(2, Fx.from_int(100), Fx.from_int(110)), 0, "it jammed its own side")
	for i: int in _content().get_power("kp_gps_jamming").duration_ticks + 2:
		w.step()
	assert_eq(w.jam_level(1, Fx.from_int(100), Fx.from_int(110)), 0, "the jamming never ended")


func test_wingmen_patrol_then_leave_and_cannot_be_selected() -> void:
	var w := _world(3)
	_choose(w, "us_wingman_patrol", 1)
	_use(w, "us_wingman_patrol", 1, 150, 128)
	var wing: Array[SimEntity] = []
	for id: int in w.entity_ids:
		if w.entities[id].def_id == "us_wingman_drone":
			wing.append(w.entities[id])
	assert_eq(wing.size(), 2)
	assert_eq(wing[0].order, SimEntity.Order.PATROL)
	assert_true(wing[0].ttl > 0)
	for i: int in _content().get_power("us_wingman_patrol").duration_ticks + 2:
		w.step()
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.def_id == "us_wingman_drone"), 0)


func test_cyberattack_blinds_enemies() -> void:
	var w := _world(3)
	_choose(w, "us_cyberattack", 1)
	_use(w, "us_cyberattack", 1)
	assert_true(w.get_player(2).blinded_until > w.tick)
	assert_eq(w.get_player(1).blinded_until, 0)


func test_unlocks_gate_production() -> void:
	var w := _world(3)
	w.spawn_building(_content().get_building("kp_power_plant"), 2, 10, 10, true)
	var b: SimEntity = w.get_entity(w.spawn_building(_content().get_building("kp_barracks"), 2, 30, 30, true))
	_cmd(w, SimCommand.make_produce(b.id, "kp_spotter_officer"), 2)
	w.step()
	assert_true(b.building.queue.is_empty(), "built a unit that needs an unlock")
	_choose(w, "kp_unlock_spotter_officer", 2)
	_cmd(w, SimCommand.make_produce(b.id, "kp_spotter_officer"), 2)
	w.step()
	assert_eq(b.building.queue.size(), 1)


func test_decoy_deployment_needs_rank_5() -> void:
	var w := _world(3)
	_choose(w, "kp_decoy_deployment", 2)
	assert_false(w.get_player(2).powers.has("kp_decoy_deployment"))
	w.get_player(2).rank = 5
	_choose(w, "kp_decoy_deployment", 2)
	_use(w, "kp_decoy_deployment", 2, 120, 120)
	assert_eq(_count(w, func(e: SimEntity) -> bool: return e.decoy_of != ""), 6)


func test_commands_round_trip() -> void:
	var c := SimCommand.from_dict(SimCommand.make_use_power("kp_rocket_barrage", Fx.from_int(5), Fx.from_int(6)).to_dict())
	assert_eq(c.type, SimCommand.Type.USE_POWER)
	assert_eq(c.def_id, "kp_rocket_barrage")
	assert_eq(c.target_y, Fx.from_int(6))


func _power_hash() -> int:
	var w := _world(3)
	w.spawn_building(_content().get_building("kp_command_hq"), 2, 100, 50, true)
	for p: String in ["us_satellite_pass", "us_precision_rockets", "us_wingman_patrol"]:
		_choose(w, p, 1)
	for p: String in ["kp_rocket_barrage", "kp_gps_jamming", "kp_reserve_callup"]:
		_choose(w, p, 2)
	_use(w, "us_satellite_pass", 1, 200, 100)
	_use(w, "us_precision_rockets", 1, 200, 100)
	_use(w, "us_wingman_patrol", 1, 180, 120)
	_use(w, "kp_rocket_barrage", 2, 60, 120)
	_use(w, "kp_gps_jamming", 2, 70, 120)
	_use(w, "kp_reserve_callup", 2)
	for i: int in 600:
		w.step()
	return w.state_hash()


func test_powers_are_deterministic() -> void:
	assert_eq(_power_hash(), _power_hash())
