extends TestCase
# Neutral capturable buildings (P3-08a): infantry capture them by standing
# next to them; enemies take them back; each works for its owner (income,
# power, healing, sight) but doesn't keep a player alive.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(59, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "us" if pid == 1 else "kp"
	return w


func _neutral(w: SimWorld, def_id: String, x_m: int = 120, y_m: int = 120) -> SimEntity:
	var def: BuildingDef = _content().get_building(def_id)
	var o: Vector2i = w.footprint_origin(def, Fx.from_int(x_m), Fx.from_int(y_m))
	return w.get_entity(w.spawn_building(def, 0, o.x, o.y, true))


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	var e: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))
	e.weapons.clear()
	return e


func _capture(w: SimWorld, units: Array[SimEntity], s: SimEntity) -> void:
	var ids: Array[int] = []
	for u: SimEntity in units:
		ids.append(u.id)
	var c := SimCommand.make_capture(ids, s.id)
	c.player_id = units[0].player_id
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func test_the_four_buildings_are_data() -> void:
	for id: String in ["oil_field", "solar_farm", "field_hospital", "data_center"]:
		var def: BuildingDef = _content().get_building(id)
		assert_true(def != null and def.capture_ticks > 0, "%s isn't capturable" % id)
		assert_eq(def.faction, "neutral")
	assert_eq(_content().get_building("oil_field").income, 60)
	assert_true(_content().get_building("solar_farm").power > 0)
	assert_true(_content().get_building("field_hospital").heal_radius > 0)
	assert_eq(_content().get_building("data_center").vision, Fx.from_int(120))


func test_infantry_capture_it_and_the_enemy_can_take_it_back() -> void:
	var w := _world()
	var oil := _neutral(w, "oil_field")
	var squad := _unit(w, "us_rifle_squad", 1, 120, 150)
	var tank := _unit(w, "us_mbt", 1, 126, 150)
	_capture(w, [squad, tank], oil)
	_run(w, 20 * SimWorld.TICK_RATE)
	assert_eq(oil.player_id, 1, "the oil field wasn't captured")
	assert_eq(squad.order, SimEntity.Order.IDLE, "the capturer kept its order")
	assert_true(tank.order != SimEntity.Order.CAPTURE, "a tank was sent to capture")
	var enemy := _unit(w, "kp_infantry_squad", 2, 120, 90)
	_capture(w, [enemy], oil)
	_run(w, 20 * SimWorld.TICK_RATE)
	assert_eq(oil.player_id, 2, "the enemy couldn't take it back")


func test_leaving_starts_the_capture_over() -> void:
	var w := _world()
	var oil := _neutral(w, "oil_field")
	var squad := _unit(w, "us_rifle_squad", 1, 120, 128)
	_capture(w, [squad], oil)
	_run(w, 5 * SimWorld.TICK_RATE)
	assert_true(oil.building.capture_progress > 0, "no progress next to the building")
	var c := SimCommand.make_move([squad.id], Fx.from_int(120), Fx.from_int(200))
	c.player_id = 1
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)
	_run(w, 2)
	assert_eq(oil.building.capture_progress, 0, "progress stayed after the capturer left")
	assert_eq(oil.player_id, 0)


func test_an_oil_field_pays_its_owner_every_10_seconds() -> void:
	var w := _world()
	var oil := _neutral(w, "oil_field")
	var before: int = w.get_player(1).credits
	_run(w, 10 * SimWorld.TICK_RATE + 1)
	assert_eq(w.get_player(1).credits, before, "a neutral oil field paid someone")
	oil.player_id = 1
	_run(w, 10 * SimWorld.TICK_RATE)
	assert_eq(w.get_player(1).credits, before + 60)


