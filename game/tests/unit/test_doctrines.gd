extends TestCase
# EU battlegroup doctrines (P3-12b): at rank 1 the EU picks one of three
# doctrines. Each unlocks one unit and grants a passive upgrade; choosing one
# rules the other two out for the match.

const DOCTRINES: Array[String] = ["eu_doctrine_heavy_armor", "eu_doctrine_air_mobile", "eu_doctrine_air_defense"]

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(rank: int = 3) -> SimWorld:
	var w := SimWorld.new(83, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "eu" if pid == 1 else "kp"
		p.rank = rank
		p.credits = 20000
	return w


func _cmd(w: SimWorld, c: SimCommand) -> void:
	c.player_id = 1
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _choose(w: SimWorld, power: String) -> void:
	_cmd(w, SimCommand.make_choose_power(power))
	w.step()


func _unit(w: SimWorld, def_id: String) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), 1, Fx.from_int(100), Fx.from_int(100)))


func test_the_doctrines_are_data() -> void:
	for id: String in DOCTRINES:
		var p: PowerDef = _content().get_power(id)
		assert_true(p != null, id)
		assert_eq(p.faction, "eu")
		assert_eq(p.tier, 1, "%s should open at rank 1" % id)
		assert_eq(p.group, "doctrine")
		var unit: UnitDef = _content().get_unit(p.unit_id)
		assert_true(unit != null and unit.requires_unlock == id, "%s unlocks no unit" % id)
		var up: UpgradeDef = _content().get_upgrade(p.grants_upgrade)
		assert_true(up != null and up.granted, "%s grants no upgrade" % id)
		var built: bool = false
		for bid: String in ["eu_barracks", "eu_vehicle_works"]:
			built = built or _content().get_building(bid).produces.has(unit.id)
		assert_true(built, "nothing builds %s" % unit.id)


func test_one_doctrine_rules_out_the_others() -> void:
	var w := _world(3)
	_choose(w, "eu_doctrine_air_mobile")
	_choose(w, "eu_doctrine_heavy_armor")
	_choose(w, "eu_doctrine_air_defense")
	var p: SimPlayer = w.get_player(1)
	assert_true(p.powers.has("eu_doctrine_air_mobile"))
	assert_false(p.powers.has("eu_doctrine_heavy_armor"), "a second doctrine was chosen")
	assert_false(p.powers.has("eu_doctrine_air_defense"))
	assert_eq(CommanderPowers.points(p), 2, "a refused doctrine spent a point")
	_choose(w, "eu_field_repair")
	assert_true(p.powers.has("eu_field_repair"), "other powers stay open")


func test_the_rank_3_unlock_allows_a_second_doctrine() -> void:
	var w := _world(4)
	_choose(w, "eu_doctrine_heavy_armor")
	_choose(w, "eu_doctrine_air_mobile")
	var p: SimPlayer = w.get_player(1)
	assert_false(p.powers.has("eu_doctrine_air_mobile"), "a second doctrine without the unlock")
	_choose(w, "eu_unlock_second_doctrine")
	_choose(w, "eu_doctrine_air_mobile")
	assert_true(p.powers.has("eu_doctrine_air_mobile"), "the unlock didn't allow a second doctrine")
	assert_true(p.upgrades.has("eu_air_mobile_doctrine"), "the second doctrine's bonus wasn't granted")
	_choose(w, "eu_doctrine_air_defense")
	assert_false(p.powers.has("eu_doctrine_air_defense"), "a third doctrine was allowed")


func test_a_doctrine_unlocks_its_unit() -> void:
	var w := _world(1)
	var works: SimEntity = w.get_entity(w.spawn_building(_content().get_building("eu_vehicle_works"), 1, 20, 20, true))
	_cmd(w, SimCommand.make_produce(works.id, "eu_heavy_mbt"))
	w.step()
	assert_eq(works.building.queue.size(), 0, "a locked unit was queued")
	_choose(w, "eu_doctrine_heavy_armor")
	_cmd(w, SimCommand.make_produce(works.id, "eu_heavy_mbt"))
	w.step()
	assert_eq(works.building.queue.size(), 1, "the unlocked unit couldn't be queued")


func test_the_bonus_applies_to_old_and_new_units() -> void:
	var w := _world(1)
	var old_tank := _unit(w, "eu_mbt")
	var base_hp: int = old_tank.max_hp
	var squad_speed: int = _unit(w, "eu_rifle_squad").mover.speed
	_choose(w, "eu_doctrine_heavy_armor")
	assert_true(w.get_player(1).upgrades.has("eu_heavy_armor_doctrine"))
	assert_eq(old_tank.max_hp, base_hp * 110 / 100, "the tank on the field didn't get tougher")
	var new_tank := _unit(w, "eu_mbt")
	assert_eq(new_tank.max_hp, base_hp * 110 / 100, "a new tank didn't get the bonus")
	assert_eq(_unit(w, "eu_rifle_squad").mover.speed, squad_speed, "heavy armor sped up infantry")
	var w2 := _world(1)
	var sam_range: int = _unit(w2, "eu_shorad").weapons[0].max_range
	_choose(w2, "eu_doctrine_air_defense")
	assert_true(_unit(w2, "eu_shorad").weapons[0].max_range > sam_range, "air defense didn't reach further")


func test_the_ai_skips_units_it_has_not_unlocked() -> void:
	var w := _world(0)
	w.spawn_building(_content().get_building("eu_power_station"), 1, 4, 4, true)
	var works: SimEntity = w.get_entity(w.spawn_building(_content().get_building("eu_vehicle_works"), 1, 20, 20, true))
	var ai: AiPlayer = AiPlayer.from_preset(_content(), "eu_default", 1)
	ai.unit_mix = {"eu_heavy_mbt": 5, "eu_mbt": 1}
	ai._seed(w)
	var cmds: Array[SimCommand] = []
	var army: Array[SimEntity] = []
	AiProduction.produce(w, ai, army, [works] as Array[SimEntity], cmds, 0)
	for c: SimCommand in cmds:
		assert_true(c.def_id != "eu_heavy_mbt", "the AI ordered a locked unit")
	assert_true(cmds.size() > 0 and cmds[0].target_entity == works.id, "the AI left the factory idle")


func _doctrine_hash() -> int:
	var w := _world(2)
	_unit(w, "eu_mbt")
	_choose(w, "eu_doctrine_heavy_armor")
	_choose(w, "eu_doctrine_air_mobile")
	for i: int in 30:
		w.step()
	return w.state_hash()


func test_doctrines_are_deterministic() -> void:
	assert_eq(_doctrine_hash(), _doctrine_hash())
