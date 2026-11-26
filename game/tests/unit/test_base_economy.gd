extends TestCase
# Construction (P1-12), production (P1-13), requirements (P1-14),
# supply economy (P1-15) and power (P1-16).

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


## A clean 128 m world with player 1 (US) holding `credits`.
func _world(credits: int = 20000) -> SimWorld:
	var sc: Dictionary = {
		"id": "test", "map": "sandbox", "victory": "none",
		"players": [{"id": 1, "team": 1, "faction": "us", "credits": credits},
			{"id": 2, "team": 2, "faction": "ru", "credits": credits}],
		"spawns": [],
	}
	return MatchSetup.build_from(_content(), sc, 1)


func _cmd(world: SimWorld, c: SimCommand, player: int = 1) -> void:
	c.player_id = player
	c.seq = world.tick * 10 + 1
	c.tick = world.tick
	world.queue_command(c)


func _run(world: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		world.step()


func _spawn(world: SimWorld, def_id: String, x_m: int, y_m: int, player: int = 1) -> int:
	var u: UnitDef = _content().get_unit(def_id)
	if u != null:
		return world.spawn_unit(u, player, Fx.from_int(x_m), Fx.from_int(y_m))
	var b: BuildingDef = _content().get_building(def_id)
	var o: Vector2i = SimWorld.footprint_origin(b, Fx.from_int(x_m), Fx.from_int(y_m))
	return world.spawn_building(b, player, o.x, o.y, true)


func _find(world: SimWorld, def_id: String, player: int = 1) -> SimEntity:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.def_id == def_id and e.player_id == player:
			return e
	return null


func test_scenario_builds_the_sandbox() -> void:
	var world: SimWorld = MatchSetup.build(_content(), "sandbox", 1)
	assert_true(world != null)
	assert_eq(world.get_player(1).credits, 10000)
	assert_eq(world.get_player(2).faction, "ru")
	assert_true(_find(world, "us_command_hq") != null, "US HQ missing")
	assert_true(_find(world, "ru_command_hq", 2) != null, "RU HQ missing")
	var sites: int = 0
	for id: int in world.entity_ids:
		if world.entities[id].supply != null:
			sites += 1
	assert_eq(sites, 4)


func test_engineer_constructs_a_building() -> void:
	var world := _world()
	var eng: int = _spawn(world, "us_engineer", 30, 30)
	_cmd(world, SimCommand.make_build([eng], "us_microreactor", Fx.from_int(40), Fx.from_int(60)))
	world.step()
	var plant: SimEntity = _find(world, "us_microreactor")
	assert_true(plant != null, "building was not placed")
	assert_false(plant.building.built)
	assert_eq(world.get_player(1).credits, 20000 - 800)
	assert_eq(world.get_player(1).power_produced, 0, "unfinished buildings give no power")
	_run(world, 15 * 25)
	assert_true(plant.building.built, "construction never finished")
	assert_eq(plant.hp, plant.max_hp)
	world.step()
	assert_eq(world.get_player(1).power_produced, 10)


func test_two_engineers_build_faster_than_one() -> void:
	var ticks: Array[int] = []
	for helpers: int in [1, 2]:
		var world := _world()
		var ids: Array[int] = []
		for i: int in helpers:
			ids.append(_spawn(world, "us_engineer", 30 + i * 6, 30))
		_cmd(world, SimCommand.make_build(ids, "us_microreactor", Fx.from_int(40), Fx.from_int(60)))
		world.step()
		var plant: SimEntity = _find(world, "us_microreactor")
		var t: int = 0
		while not plant.building.built and t < 15 * 60:
			world.step()
			t += 1
		ticks.append(t)
	assert_true(ticks[1] < ticks[0], "1 builder %d ticks, 2 builders %d ticks" % [ticks[0], ticks[1]])


func test_cannot_build_without_money_requirements_or_room() -> void:
	var world := _world(100)
	var eng: int = _spawn(world, "us_engineer", 30, 30)
	_cmd(world, SimCommand.make_build([eng], "us_microreactor", Fx.from_int(40), Fx.from_int(60)))
	world.step()
	assert_true(_find(world, "us_microreactor") == null, "built without enough credits")
	world.get_player(1).credits = 20000
	_cmd(world, SimCommand.make_build([eng], "us_barracks", Fx.from_int(40), Fx.from_int(60)))
	world.step()
	assert_true(_find(world, "us_barracks") == null, "built a barracks without its power plant")
	_cmd(world, SimCommand.make_build([eng], "us_microreactor", Fx.from_int(64), Fx.from_int(30)))   # on the ridge
	world.step()
	assert_true(_find(world, "us_microreactor") == null, "built on rock")
	_cmd(world, SimCommand.make_build([eng], "ru_power_plant", Fx.from_int(40), Fx.from_int(60)))
	world.step()
	assert_true(_find(world, "ru_power_plant") == null, "built another faction's building")


func test_production_queue_rally_and_cancel() -> void:
	var world := _world(5000)
	_spawn(world, "us_microreactor", 20, 20)
	var barracks: int = _spawn(world, "us_barracks", 30, 70)
	world.step()
	_cmd(world, SimCommand.make_rally(barracks, Fx.from_int(50), Fx.from_int(90)))
	_cmd(world, SimCommand.make_produce(barracks, "us_rifle_squad"))
	world.step()
	_cmd(world, SimCommand.make_produce(barracks, "us_rifle_squad"))
	_cmd(world, SimCommand.make_produce(barracks, "us_mbt"))   # not made here: ignored
	world.step()
	var b: SimEntity = world.get_entity(barracks)
	assert_eq(b.building.queue.size(), 2)
	assert_eq(world.get_player(1).credits, 5000 - 500)
	_cmd(world, SimCommand.make_cancel(barracks, 1))
	world.step()
	assert_eq(b.building.queue.size(), 1)
	assert_eq(world.get_player(1).credits, 5000 - 250)
	_run(world, 15 * 8)
	var squad: SimEntity = _find(world, "us_rifle_squad")
	assert_true(squad != null, "no unit came out")
	_run(world, 15 * 20)
	assert_true(Fx.length(squad.x - Fx.from_int(50), squad.y - Fx.from_int(90)) < Fx.from_int(3), "unit did not go to the rally point")


func test_low_power_halves_production_speed() -> void:
	var times: Array[int] = []
	for powered: bool in [true, false]:
		var world := _world()
		if powered:
			_spawn(world, "us_microreactor", 20, 20)
		var barracks: int = _spawn(world, "us_barracks", 30, 70)
		world.step()
		if not powered:
			assert_true(world.get_player(1).low_power())
		_cmd(world, SimCommand.make_produce(barracks, "us_rifle_squad"))
		var t: int = 0
		while _find(world, "us_rifle_squad") == null and t < 15 * 30:
			world.step()
			t += 1
		times.append(t)
	assert_true(times[1] >= times[0] * 2 - 2, "powered %d ticks, unpowered %d ticks" % [times[0], times[1]])


func test_trucks_gather_supply_into_credits() -> void:
	var world: SimWorld = MatchSetup.build(_content(), "sandbox", 1)
	world.get_player(1).credits = 0
	var eng: SimEntity = _find(world, "us_engineer")
	_cmd(world, SimCommand.make_build([eng.id], "us_logistics_hub", Fx.from_int(46), Fx.from_int(56)))
	world.get_player(1).credits = 1500
	_run(world, 15 * 60)
	var hub: SimEntity = _find(world, "us_logistics_hub")
	assert_true(hub != null and hub.building.built, "hub not built")
	var trucks: int = 0
	for id: int in world.entity_ids:
		if world.entities[id].def_id == "us_logistics_truck":
			trucks += 1
	assert_eq(trucks, 2, "the hub should give a free truck")
	var before: int = world.get_player(1).credits
	_run(world, 15 * 60)
	assert_true(world.get_player(1).credits - before >= 1200, "earned only %d in a minute" % (world.get_player(1).credits - before))


func test_supply_sites_run_dry() -> void:
	var world := _world(0)
	_spawn(world, "us_logistics_hub", 30, 60)
	var site: int = world.spawn_supply_site(Fx.from_int(42), Fx.from_int(60), 600)
	_spawn(world, "us_logistics_truck", 36, 66)
	_run(world, 15 * 90)
	assert_eq(world.get_entity(site).supply.remaining, 0)
	# All 600 were collected; the truck then moves on to the map's other sites.
	assert_true(world.get_player(1).credits >= 600, "collected only %d" % world.get_player(1).credits)


func test_move_order_takes_truck_off_duty_and_gather_resumes() -> void:
	var world := _world(0)
	_spawn(world, "us_logistics_hub", 30, 60)
	var site: int = world.spawn_supply_site(Fx.from_int(42), Fx.from_int(60), 30000)
	var truck: int = _spawn(world, "us_logistics_truck", 36, 66)
	_cmd(world, SimCommand.make_move([truck], Fx.from_int(10), Fx.from_int(110)))
	_run(world, 15 * 30)
	assert_eq(world.get_player(1).credits, 0, "truck kept working after a move order")
	_cmd(world, SimCommand.make_gather([truck], site))
	_run(world, 15 * 60)
	assert_true(world.get_player(1).credits > 0, "gather order did not resume work")


func test_sell_refunds_half() -> void:
	var world := _world(0)
	var plant: int = _spawn(world, "us_microreactor", 20, 20)
	_cmd(world, SimCommand.make_sell(plant))
	_run(world, 2)
	assert_false(world.entities.has(plant))
	assert_eq(world.get_player(1).credits, 400)
	assert_true(world.map.is_passable(10, 10), "footprint not released")


func test_repair_restores_health_for_credits() -> void:
	var world := _world(1000)
	var plant: int = _spawn(world, "us_microreactor", 20, 20)
	var eng: int = _spawn(world, "us_engineer", 32, 20)
	var p: SimEntity = world.get_entity(plant)
	p.hp = p.max_hp / 2
	_cmd(world, SimCommand.make_repair([eng], plant))
	_run(world, 15 * 40)
	assert_true(p.hp > p.max_hp / 2, "no repair happened")
	assert_true(world.get_player(1).credits < 1000, "repairs should cost credits")


func test_base_economy_is_deterministic() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var world: SimWorld = MatchSetup.build(_content(), "sandbox", 7)
		var eng: SimEntity = _find(world, "us_engineer")
		_cmd(world, SimCommand.make_build([eng.id], "us_logistics_hub", Fx.from_int(46), Fx.from_int(56)))
		var reng: SimEntity = _find(world, "ru_engineer", 2)
		_cmd(world, SimCommand.make_build([reng.id], "ru_logistics_hub", Fx.from_int(84), Fx.from_int(56)), 2)
		_run(world, 15 * 90)
		hashes.append(world.state_hash())
	assert_eq(hashes[0], hashes[1])