func test_a_captured_solar_farm_and_hospital_work_for_their_owner() -> void:
	var w := _world()
	var farm := _neutral(w, "solar_farm", 60, 60)
	var hospital := _neutral(w, "field_hospital", 160, 160)
	var squad := _unit(w, "us_rifle_squad", 1, 160, 172)
	squad.hp = 100
	_run(w, SimWorld.TICK_RATE + 1)
	assert_eq(w.get_player(1).power_produced, 0)
	assert_eq(squad.hp, 100, "a neutral hospital healed someone")
	farm.player_id = 1
	hospital.player_id = 1
	_run(w, SimWorld.TICK_RATE)
	assert_eq(w.get_player(1).power_produced, farm.building.power)
	assert_true(squad.hp > 100, "the captured hospital didn't heal its owner's infantry")


func test_captured_buildings_dont_keep_a_player_alive() -> void:
	var w := _world()
	w.victory_rule = "buildings"
	var oil := _neutral(w, "oil_field")
	oil.player_id = 1
	w.spawn_building(_content().get_building("kp_power_plant"), 2, 10, 10, true)
	_run(w, SimWorld.TICK_RATE * 2)
	assert_true(w.get_player(1).defeated, "an oil field kept a player with nothing else alive")
	assert_false(oil.dead)
	assert_eq(oil.player_id, 0, "the oil field didn't turn neutral again")


func test_the_ai_sends_a_squad_to_capture() -> void:
	var w := _world()
	var hq: SimEntity = w.get_entity(w.spawn_building(_content().get_building("us_command_hq"), 1, 20, 20, true))
	var oil := _neutral(w, "oil_field", 100, 60)
	var squad: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit("us_rifle_squad"), 1, Fx.from_int(60), Fx.from_int(60)))
	var cmds: Array[SimCommand] = []
	AiTactics.capture(w, 1, hq, [squad], cmds)
	assert_eq(cmds.size(), 1)
	assert_eq(cmds[0].type, SimCommand.Type.CAPTURE)
	assert_eq(cmds[0].target_entity, oil.id)


func _capture_hash() -> int:
	var w := _world()
	var oil := _neutral(w, "oil_field")
	_capture(w, [_unit(w, "us_rifle_squad", 1, 120, 150)], oil)
	_capture(w, [_unit(w, "kp_infantry_squad", 2, 120, 90)], oil)
	_run(w, 15 * SimWorld.TICK_RATE)
	return w.state_hash()


func test_capturing_is_deterministic() -> void:
	assert_eq(_capture_hash(), _capture_hash())


func test_a_captured_rail_depot_builds_vehicles_faster() -> void:
	var times: Array[int] = []
	for captured: bool in [false, true]:
		var w := _world()
		w.get_player(1).credits = 10000
		w.spawn_building(_content().get_building("us_microreactor"), 1, 10, 10, true)
		var depot: SimEntity = w.get_entity(w.spawn_building(_content().get_building("us_vehicle_depot"), 1, 30, 30, true))
		var rail := _neutral(w, "rail_depot", 200, 200)
		if captured:
			rail.player_id = 1
		depot.building.queue.append("us_mbt")
		var ticks: int = 0
		while not depot.building.queue.is_empty() and ticks < 1000:
			w.step()
			ticks += 1
		times.append(ticks)
	var expected: int = (times[0] * 100) / 125
	assert_true(absi(times[1] - expected) <= 2, "a tank took %d ticks with the depot, %d without" % [times[1], times[0]])


func test_a_captured_cell_tower_spots_for_its_owner() -> void:
	var w := _world()
	var tower := _neutral(w, "cell_tower", 120, 120)
	w.step()
	assert_false(w.is_spotted(1, Fx.from_int(150), Fx.from_int(120)), "a neutral tower spotted for someone")
	tower.player_id = 1
	w.step()
	assert_true(w.is_spotted(1, Fx.from_int(150), Fx.from_int(120)), "the captured tower doesn't spot 30 m away")
	assert_false(w.is_spotted(2, Fx.from_int(150), Fx.from_int(120)), "it spotted for the enemy")
