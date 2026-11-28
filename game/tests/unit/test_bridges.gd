extends TestCase
# Bridges (P3-11): Riverside's two decks are neutral bridges. Only an attack
# order hits one; at 0 hp it collapses (units on it fall, nothing crosses)
# and any side's builders repair it for free until it opens at half health.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _riverside() -> SimWorld:
	var sc: Dictionary = MatchConfig.skirmish(_content(), "riverside", "us", 10000, false, "normal", "kp")
	return MatchSetup.build_from(_content(), sc, 5)


func _bridges(w: SimWorld) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for id: int in w.entity_ids:
		var e: SimEntity = w.entities[id]
		if e.building != null and e.building.bridge:
			out.append(e)
	return out


## The bridge whose deck covers the point (meters).
func _bridge_at(w: SimWorld, x_m: int, y_m: int) -> SimEntity:
	for b: SimEntity in _bridges(w):
		var cx: int = x_m / 2
		var cy: int = y_m / 2
		if cx >= b.building.cell_x and cx < b.building.cell_x + b.building.w \
				and cy >= b.building.cell_y and cy < b.building.cell_y + b.building.h:
			return b
	return null


func _cmd(w: SimWorld, c: SimCommand, player: int) -> void:
	c.player_id = player
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func test_riverside_has_two_neutral_walkable_bridges() -> void:
	var w := _riverside()
	var bridges: Array[SimEntity] = _bridges(w)
	assert_eq(bridges.size(), 2)
	for b: SimEntity in bridges:
		assert_eq(b.player_id, 0)
		assert_true(b.building.walkable)
		assert_eq(w.map.footprint_owner(SimMap.cell_coord(b.x), SimMap.cell_coord(b.y)), 0, "a standing bridge blocks its deck")
	assert_true(w.map.is_passable(64, 35), "the north crossing is closed")


func test_units_only_attack_a_bridge_when_ordered() -> void:
	var w := _riverside()
	var bridge: SimEntity = _bridge_at(w, 128, 70)
	var tank := _unit(w, "us_mbt", 1, 100, 70)
	_run(w, 60)
	assert_eq(bridge.hp, bridge.max_hp, "a tank shot a bridge on its own")
	_cmd(w, SimCommand.make_attack([tank.id] as Array[int], bridge.id), 1)
	_run(w, 90)
	assert_true(bridge.hp < bridge.max_hp, "an attack order didn't hit the bridge")


func test_a_collapsed_bridge_blocks_the_crossing_and_drops_units() -> void:
	var w := _riverside()
	var bridge: SimEntity = _bridge_at(w, 128, 70)
	var on_deck := _unit(w, "kp_infantry_squad", 2, 128, 70)
	var helo := _unit(w, "us_attack_heli", 1, 128, 70)
	_run(w, 1)
	w.apply_damage(bridge, 1000000, "anti_tank", 0)
	assert_false(bridge.dead, "a bridge died instead of collapsing")
	assert_true(bridge.building.collapsed)
	assert_eq(bridge.hp, 0)
	assert_true(on_deck.dead, "a squad on the deck survived the collapse")
	assert_false(helo.dead, "a helicopter over the deck fell")
	assert_false(w.map.is_passable(64, 35), "the crossing stayed open")
	assert_eq(w.apply_damage(bridge, 500, "anti_tank", 0), 0, "a collapsed bridge took more damage")
	# A tank sent across now has to go round by the south bridge.
	var tank := _unit(w, "us_mbt", 1, 100, 70)
	_cmd(w, SimCommand.make_move([tank.id] as Array[int], Fx.from_int(156), Fx.from_int(70)), 1)
	var furthest_south: int = 0
	for i: int in 90 * SimWorld.TICK_RATE:
		w.step()
		furthest_south = maxi(furthest_south, Fx.floor_to_int(tank.y))
	assert_true(Fx.length(tank.x - Fx.from_int(156), tank.y - Fx.from_int(70)) < Fx.from_int(8), "the tank never got across")
	assert_true(furthest_south > 170, "it didn't go round by the south bridge")


func test_builders_of_any_side_repair_it_for_free() -> void:
	var w := _riverside()
	var bridge: SimEntity = _bridge_at(w, 128, 70)
	w.apply_damage(bridge, 1000000, "anti_tank", 0)
	var eng := _unit(w, "kp_engineer", 2, 108, 70)
	var credits: int = w.get_player(2).credits
	_cmd(w, SimCommand.make_repair([eng.id] as Array[int], bridge.id), 2)
	_run(w, 30 * SimWorld.TICK_RATE)
	assert_true(bridge.hp > 0, "the engineer didn't repair the bridge")
	assert_true(bridge.building.collapsed, "it opened before half health")
	_run(w, 30 * SimWorld.TICK_RATE)
	assert_false(bridge.building.collapsed, "it never opened again")
	assert_true(w.map.is_passable(64, 35))
	assert_eq(w.get_player(2).credits, credits, "repairing a bridge cost credits")


func test_neutral_attack_orders_are_bridges_only() -> void:
	var w := _riverside()
	var house: SimEntity = null
	for id: int in w.entity_ids:
		if w.entities[id].def_id == "civilian_house":
			house = w.entities[id]
			break
	var tank := _unit(w, "us_mbt", 1, Fx.floor_to_int(house.x) - 20, Fx.floor_to_int(house.y))
	_run(w, 2)
	_cmd(w, SimCommand.make_attack([tank.id] as Array[int], house.id), 1)
	_run(w, 2)
	assert_true(tank.order != SimEntity.Order.ATTACK, "an attack order on a neutral house was accepted")


func _bridge_hash() -> int:
	var w := _riverside()
	var bridge: SimEntity = _bridge_at(w, 128, 186)
	var tank := _unit(w, "kp_mbt", 2, 150, 186)
	_cmd(w, SimCommand.make_attack([tank.id] as Array[int], bridge.id), 2)
	_run(w, 20 * SimWorld.TICK_RATE)
	return w.state_hash()


func test_bridges_are_deterministic() -> void:
	assert_eq(_bridge_hash(), _bridge_hash())
