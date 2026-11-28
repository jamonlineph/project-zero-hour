extends TestCase
# Minefields (P3-10a): walk-over, hidden, and they go off once under an enemy
# ground unit; detectors reveal them so they can be shot; they don't keep a
# player alive.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(73, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "kp" if pid == 1 else "us"
	return w


func _mine(w: SimWorld, x_m: int, y_m: int) -> SimEntity:
	var def: BuildingDef = _content().get_building("kp_minefield")
	var o: Vector2i = w.footprint_origin(def, Fx.from_int(x_m), Fx.from_int(y_m))
	return w.get_entity(w.spawn_building(def, 1, o.x, o.y, true))


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	var e: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))
	e.weapons.clear()
	return e


func _drive(w: SimWorld, e: SimEntity, x_m: int, y_m: int, ticks: int) -> void:
	var c := SimCommand.make_move([e.id], Fx.from_int(x_m), Fx.from_int(y_m))
	c.player_id = e.player_id
	c.seq = w.tick + 1
	c.tick = w.tick
	w.queue_command(c)
	for i: int in ticks:
		w.step()


func test_a_mine_doesnt_block_and_is_hidden() -> void:
	var w := _world()
	var mine := _mine(w, 120, 120)
	assert_true(w.map.is_passable(SimMap.cell_coord(mine.x), SimMap.cell_coord(mine.y)), "a minefield blocks movement")
	_unit(w, "us_rifle_squad", 2, 120, 150)
	for i: int in 5:
		w.step()
	assert_false(w.is_detected(2, mine), "an enemy 30 m away sees the minefield")


func test_it_blows_up_under_an_enemy_vehicle_once() -> void:
	var w := _world()
	var mine := _mine(w, 120, 120)
	var tank := _unit(w, "us_mbt", 2, 120, 160)
	var own := _unit(w, "kp_mbt", 1, 100, 140)
	_drive(w, own, 140, 140, 60)   # our own tank never sets it off
	assert_false(mine.dead, "our own tank set off the mine")
	var hp: int = tank.hp
	_drive(w, tank, 120, 80, 200)
	assert_true(mine.dead, "the enemy tank drove over it and nothing happened")
	assert_true(tank.hp < hp - 200, "the mine barely hurt the tank (%d -> %d)" % [hp, tank.hp])


func test_minefields_dont_keep_a_player_alive() -> void:
	var w := _world()
	w.victory_rule = "buildings"
	_mine(w, 120, 120)
	w.spawn_building(_content().get_building("us_microreactor"), 2, 10, 10, true)
	for i: int in SimWorld.TICK_RATE * 2:
		w.step()
	assert_true(w.get_player(1).defeated, "a minefield kept a player alive")
