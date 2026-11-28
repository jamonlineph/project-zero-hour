extends TestCase
# The UAE's swarm-drone truck (P3-02c): launches a group of drones at an enemy
# it can see in range, then waits out its cooldown; the drones fight as
# ordinary flying units and crash when their endurance runs out.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(37, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		w.get_player(pid).team = pid
	return w


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func _drones(w: SimWorld, player: int) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for id: int in w.entity_ids:
		var e: SimEntity = w.entities[id]
		if e.def_id == "ae_swarm_drone" and e.player_id == player and not e.dead:
			out.append(e)
	return out


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func test_the_truck_is_data() -> void:
	var u: UnitDef = _content().get_unit("ae_swarm_launcher")
	assert_eq(u.launch_unit, "ae_swarm_drone")
	assert_eq(u.launch_count, 5)
	assert_eq(u.launch_range, Fx.from_int(90))
	assert_eq(u.launch_cooldown_ticks, 40 * SimWorld.TICK_RATE)
	assert_true(_content().get_building("ae_drone_complex").produces.has("ae_swarm_launcher"))
	var d: UnitDef = _content().get_unit("ae_swarm_drone")
	assert_true(d.flying, "swarm drones must fly")
	assert_eq(d.cost, 0, "swarm drones are only launched, never built")


func test_it_launches_at_a_visible_enemy_then_waits_for_its_cooldown() -> void:
	var w := _world()
	var truck := _unit(w, "ae_swarm_launcher", 1, 60, 120)
	var tank := _unit(w, "kp_mbt", 2, 100, 120)
	tank.weapons.clear()
	_run(w, SimVision.UPDATE_INTERVAL + 1)
	var drones: Array[SimEntity] = _drones(w, 1)
	assert_eq(drones.size(), 5, "the truck didn't launch its swarm")
	for d: SimEntity in drones:
		assert_eq(d.order, SimEntity.Order.ATTACK_MOVE)
		assert_eq(d.order_x, tank.x)
	assert_true(truck.launcher.ready_tick > w.tick and truck.launcher.ready_tick <= w.tick + 40 * SimWorld.TICK_RATE,
		"the cooldown didn't start")
	var hp: int = tank.hp
	_run(w, SimWorld.TICK_RATE * 8)
	assert_true(tank.hp < hp, "the swarm never hit the tank")
	# Still cooling down: no second swarm yet, however many drones are left.
	var launched: int = 0
	for id: int in w.entity_ids:
		if w.entities[id].def_id == "ae_swarm_drone":
			launched += 1
	assert_true(launched <= 5, "a second swarm came before the cooldown")


func test_no_launch_without_a_visible_ground_target_in_range() -> void:
	var w := _world()
	_unit(w, "ae_swarm_launcher", 1, 40, 120)
	_unit(w, "kp_mbt", 2, 200, 120)          # out of range and out of sight
	_unit(w, "kp_recon_drone", 2, 60, 125)   # in range, but flying
	_run(w, SimWorld.TICK_RATE * 3)
	assert_eq(_drones(w, 1).size(), 0, "the truck launched at nothing it should")


func test_swarm_drones_crash_when_their_endurance_ends() -> void:
	var w := _world()
	_unit(w, "ae_swarm_launcher", 1, 60, 120)
	var target := _unit(w, "kp_logistics_truck", 2, 100, 120)
	target.max_hp = 1000000
	target.hp = target.max_hp
	_run(w, SimVision.UPDATE_INTERVAL + 1)
	assert_eq(_drones(w, 1).size(), 5)
	_run(w, 31 * SimWorld.TICK_RATE)
	# Only a fresh swarm (the truck relaunches after 40 s) may be in the air.
	assert_eq(_drones(w, 1).size(), 0, "swarm drones outlived their 30 s endurance")


func _swarm_hash() -> int:
	var w := _world()
	_unit(w, "ae_swarm_launcher", 1, 60, 120)
	_unit(w, "kp_infantry_squad", 2, 95, 118)
	_unit(w, "kp_infantry_squad", 2, 98, 124)
	_run(w, SimWorld.TICK_RATE * 12)
	return w.state_hash()


func test_swarms_are_deterministic() -> void:
	assert_eq(_swarm_hash(), _swarm_hash())
