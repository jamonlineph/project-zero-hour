extends TestCase
# Transport helicopters (P3-04b with P3-06): infantry board their own
# transport helicopter, fly over ground they can't walk, and get out on the
# far side; shot down, everyone aboard is lost.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


## A world split by a wall of rock from top to bottom at x = 110..130 m.
func _world() -> SimWorld:
	var w := SimWorld.new(107, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.map.add_obstacle_m(110, 0, 20, 240)
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		w.get_player(pid).team = pid
	return w


func _unit(w: SimWorld, def_id: String, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), 1, Fx.from_int(x_m), Fx.from_int(y_m)))


func _cmd(w: SimWorld, c: SimCommand) -> void:
	c.player_id = 1
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func test_every_faction_has_one() -> void:
	for pair: Array in [["us_airbase", "us_tiltrotor"], ["ae_airbase", "ae_transport_heli"],
			["eu_airbase", "eu_transport_heli"], ["kp_airstrip", "kp_transport_heli"]]:
		var u: UnitDef = _content().get_unit(pair[1])
		assert_true(u != null and u.flying and u.transport_capacity >= 2, pair[1])
		assert_true(_content().get_building(pair[0]).produces.has(pair[1]), "%s doesn't build %s" % pair)


func test_infantry_fly_over_a_wall_and_get_out_beyond_it() -> void:
	var w := _world()
	var heli := _unit(w, "us_tiltrotor", 80, 120)
	var squad := _unit(w, "us_rifle_squad", 60, 120)
	_cmd(w, SimCommand.make_garrison([squad.id] as Array[int], heli.id))
	_run(w, 10 * SimWorld.TICK_RATE)
	assert_eq(squad.inside_id, heli.id, "the squad didn't board the helicopter")
	_cmd(w, SimCommand.make_move([heli.id] as Array[int], Fx.from_int(180), Fx.from_int(120)))
	_run(w, 15 * SimWorld.TICK_RATE)
	assert_true(Fx.length(squad.x - Fx.from_int(180), squad.y - Fx.from_int(120)) < Fx.from_int(8), "the squad didn't ride along")
	_cmd(w, SimCommand.make_unload(heli.id))
	_run(w, 2)
	assert_eq(squad.inside_id, 0)
	assert_true(squad.x > Fx.from_int(130), "the squad got out on the wrong side")
	assert_true(w.map.is_passable(SimMap.cell_coord(squad.x), SimMap.cell_coord(squad.y)), "it got out on blocked ground")


func test_shot_down_everyone_aboard_is_lost() -> void:
	var w := _world()
	var heli := _unit(w, "kp_transport_heli", 80, 120)
	var squad := _unit(w, "kp_infantry_squad", 60, 120)
	_cmd(w, SimCommand.make_garrison([squad.id] as Array[int], heli.id))
	_run(w, 10 * SimWorld.TICK_RATE)
	assert_eq(squad.inside_id, heli.id)
	w.apply_damage(heli, 1000000, "anti_air", 0)
	_run(w, 2)
	assert_true(squad.dead, "a passenger survived the crash")


func test_ground_transports_still_eject_their_passengers() -> void:
	var w := _world()
	var ifv := _unit(w, "us_ifv", 80, 120)
	var squad := _unit(w, "us_rifle_squad", 70, 120)
	_cmd(w, SimCommand.make_garrison([squad.id] as Array[int], ifv.id))
	_run(w, 10 * SimWorld.TICK_RATE)
	assert_eq(squad.inside_id, ifv.id)
	w.apply_damage(ifv, 1000000, "anti_tank", 0)
	_run(w, 2)
	assert_false(squad.dead, "an IFV's passenger died with it")
