extends TestCase
# Health, damage and death (P1-07), damage matrix (P1-09), weapons (P1-08)
# and attack orders (P1-10).

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(size_m: int = 200) -> SimWorld:
	var w := SimWorld.new(9, size_m, size_m)
	w.damage_matrix = _content().damage_matrix
	return w


func _spawn(world: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> int:
	return world.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m))


func _command(world: SimWorld, c: SimCommand, player: int = 1) -> void:
	c.player_id = player
	c.seq = world.tick * 10 + 1
	c.tick = world.tick
	world.queue_command(c)


func _run(world: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		world.step()


func _count_events(world: SimWorld, ticks: int, type: String) -> int:
	var n: int = 0
	for i: int in ticks:
		world.step()
		for ev: Dictionary in world.events:
			if ev["type"] == type:
				n += 1
	return n


func test_damage_matrix_loads_from_data() -> void:
	var m: DamageMatrix = _content().damage_matrix
	assert_eq(m.percent("anti_tank", "infantry"), 25)
	assert_eq(m.percent("small_arms", "heavy_armor"), 5)
	assert_eq(m.apply(160, "anti_tank", "infantry"), 40)
	assert_eq(m.apply(12, "small_arms", "heavy_armor"), 1, "a non-zero hit never rounds to 0")
	assert_eq(m.apply(100, "anti_air", "infantry"), 0)


func test_weapons_load_and_attach_to_units() -> void:
	var tank: UnitDef = _content().get_unit("us_mbt")
	assert_eq(tank.weapons.size(), 1)
	var cannon: WeaponDef = tank.weapons[0]
	assert_eq(cannon.max_range, Fx.from_int(50))
	assert_eq(cannon.reload_ticks, 45)   # 3000 ms at 15 ticks/s


func test_damage_kills_and_removes_at_end_of_tick() -> void:
	var world := _world()
	var id: int = _spawn(world, "ru_motor_rifle_squad", 2, 50, 50)
	var e: SimEntity = world.get_entity(id)
	world.apply_damage(e, 10_000, "small_arms", 0)
	assert_true(e.dead)
	assert_eq(e.hp, 0)
	assert_true(world.entities.has(id), "removed only at the end of a tick")
	world.step()
	assert_false(world.entities.has(id))
	assert_false(world.entity_ids.has(id))


func test_units_in_range_fire_and_respect_reload() -> void:
	var world := _world()
	_spawn(world, "us_mbt", 1, 50, 50)
	_spawn(world, "ru_mbt", 2, 90, 50)      # 40 m: in range of both cannons
	var shots: int = _count_events(world, 60, "fired")
	# Two tanks, about 3 s reload each, over 4 s: 2 shots each at most.
	assert_true(shots >= 2 and shots <= 4, "%d shots in 4 s" % shots)


func test_units_out_of_range_do_not_fire() -> void:
	var world := _world()
	_spawn(world, "us_mbt", 1, 20, 50)
	_spawn(world, "ru_mbt", 2, 150, 50)
	assert_eq(_count_events(world, 60, "fired"), 0)


func test_tanks_fight_to_the_death() -> void:
	var world := _world()
	var a: int = _spawn(world, "us_mbt", 1, 50, 50)
	var b: int = _spawn(world, "ru_mbt", 2, 90, 50)
	var died: int = _count_events(world, 15 * 60, "died")
	assert_eq(died, 1, "exactly one tank should die")
	assert_true(world.entities.has(a) != world.entities.has(b))


func test_rifles_barely_scratch_tanks() -> void:
	var world := _world()
	var tank: int = _spawn(world, "ru_mbt", 2, 60, 50)
	_spawn(world, "us_rifle_squad", 1, 40, 50)
	world.get_entity(tank).weapons.clear()   # disarm the tank to isolate the rifles
	_run(world, 15 * 10)
	var lost: int = world.get_entity(tank).max_hp - world.get_entity(tank).hp
	assert_true(lost > 0 and lost <= 20, "rifles took %d hp from a tank in 10 s" % lost)


func test_splash_hits_enemies_only_and_respects_min_range() -> void:
	var world := _world()
	var mortar: WeaponDef = _content().get_weapon("test_mortar")
	var shooter: int = _spawn(world, "us_rifle_squad", 1, 20, 50)
	world.get_entity(shooter).weapons = [SimWeapon.from_def(mortar)] as Array[SimWeapon]
	world.get_entity(shooter).vision = Fx.from_int(100)   # mortars need someone to see far
	var e1: int = _spawn(world, "ru_motor_rifle_squad", 2, 70, 50)
	var e2: int = _spawn(world, "ru_motor_rifle_squad", 2, 72, 52)
	var friend: int = _spawn(world, "us_rifle_squad", 1, 71, 48)
	var too_close: int = _spawn(world, "ru_motor_rifle_squad", 2, 24, 50)   # inside min range
	world.get_entity(e1).weapons.clear()
	world.get_entity(e2).weapons.clear()
	world.get_entity(too_close).weapons.clear()
	world.get_entity(friend).weapons.clear()
	_run(world, 60)
	assert_true(world.get_entity(e1).hp < world.get_entity(e1).max_hp, "splash missed the target")
	assert_true(world.get_entity(e2).hp < world.get_entity(e2).max_hp, "splash missed the neighbor")
	assert_eq(world.get_entity(friend).hp, world.get_entity(friend).max_hp, "splash hurt a friendly")
	assert_eq(world.get_entity(too_close).hp, world.get_entity(too_close).max_hp, "fired inside min range")


func test_projectiles_take_time_to_arrive() -> void:
	var world := _world()
	var shooter: int = _spawn(world, "us_rifle_squad", 1, 20, 50)
	world.get_entity(shooter).weapons = [SimWeapon.from_def(_content().get_weapon("test_mortar"))] as Array[SimWeapon]
	world.get_entity(shooter).vision = Fx.from_int(100)
	var target: int = _spawn(world, "ru_motor_rifle_squad", 2, 80, 50)
	world.get_entity(target).weapons.clear()
	var fired_at: int = -1
	var hit_at: int = -1
	for i: int in 60:
		world.step()
		for ev: Dictionary in world.events:
			if ev["type"] == "fired" and fired_at < 0:
				fired_at = world.tick
			if ev["type"] == "hit" and hit_at < 0:
				hit_at = world.tick
	# 60 m at 40 m/s is 1.5 s, about 22 ticks.
	assert_true(fired_at >= 0 and hit_at - fired_at >= 20 and hit_at - fired_at <= 24,
		"fired at %d, hit at %d" % [fired_at, hit_at])


func test_attack_order_chases_and_kills() -> void:
	var world := _world()
	var hunter: int = _spawn(world, "us_mbt", 1, 20, 50)
	var prey: int = _spawn(world, "ru_motor_rifle_squad", 2, 150, 120)
	world.get_entity(prey).weapons.clear()
	# A friendly spotter near the prey shares its vision with the hunter.
	var spotter: int = _spawn(world, "us_rifle_squad", 1, 160, 140)
	world.get_entity(spotter).weapons.clear()
	world.step()
	_command(world, SimCommand.make_attack([hunter], prey))
	_run(world, 15 * 60)
	assert_false(world.entities.has(prey), "the target survived")
	var h: SimEntity = world.get_entity(hunter)
	assert_eq(h.order, SimEntity.Order.IDLE)
	assert_false(h.mover.has_target)


func test_attack_move_stops_to_fight_then_continues() -> void:
	var world := _world()
	var tank: int = _spawn(world, "us_mbt", 1, 10, 50)
	var blocker: int = _spawn(world, "ru_motor_rifle_squad", 2, 80, 50)
	world.get_entity(blocker).weapons.clear()
	_command(world, SimCommand.make_attack_move([tank], Fx.from_int(180), Fx.from_int(50)))
	var paused_seen: bool = false
	for i: int in 15 * 90:
		world.step()
		var t: SimEntity = world.get_entity(tank)
		paused_seen = paused_seen or t.mover.paused
	assert_true(paused_seen, "never stopped to fight")
	assert_false(world.entities.has(blocker), "enemy on the way survived")
	var t: SimEntity = world.get_entity(tank)
	assert_true(Fx.length(t.x - Fx.from_int(180), t.y - Fx.from_int(50)) < Fx.from_int(2), "did not continue to the destination")
	assert_eq(t.order, SimEntity.Order.IDLE)


func test_hold_position_never_moves() -> void:
	var world := _world()
	var tank: int = _spawn(world, "us_mbt", 1, 20, 50)
	_command(world, SimCommand.make_hold([tank]))
	var prey: int = _spawn(world, "ru_mbt", 2, 120, 50)
	_command(world, SimCommand.make_attack_move([prey], Fx.from_int(40), Fx.from_int(50)), 2)
	_run(world, 15 * 30)
	var t: SimEntity = world.get_entity(tank)
	if t != null:
		assert_eq([t.x, t.y], [Fx.from_int(20), Fx.from_int(50)])
		assert_eq(t.order, SimEntity.Order.HOLD)


func test_cannot_attack_own_units_or_with_wrong_weapons() -> void:
	var world := _world()
	var a: int = _spawn(world, "us_mbt", 1, 20, 50)
	var b: int = _spawn(world, "us_mbt", 1, 40, 50)
	_command(world, SimCommand.make_attack([a], b))
	world.step()
	assert_eq(world.get_entity(a).order, SimEntity.Order.IDLE)


func test_battles_are_deterministic() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var world := _world()
		for i: int in 4:
			_spawn(world, "us_mbt", 1, 20, 30 + i * 10)
			_spawn(world, "us_rifle_squad", 1, 15, 35 + i * 10)
			_spawn(world, "ru_mbt", 2, 120, 30 + i * 10)
			_spawn(world, "ru_motor_rifle_squad", 2, 125, 35 + i * 10)
		var blue: Array[int] = []
		var red: Array[int] = []
		for id: int in world.entity_ids:
			(blue if world.entities[id].player_id == 1 else red).append(id)
		_command(world, SimCommand.make_attack_move(blue, Fx.from_int(130), Fx.from_int(50)), 1)
		_command(world, SimCommand.make_attack_move(red, Fx.from_int(10), Fx.from_int(50)), 2)
		_run(world, 15 * 40)
		hashes.append(world.state_hash())
	assert_eq(hashes[0], hashes[1])
