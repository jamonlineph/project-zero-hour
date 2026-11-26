extends TestCase
# Veterancy (P1-17), commander rank (P1-18) and victory (P1-19).

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(victory: String = "buildings") -> SimWorld:
	var sc: Dictionary = {
		"id": "test", "map": "sandbox", "victory": victory,
		"players": [{"id": 1, "team": 1, "faction": "us", "credits": 0},
			{"id": 2, "team": 2, "faction": "ru", "credits": 0}],
		"spawns": [],
	}
	var world: SimWorld = MatchSetup.build_from(_content(), sc, 1)
	# Remove the map's supply sites so they don't get in the way (they are
	# cleared on the first step; tests spawn their units before that).
	for id: int in world.entity_ids:
		if world.entities[id].supply != null:
			world.entities[id].dead = true
	return world


func _spawn(world: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> int:
	var u: UnitDef = _content().get_unit(def_id)
	if u != null:
		return world.spawn_unit(u, player, Fx.from_int(x_m), Fx.from_int(y_m))
	var b: BuildingDef = _content().get_building(def_id)
	var o: Vector2i = SimWorld.footprint_origin(b, Fx.from_int(x_m), Fx.from_int(y_m))
	return world.spawn_building(b, player, o.x, o.y, true)


func test_rules_load_from_data() -> void:
	var r: SimRules = _content().rules
	assert_eq(r.commander_rank_xp, PackedInt32Array([0, 2000, 5000, 10000, 18000]))
	assert_eq(r.veterancy_damage_bonus[3], 20)


func test_killing_promotes_a_unit() -> void:
	var world := _world("none")
	var tank: int = _spawn(world, "us_mbt", 1, 30, 60)
	var t: SimEntity = world.get_entity(tank)
	# Destroying 2.5x its own cost in enemy value is enough for rank 2.
	for i: int in 3:
		var enemy: int = _spawn(world, "ru_mbt", 2, 40, 60)
		world.apply_damage(world.get_entity(enemy), 100000, "anti_tank", tank)
		world.step()
	assert_eq(t.xp, 3 * 850)
	assert_eq(t.vet_rank, 2)


func test_veterans_hit_harder_and_take_less_damage() -> void:
	var world := _world("none")
	var vet: int = _spawn(world, "ru_mbt", 2, 40, 60)
	var rookie: int = _spawn(world, "ru_mbt", 2, 40, 80)
	world.get_entity(vet).vet_rank = 3
	var a: int = world.apply_damage(world.get_entity(vet), 100, "anti_tank", 0)
	var b: int = world.apply_damage(world.get_entity(rookie), 100, "anti_tank", 0)
	assert_eq(a, 80)
	assert_eq(b, 100)
	assert_eq(world.damage_bonus(world.get_entity(vet)), 20)


func test_top_veterans_repair_themselves() -> void:
	var world := _world("none")
	var vet: int = _spawn(world, "ru_mbt", 2, 40, 60)
	var e: SimEntity = world.get_entity(vet)
	e.vet_rank = 3
	e.hp = 500
	for i: int in SimWorld.TICK_RATE * 4:
		world.step()
	assert_true(e.hp > 500, "no self-repair")


func test_commander_ranks_up_from_combat() -> void:
	var world := _world("none")
	var tank: int = _spawn(world, "us_mbt", 1, 30, 60)
	for i: int in 3:
		var enemy: int = _spawn(world, "ru_mbt", 2, 40, 60)
		world.apply_damage(world.get_entity(enemy), 100000, "anti_tank", tank)
	assert_eq(world.get_player(1).xp, 2550)
	assert_eq(world.get_player(1).rank, 2)
	var hq: int = _spawn(world, "ru_command_hq", 2, 100, 60)
	world.apply_damage(world.get_entity(hq), 1000000, "high_explosive", tank)
	# The HQ costs 3000: 3000 XP for its health plus a 50% kill bonus.
	assert_eq(world.get_player(1).xp, 2550 + 3000 + 1500)
	assert_eq(world.get_player(1).rank, 3)


func test_losing_all_buildings_and_builders_means_defeat() -> void:
	var world := _world("buildings")
	_spawn(world, "us_command_hq", 1, 20, 46)
	var ru_hq: int = _spawn(world, "ru_command_hq", 2, 108, 46)
	var ru_tank: int = _spawn(world, "ru_mbt", 2, 100, 80)
	for i: int in SimWorld.TICK_RATE * 2:
		world.step()
	assert_false(world.game_over)
	world.apply_damage(world.get_entity(ru_hq), 1000000, "high_explosive", 0)
	for i: int in SimWorld.TICK_RATE * 2:
		world.step()
	assert_true(world.get_player(2).defeated)
	assert_false(world.entities.has(ru_tank), "a defeated player's units are removed")
	assert_true(world.game_over)
	assert_eq(world.winner_team, 1)


func test_units_rule_and_draws() -> void:
	var world := _world("units")
	var a: int = _spawn(world, "us_rifle_squad", 1, 30, 60)
	var b: int = _spawn(world, "ru_motor_rifle_squad", 2, 100, 60)
	for i: int in SimWorld.TICK_RATE:
		world.step()
	world.apply_damage(world.get_entity(a), 100000, "small_arms", 0)
	world.apply_damage(world.get_entity(b), 100000, "small_arms", 0)
	for i: int in SimWorld.TICK_RATE * 2:
		world.step()
	assert_true(world.game_over)
	assert_eq(world.winner_team, 0, "both eliminated at once is a draw")


func test_sandbox_never_ends() -> void:
	var world := _world("none")
	for i: int in SimWorld.TICK_RATE * 3:
		world.step()
	assert_false(world.game_over)
