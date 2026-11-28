extends TestCase
# Transports (P3-06): infantry board their own IFV, ride along, fire from
# inside, can't be shot, get out with UNLOAD, and are thrown out hurt when
# the transport is destroyed.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(67, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		w.get_player(pid).team = pid
	return w


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


func _board(w: SimWorld, units: Array[SimEntity], t: SimEntity, player: int) -> void:
	var ids: Array[int] = []
	for u: SimEntity in units:
		ids.append(u.id)
	_cmd(w, SimCommand.make_garrison(ids, t.id), player)
	_run(w, 200)


func test_ifvs_carry_two_squads() -> void:
	for id: String in ["us_ifv", "kp_ifv", "ae_ifv", "eu_ifv", "eu_apc"]:
		assert_eq(_content().get_unit(id).transport_capacity, 2, id)
	var w := _world()
	var ifv := _unit(w, "us_ifv", 1, 100, 100)
	assert_true(ifv.garrison != null)
	assert_eq(ifv.garrison.capacity, 2)


func test_infantry_board_ride_along_and_get_out() -> void:
	var w := _world()
	var ifv := _unit(w, "us_ifv", 1, 100, 100)
	var a := _unit(w, "us_rifle_squad", 1, 100, 120)
	var b := _unit(w, "us_at_team", 1, 104, 120)
	var c := _unit(w, "us_rifle_squad", 1, 108, 120)
	var tank := _unit(w, "us_mbt", 1, 112, 120)
	_board(w, [a, b, c, tank], ifv, 1)
	# Whoever reaches it first gets in; it has room for two.
	var aboard: Array[SimEntity] = []
	for u: SimEntity in [a, b, c]:
		if u.inside_id == ifv.id:
			aboard.append(u)
	assert_eq(aboard.size(), 2, "the transport for two holds %d" % aboard.size())
	assert_eq(ifv.garrison.occupants.size(), 2)
	assert_eq(tank.inside_id, 0, "a tank boarded a transport")
	a = aboard[0]
	b = aboard[1]
	_cmd(w, SimCommand.make_move([ifv.id], Fx.from_int(180), Fx.from_int(180)), 1)
	_run(w, 300)
	assert_true(Fx.length(ifv.x - Fx.from_int(100), ifv.y - Fx.from_int(100)) > Fx.from_int(40), "the transport didn't drive")
	assert_true(Fx.length(a.x - ifv.x, a.y - ifv.y) <= Fx.from_int(10), "a passenger was left behind")
	_cmd(w, SimCommand.make_unload(ifv.id), 1)
	_run(w, 2)
	assert_eq(a.inside_id, 0)
	assert_eq(b.inside_id, 0)
	assert_true(w.map.is_passable(SimMap.cell_coord(a.x), SimMap.cell_coord(a.y)), "a passenger got out onto a blocked cell")


func test_the_enemy_cannot_board_and_passengers_cannot_be_shot() -> void:
	var w := _world()
	var ifv := _unit(w, "us_ifv", 1, 100, 100)
	var enemy := _unit(w, "kp_infantry_squad", 2, 100, 120)
	enemy.weapons.clear()
	_board(w, [enemy], ifv, 2)
	assert_eq(enemy.inside_id, 0, "an enemy boarded our transport")
	var squad := _unit(w, "us_rifle_squad", 1, 100, 115)
	_board(w, [squad], ifv, 1)
	assert_eq(squad.inside_id, ifv.id)
	var shooter := _unit(w, "kp_infantry_squad", 2, 100, 125)
	shooter.vision = Fx.from_int(60)
	_run(w, 60)
	assert_eq(squad.hp, squad.max_hp, "a passenger was hit directly")


func test_a_destroyed_transport_throws_its_passengers_out_hurt() -> void:
	var w := _world()
	var ifv := _unit(w, "us_ifv", 1, 100, 100)
	var squad := _unit(w, "us_rifle_squad", 1, 100, 115)
	_board(w, [squad], ifv, 1)
	w.apply_damage(ifv, 1000000, "anti_tank", 0)
	_run(w, 3)
	assert_eq(squad.inside_id, 0)
	assert_false(squad.dead, "the passenger died with the transport")
	assert_true(squad.hp < squad.max_hp)


func _ride_hash() -> int:
	var w := _world()
	var ifv := _unit(w, "kp_ifv", 2, 100, 100)
	_board(w, [_unit(w, "kp_infantry_squad", 2, 100, 115), _unit(w, "kp_at_team", 2, 104, 115)], ifv, 2)
	_cmd(w, SimCommand.make_move([ifv.id], Fx.from_int(160), Fx.from_int(60)), 2)
	_run(w, 200)
	return w.state_hash()


func test_transports_are_deterministic() -> void:
	assert_eq(_ride_hash(), _ride_hash())
