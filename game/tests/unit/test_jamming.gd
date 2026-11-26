extends TestCase
# Jamming fields and spoofing (P2-03).

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(11, 200, 200)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.content = _content()
	return w


func _spawn(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func _command(w: SimWorld, c: SimCommand, player: int) -> void:
	c.player_id = player
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


## A drone carrying a weapon (no slice drone is armed yet).
func _armed_drone(w: SimWorld, player: int, x_m: int, y_m: int, fiber: bool = false) -> SimEntity:
	var def := UnitDef.new()
	def.id = "test_armed_drone"
	def.armor_class = "drone"
	def.flying = true
	def.fiber_optic = fiber
	def.max_hp = 60
	def.radius = Fx.ONE
	def.speed = Fx.from_ratio(1400, 100 * SimWorld.TICK_RATE)
	def.vision = Fx.from_int(60)
	def.endurance_ticks = 100000
	def.weapons = [_content().get_weapon("bunker_machine_gun")]
	return w.get_entity(w.spawn_unit(def, player, Fx.from_int(x_m), Fx.from_int(y_m)))


func test_ew_vehicle_has_a_jamming_field() -> void:
	var u: UnitDef = _content().get_unit("kp_ew_vehicle")
	assert_eq(u.jam_radius, Fx.from_int(40))
	assert_true(u.spoof_radius > 0 and u.spoof_cooldown_ticks > 0)


func test_enemy_drone_in_field_loses_control() -> void:
	var w := _world()
	_spawn(w, "kp_ew_vehicle", 2, 100, 100)
	var drone: SimEntity = _spawn(w, "us_recon_drone", 1, 80, 100)   # 20 m away: inside
	drone.drone.endurance = 100000
	_command(w, SimCommand.make_move([drone.id], Fx.from_int(180), Fx.from_int(100)), 1)
	_run(w, 3)
	assert_true(drone.drone.jammed, "the drone inside the field is not jammed")
	var start := Vector2i(drone.x, drone.y)
	_run(w, 60)
	var moved: float = Fx.to_float(Fx.length(drone.x - start.x, drone.y - start.y))
	assert_true(moved < 10.0, "a jammed drone flew %.1f m toward its order" % moved)


func test_own_field_and_far_drones_are_not_jammed() -> void:
	var w := _world()
	_spawn(w, "kp_ew_vehicle", 2, 100, 100)
	var own: SimEntity = _spawn(w, "kp_recon_drone", 2, 90, 100)
	var far: SimEntity = _spawn(w, "us_recon_drone", 1, 20, 20)
	_run(w, 3)
	assert_false(own.drone.jammed, "a field jammed its own side's drone")
	assert_false(far.drone.jammed, "a drone far outside the field was jammed")


func test_jammed_drone_crashes_when_endurance_runs_out() -> void:
	var w := _world()
	_spawn(w, "kp_ew_vehicle", 2, 100, 100)
	var drone: SimEntity = _spawn(w, "us_recon_drone", 1, 95, 100)
	drone.drone.endurance = 40
	_run(w, 50)
	assert_eq(w.get_entity(drone.id), null)


func test_jammed_drones_cannot_fire_and_fiber_optic_is_immune() -> void:
	var w := _world()
	var ew: SimEntity = _spawn(w, "kp_ew_vehicle", 2, 100, 100)
	var target: SimEntity = _spawn(w, "kp_infantry_squad", 2, 110, 100)
	_armed_drone(w, 1, 105, 100)
	_run(w, 30)
	assert_true(target.hp == target.max_hp and ew.hp == ew.max_hp, "a jammed drone fired")
	var w2 := _world()
	var ew2: SimEntity = _spawn(w2, "kp_ew_vehicle", 2, 100, 100)
	var target2: SimEntity = _spawn(w2, "kp_infantry_squad", 2, 110, 100)
	var fiber: SimEntity = _armed_drone(w2, 1, 105, 100, true)
	_run(w2, 30)
	assert_false(fiber.drone.jammed)
	var hurt: bool = w2.get_entity(ew2.id) == null or ew2.hp < ew2.max_hp \
			or w2.get_entity(target2.id) == null or target2.hp < target2.max_hp
	assert_true(hurt, "a fiber-optic drone was stopped by jamming")


func test_guided_missiles_lose_lock_about_half_the_time() -> void:
	var w := _world()
	_spawn(w, "kp_ew_vehicle", 2, 150, 100)
	var tank: SimEntity = _spawn(w, "kp_mbt", 2, 140, 100)
	tank.max_hp = 1000000
	tank.hp = 1000000
	tank.weapons.clear()   # a harmless target: only the missile team shoots
	var team: SimEntity = _spawn(w, "us_at_team", 1, 110, 100)
	team.vision = Fx.from_int(60)
	var fired: int = 0
	var lost: int = 0
	for t: int in 900:
		w.step()
		for ev: Dictionary in w.events:
			if ev["type"] == "fired" and ev["attacker"] == team.id:
				fired += 1
			elif ev["type"] == "jammed_shot":
				lost += 1
	assert_true(fired >= 8, "only %d shots fired" % fired)
	assert_true(lost * 4 >= fired and lost * 4 <= fired * 3, "%d of %d guided shots lost lock (expected about half)" % [lost, fired])


func test_unguided_weapons_ignore_jamming() -> void:
	var w := _world()
	_spawn(w, "kp_ew_vehicle", 2, 150, 100)
	var target: SimEntity = _spawn(w, "kp_mbt", 2, 140, 100)
	target.max_hp = 1000000
	target.hp = 1000000
	var tank: SimEntity = _spawn(w, "us_mbt", 1, 100, 100)
	tank.vision = Fx.from_int(60)
	var lost: int = 0
	for t: int in 300:
		w.step()
		for ev: Dictionary in w.events:
			if ev["type"] == "jammed_shot":
				lost += 1
	assert_eq(lost, 0)
	assert_true(target.hp < target.max_hp)


func test_spoofing_sends_enemy_drones_astray_and_has_a_cooldown() -> void:
	var w := _world()
	var ew: SimEntity = _spawn(w, "kp_ew_vehicle", 2, 40, 100)
	var a: SimEntity = _spawn(w, "us_recon_drone", 1, 150, 100)   # 110 m away: outside the field
	var b: SimEntity = _spawn(w, "us_recon_drone", 1, 152, 104)
	var fiber: SimEntity = _armed_drone(w, 1, 150, 96, true)
	_run(w, 2)
	_command(w, SimCommand.make_spoof([ew.id], Fx.from_int(150), Fx.from_int(100)), 2)   # 110 m away: out of range (70 m)
	_run(w, 2)
	assert_eq(a.drone.spoofed_ticks, 0, "spoofed from beyond its range")
	ew.x = Fx.from_int(90)   # move the jammer closer (test shortcut)
	_command(w, SimCommand.make_spoof([ew.id], Fx.from_int(150), Fx.from_int(100)), 2)
	_run(w, 2)
	assert_true(a.drone.spoofed_ticks > 0 and b.drone.spoofed_ticks > 0, "drones in the spoof radius were not spoofed")
	assert_eq(fiber.drone.spoofed_ticks, 0, "a fiber-optic drone was spoofed")
	var ready: int = ew.jammer.spoof_ready_tick
	assert_true(ready > w.tick)
	_command(w, SimCommand.make_spoof([ew.id], Fx.from_int(150), Fx.from_int(100)), 2)
	_run(w, 2)
	assert_eq(ew.jammer.spoof_ready_tick, ready, "spoofed again during the cooldown")
	_run(w, JammingSystem.SPOOF_TICKS + 2)
	assert_eq(a.drone.spoofed_ticks, 0)


func test_spoofed_armed_drone_can_attack_its_own_side() -> void:
	var w := _world()
	var ew: SimEntity = _spawn(w, "kp_ew_vehicle", 2, 60, 100)
	var drone: SimEntity = _armed_drone(w, 1, 120, 100)
	var friend: SimEntity = _spawn(w, "us_rifle_squad", 1, 125, 100)
	_run(w, 2)
	_command(w, SimCommand.make_spoof([ew.id], Fx.from_int(120), Fx.from_int(100)), 2)
	_run(w, 2)
	assert_eq(drone.weapons[0].target_id, friend.id, "the only target nearby was the friendly squad")
	_run(w, 20)
	assert_true(friend.hp < friend.max_hp, "the spoofed drone did not fire on its own side")


func _jam_hash() -> int:
	var w := _world()
	var ew: SimEntity = _spawn(w, "kp_ew_vehicle", 2, 100, 100)
	for i: int in 5:
		var d: SimEntity = _spawn(w, "us_recon_drone", 1, 70 + i * 6, 100)
		d.drone.endurance = 100000
	for i: int in 3:
		_spawn(w, "us_at_team", 1, 60, 80 + i * 10).vision = Fx.from_int(60)
	_spawn(w, "kp_mbt", 2, 95, 90)
	_run(w, 50)
	_command(w, SimCommand.make_spoof([ew.id], Fx.from_int(85), Fx.from_int(100)), 2)
	_run(w, 300)
	return w.state_hash()


func test_jamming_and_spoofing_are_deterministic() -> void:
	assert_eq(_jam_hash(), _jam_hash())


func test_spoof_command_round_trips() -> void:
	var c := SimCommand.make_spoof([4], Fx.from_int(10), Fx.from_int(20))
	var back := SimCommand.from_dict(c.to_dict())
	assert_eq(back.type, SimCommand.Type.SPOOF)
	assert_eq(back.target_x, Fx.from_int(10))
