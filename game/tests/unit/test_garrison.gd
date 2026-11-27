extends TestCase
# Garrisons (P3-05): entering, holding a town house, firing from inside,
# protection, clearing with thermobaric weapons, leaving and destruction.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(31, 200, 200)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		w.get_player(pid).team = pid
	return w


func _house(w: SimWorld, x_m: int = 100, y_m: int = 100) -> SimEntity:
	return w.get_entity(w.spawn_structure(_content().get_building("civilian_house"), x_m, y_m, 10, 8))


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func _cmd(w: SimWorld, c: SimCommand, player: int) -> void:
	c.player_id = player
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func _enter(w: SimWorld, units: Array[SimEntity], s: SimEntity, player: int) -> void:
	var ids: Array[int] = []
	for u: SimEntity in units:
		ids.append(u.id)
	_cmd(w, SimCommand.make_garrison(ids, s.id), player)
	_run(w, 300)


func test_houses_are_neutral_buildings_with_room_for_two() -> void:
	var w := _world()
	var h := _house(w)
	assert_eq(h.player_id, 0)
	assert_eq(h.garrison.capacity, 2)
	assert_true(h.garrison.neutral)
	assert_eq(h.building.w, 5)
	assert_eq(h.building.h, 4)
	assert_false(w.map.is_passable(SimMap.cell_coord(h.x), SimMap.cell_coord(h.y)), "a house doesn't block")


func test_infantry_enter_and_claim_a_house_up_to_its_capacity() -> void:
	var w := _world()
	var h := _house(w)
	var a := _unit(w, "us_rifle_squad", 1, 100, 130)
	var b := _unit(w, "us_rifle_squad", 1, 104, 130)
	var c := _unit(w, "us_rifle_squad", 1, 108, 130)
	var tank := _unit(w, "us_mbt", 1, 112, 130)
	_enter(w, [a, b, c, tank], h, 1)
	assert_eq(h.player_id, 1, "the house was not claimed")
	assert_eq(h.garrison.occupants.size(), 2)
	assert_eq(a.inside_id, h.id)
	assert_eq(b.inside_id, h.id)
	assert_eq(c.inside_id, 0, "a third squad got into a house for two")
	assert_eq(tank.inside_id, 0, "a tank went inside")
	assert_eq(a.x, h.x)
	# The enemy can't walk into a house we hold.
	var enemy := _unit(w, "kp_infantry_squad", 2, 100, 70)
	enemy.weapons.clear()
	_enter(w, [enemy], h, 2)
	assert_eq(enemy.inside_id, 0)


func test_units_inside_fire_further_and_cannot_be_shot() -> void:
	var w := _world()
	var h := _house(w)
	var squad := _unit(w, "us_rifle_squad", 1, 100, 125)
	_enter(w, [squad], h, 1)
	var rifle_range: int = squad.weapons[0].max_range
	# An enemy squad just beyond normal rifle range of the house's center.
	var enemy := _unit(w, "kp_infantry_squad", 2, 100, 100 + rifle_range / Fx.ONE + 3)
	enemy.vision = Fx.from_int(60)
	var enemy_hp: int = enemy.hp
	_run(w, 90)
	assert_true(enemy.hp < enemy_hp, "the garrison did not use its range bonus")
	assert_eq(squad.hp, squad.max_hp, "a unit inside a building was hit directly")
	assert_true(h.hp < h.max_hp, "the enemy didn't shoot the building instead")


func test_thermobaric_damage_clears_the_building() -> void:
	var w := _world()
	var h := _house(w)
	var squad := _unit(w, "us_rifle_squad", 1, 100, 125)
	_enter(w, [squad], h, 1)
	var hp: int = squad.hp
	w.apply_damage(h, 200, "thermobaric", 0)
	assert_true(squad.hp < hp, "a thermobaric hit did not reach the units inside")
	hp = squad.hp
	w.apply_damage(h, 200, "anti_tank", 0)
	assert_eq(squad.hp, hp, "an ordinary hit reached the units inside")
	CombatSystem.impact(w, 2, 0, 0, h.x, h.y, 300, "high_explosive", Fx.from_int(8), 50, PackedStringArray())
	assert_eq(squad.hp, hp, "high-explosive splash went through the walls")


func test_exit_and_destruction_let_units_out() -> void:
	var w := _world()
	var h := _house(w)
	var a := _unit(w, "us_rifle_squad", 1, 100, 125)
	var b := _unit(w, "us_rifle_squad", 1, 104, 125)
	_enter(w, [a, b], h, 1)
	_cmd(w, SimCommand.make_unload(h.id), 1)
	_run(w, 2)
	assert_eq(a.inside_id, 0)
	assert_eq(b.inside_id, 0)
	assert_eq(h.player_id, 0, "an empty house did not turn neutral")
	assert_true(w.map.is_passable(SimMap.cell_coord(a.x), SimMap.cell_coord(a.y)), "a unit came out inside the walls")
	_enter(w, [a], h, 1)
	assert_eq(a.inside_id, h.id)
	var hp: int = a.hp
	w.apply_damage(h, 100000, "anti_tank", 0)
	_run(w, 2)
	assert_eq(a.inside_id, 0, "the unit stayed inside a destroyed house")
	assert_true(a.hp < hp and not a.dead, "coming out of a destroyed house should hurt, not kill")


func test_town_houses_do_not_keep_a_player_alive() -> void:
	var w := _world()
	w.victory_rule = "buildings"
	var h := _house(w)
	var squad := _unit(w, "us_rifle_squad", 1, 100, 125)
	w.spawn_building(_content().get_building("kp_power_plant"), 2, 10, 10, true)
	_enter(w, [squad], h, 1)
	_run(w, SimWorld.TICK_RATE * 2)
	assert_true(w.get_player(1).defeated, "a house kept a player with no buildings alive")
	assert_false(h.dead, "the town house was destroyed with its holder")
	assert_eq(h.player_id, 0)


func _garrison_hash() -> int:
	var w := _world()
	var h := _house(w)
	_enter(w, [_unit(w, "us_rifle_squad", 1, 100, 125), _unit(w, "us_rifle_squad", 1, 104, 125)], h, 1)
	_unit(w, "kp_infantry_squad", 2, 100, 70)
	_run(w, 300)
	return w.state_hash()


func test_garrisons_are_deterministic() -> void:
	assert_eq(_garrison_hash(), _garrison_hash())


func test_commands_round_trip() -> void:
	var g := SimCommand.from_dict(SimCommand.make_garrison([3, 4], 9).to_dict())
	assert_eq(g.type, SimCommand.Type.GARRISON)
	assert_eq(g.target_entity, 9)
	var u := SimCommand.from_dict(SimCommand.make_unload(9).to_dict())
	assert_eq(u.type, SimCommand.Type.UNLOAD)
