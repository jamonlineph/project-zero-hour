extends TestCase
# UAE procurement (P3-02e): orders at the procurement office cost 30% more,
# use no factory time, and a cargo flight drops them off 30 s later. Shot
# down on the way, the order is lost. Emergency procurement halves the wait.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(101, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "ae" if pid == 1 else "kp"
		p.credits = 20000
		p.rank = 1
	return w


func _cmd(w: SimWorld, c: SimCommand, player: int = 1) -> void:
	c.player_id = player
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _office(w: SimWorld) -> SimEntity:
	w.spawn_building(_content().get_building("ae_power_plant"), 1, 4, 4, true)
	w.spawn_building(_content().get_building("ae_vehicle_depot"), 1, 4, 40, true)
	return w.get_entity(w.spawn_building(_content().get_building("ae_procurement_office"), 1, 30, 20, true))


func _count(w: SimWorld, def_id: String) -> int:
	var n: int = 0
	for id: int in w.entity_ids:
		if w.entities[id].def_id == def_id and not w.entities[id].dead:
			n += 1
	return n


func test_the_office_is_data() -> void:
	var b: BuildingDef = _content().get_building("ae_procurement_office")
	assert_eq(b.procurement_percent, 30)
	assert_eq(b.delivery_ticks, 30 * SimWorld.TICK_RATE)
	assert_true(_content().get_strike(b.delivery_strike) != null)
	assert_true(AiPlayer.from_preset(_content(), "ae_default", 1).build_order.has("ae_procurement_office"))


func test_an_order_costs_more_and_is_flown_in() -> void:
	var w := _world()
	var office := _office(w)
	var tank: UnitDef = _content().get_unit("ae_mbt")
	_cmd(w, SimCommand.make_produce(office.id, "ae_mbt"))
	w.step()
	assert_eq(w.get_player(1).credits, 20000 - (tank.cost * 130) / 100, "the premium wasn't charged")
	for i: int in 30 * SimWorld.TICK_RATE - 2:
		w.step()
	assert_eq(_count(w, "ae_mbt"), 0, "the tank came before 30 s")
	var flights: int = _count(w, "ae_cargo_flight")
	for i: int in 30 * SimWorld.TICK_RATE:
		w.step()
		flights = maxi(flights, _count(w, "ae_cargo_flight"))
	assert_eq(flights, 1, "no cargo flight came")
	assert_eq(_count(w, "ae_mbt"), 1, "the tank wasn't dropped off")


func test_a_flight_shot_down_loses_the_order() -> void:
	var w := _world()
	var office := _office(w)
	_cmd(w, SimCommand.make_produce(office.id, "ae_mbt"))
	var shot: bool = false
	for i: int in 60 * SimWorld.TICK_RATE:
		w.step()
		for id: int in w.entity_ids:
			var e: SimEntity = w.entities[id]
			if e.def_id == "ae_cargo_flight" and not shot:
				w.apply_damage(e, 1000000, "anti_air", 0)
				shot = true
	assert_true(shot)
	assert_eq(_count(w, "ae_mbt"), 0, "a downed flight still delivered")


func test_cancelling_refunds_the_full_price() -> void:
	var w := _world()
	var office := _office(w)
	_cmd(w, SimCommand.make_produce(office.id, "ae_mbt"))
	w.step()
	var c := SimCommand.make_cancel(office.id, 0)
	_cmd(w, c)
	w.step()
	assert_eq(w.get_player(1).credits, 20000)


func test_emergency_procurement_halves_the_wait() -> void:
	var w := _world()
	var office := _office(w)
	_cmd(w, SimCommand.make_choose_power("ae_emergency_procurement"))
	w.step()
	_cmd(w, SimCommand.make_produce(office.id, "ae_mbt"))
	_cmd(w, SimCommand.make_use_power("ae_emergency_procurement", 0, 0))
	w.step()
	assert_true(w.get_player(1).procurement_rush)
	var launched: int = -1
	for i: int in 30 * SimWorld.TICK_RATE:
		w.step()
		if launched < 0 and _count(w, "ae_cargo_flight") > 0:
			launched = i
	assert_true(launched > 0 and launched <= 16 * SimWorld.TICK_RATE, "the rushed flight left at tick %d" % launched)
	assert_false(w.get_player(1).procurement_rush, "the rush wasn't used up")


func _proc_hash() -> int:
	var w := _world()
	var office := _office(w)
	_cmd(w, SimCommand.make_produce(office.id, "ae_mbt"))
	_cmd(w, SimCommand.make_produce(office.id, "ae_ifv"))
	for i: int in 90 * SimWorld.TICK_RATE:
		w.step()
	return w.state_hash()


func test_procurement_is_deterministic() -> void:
	assert_eq(_proc_hash(), _proc_hash())
