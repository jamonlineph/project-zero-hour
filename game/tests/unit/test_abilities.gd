extends TestCase
# Unit abilities (P3-02f): the UAE special forces call strikes and disable
# buildings; cooldowns, range, sight and one use per command.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(43, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.credits = 10000
	return w


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	var e: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))
	e.weapons.clear()
	return e


func _use(w: SimWorld, units: Array[SimEntity], ability: String, x_m: int, y_m: int, target: int = 0) -> void:
	var ids: Array[int] = []
	for u: SimEntity in units:
		ids.append(u.id)
	var c := SimCommand.make_use_ability(ids, ability, Fx.from_int(x_m), Fx.from_int(y_m), target)
	c.player_id = units[0].player_id
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)
	w.step()


func _strikes(w: SimWorld, player: int) -> int:
	var n: int = 0
	for id: int in w.entity_ids:
		if w.entities[id].strike != null and w.entities[id].player_id == player:
			n += 1
	return n


func test_special_forces_have_both_abilities() -> void:
	var u: UnitDef = _content().get_unit("ae_sf_team")
	assert_eq(u.abilities.size(), 2)
	assert_eq(u.abilities[0].kind, "strike")
	assert_true(_content().strikes.has(u.abilities[0].strike_id), "the strike ability names a missing strike")
	assert_eq(u.abilities[1].kind, "disable")
	assert_eq(u.abilities[1].duration_ticks, 25 * SimWorld.TICK_RATE)


func test_a_strike_needs_sight_and_range_and_then_cools_down() -> void:
	var w := _world()
	var a := _unit(w, "ae_sf_team", 1, 50, 120)
	var b := _unit(w, "ae_sf_team", 1, 52, 120)
	w.step()   # vision
	_use(w, [a], "sf_precision_strike", 200, 120)   # out of range and out of sight
	assert_eq(_strikes(w, 1), 0)
	_use(w, [a, b], "sf_precision_strike", 80, 120)
	assert_eq(_strikes(w, 1), 2, "two teams selected should still call one strike of 2 rockets")
	assert_true(a.ability_ready.has("sf_precision_strike"), "the lower id used it")
	assert_false(b.ability_ready.has("sf_precision_strike"))
	_use(w, [a], "sf_precision_strike", 80, 120)
	assert_eq(_strikes(w, 1), 2, "a strike during the cooldown")
	_use(w, [a, b], "sf_precision_strike", 80, 120)
	assert_true(_strikes(w, 1) > 2, "the second team couldn't use its own ready strike")


func test_disable_shuts_a_building_down_for_a_while() -> void:
	var w := _world()
	var sf := _unit(w, "ae_sf_team", 1, 100, 100)
	var plant: SimEntity = w.get_entity(w.spawn_building(_content().get_building("kp_power_plant"), 2, 52, 46, true))
	var barracks: SimEntity = w.get_entity(w.spawn_building(_content().get_building("kp_barracks"), 2, 52, 60, true))
	w.step()
	var power_before: int = w.get_player(2).power_produced
	assert_true(power_before > 0)
	_use(w, [sf], "sf_disable", 0, 0, plant.id)
	assert_true(plant.building.is_disabled(w.tick), "the plant wasn't disabled")
	w.step()
	assert_eq(w.get_player(2).power_produced, power_before - plant.building.power, "a disabled plant still made power")
	# Too far from the barracks to sabotage it.
	_use(w, [sf], "sf_disable", 0, 0, barracks.id)
	assert_false(barracks.building.is_disabled(w.tick))
	for i: int in 25 * SimWorld.TICK_RATE:
		w.step()
	assert_false(plant.building.is_disabled(w.tick), "the plant stayed disabled")
	assert_eq(w.get_player(2).power_produced, power_before)


func test_a_disabled_barracks_stops_training() -> void:
	var w := _world()
	w.get_player(2).faction = "kp"
	w.spawn_building(_content().get_building("kp_power_plant"), 2, 20, 20, true)
	var barracks: SimEntity = w.get_entity(w.spawn_building(_content().get_building("kp_barracks"), 2, 60, 60, true))
	var sf := _unit(w, "ae_sf_team", 1, 128, 120)
	barracks.building.queue.append("kp_infantry_squad")
	w.step()
	var progress: int = barracks.building.queue_progress
	assert_true(progress > 0)
	_use(w, [sf], "sf_disable", 0, 0, barracks.id)
	for i: int in 10:
		w.step()
	assert_eq(barracks.building.queue_progress, progress, "a disabled barracks kept training")


func test_commands_round_trip() -> void:
	var c := SimCommand.from_dict(SimCommand.make_use_ability([4, 5], "sf_disable", 7, 8, 9).to_dict())
	assert_eq(c.type, SimCommand.Type.USE_ABILITY)
	assert_eq(c.def_id, "sf_disable")
	assert_eq(c.target_entity, 9)
	assert_eq(c.target_x, 7)


func _ability_hash() -> int:
	var w := _world()
	var sf := _unit(w, "ae_sf_team", 1, 50, 120)
	w.step()
	_use(w, [sf], "sf_precision_strike", 80, 120)
	for i: int in 60:
		w.step()
	return w.state_hash()


func test_abilities_are_deterministic() -> void:
	assert_eq(_ability_hash(), _ability_hash())
