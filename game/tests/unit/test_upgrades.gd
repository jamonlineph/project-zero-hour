extends TestCase
# Upgrades (P2-05): research, per-unit kits, effects, requirements.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world(credits: int = 10000) -> SimWorld:
	var w := SimWorld.new(5, 200, 200)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.content = _content()
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "us" if pid == 1 else "kp"
		p.credits = credits
	return w


func _building(w: SimWorld, def_id: String, player: int, cx: int, cy: int) -> SimEntity:
	return w.get_entity(w.spawn_building(_content().get_building(def_id), player, cx, cy, true))


func _unit(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func _command(w: SimWorld, c: SimCommand, player: int = 1) -> void:
	c.player_id = player
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func _power(w: SimWorld, player: int) -> void:
	_building(w, "us_microreactor" if player == 1 else "kp_power_plant", player, 80, 80)


func test_upgrades_load_with_valid_references() -> void:
	assert_eq(_content().upgrades.size(), 6)
	var u: UpgradeDef = _content().get_upgrade("us_composite_armor")
	assert_eq(u.scope, "global")
	assert_eq(u.researched_at, "us_vehicle_depot")
	assert_eq(u.effects["max_hp_percent"], 15)
	assert_eq(_content().get_upgrade("kp_ifv_cage_kit").attachment, "upg_cage")


func test_research_takes_time_costs_credits_and_upgrades_existing_and_new_units() -> void:
	var w := _world()
	_power(w, 1)
	var depot: SimEntity = _building(w, "us_vehicle_depot", 1, 20, 20)
	var tank: SimEntity = _unit(w, "us_mbt", 1, 100, 100)
	var hp_before: int = tank.max_hp
	_command(w, SimCommand.make_research(depot.id, "us_composite_armor"))
	w.step()
	assert_eq(depot.building.research_id, "us_composite_armor")
	assert_eq(w.get_player(1).credits, 10000 - 1500)
	var def: UpgradeDef = _content().get_upgrade("us_composite_armor")
	_run(w, def.research_ticks - 2)
	assert_eq(tank.max_hp, hp_before, "the upgrade applied before research finished")
	_run(w, 3)
	assert_true(w.get_player(1).upgrades.has("us_composite_armor"))
	assert_eq(tank.max_hp, hp_before * 115 / 100)
	var fresh: SimEntity = _unit(w, "us_mbt", 1, 110, 100)
	assert_eq(fresh.max_hp, tank.max_hp, "a tank built after research did not get the upgrade")
	assert_eq(fresh.hp, fresh.max_hp)


func test_research_rules() -> void:
	var w := _world(1000)
	_power(w, 1)
	var depot: SimEntity = _building(w, "us_vehicle_depot", 1, 20, 20)
	_command(w, SimCommand.make_research(depot.id, "us_composite_armor"))   # costs 1500
	w.step()
	assert_eq(depot.building.research_id, "", "researched without enough credits")
	w.get_player(1).credits = 10000
	var hub: SimEntity = _building(w, "us_logistics_hub", 1, 40, 20)
	_command(w, SimCommand.make_research(hub.id, "us_composite_armor"))      # wrong building
	_command(w, SimCommand.make_research(hub.id, "us_self_driving_trucks"))  # needs rank 5
	_command(w, SimCommand.make_research(depot.id, "kp_reactive_armor"))     # other faction
	w.step()
	assert_eq(hub.building.research_id, "")
	assert_eq(depot.building.research_id, "")
	w.get_player(1).rank = 5
	_command(w, SimCommand.make_research(hub.id, "us_self_driving_trucks"))
	w.step()
	assert_eq(hub.building.research_id, "us_self_driving_trucks")


func test_low_power_halves_research_speed() -> void:
	var w := _world()
	var depot: SimEntity = _building(w, "us_vehicle_depot", 1, 20, 20)   # no power plant: low power
	_command(w, SimCommand.make_research(depot.id, "us_composite_armor"))
	_run(w, 21)
	assert_true(w.get_player(1).low_power())
	assert_true(depot.building.research_progress <= 11, "research ran at full speed on low power")


func test_per_unit_kits_apply_only_to_chosen_units_and_charge_each() -> void:
	var w := _world()
	_power(w, 1)
	_building(w, "us_vehicle_depot", 1, 20, 20)
	var a: SimEntity = _unit(w, "us_ifv", 1, 100, 100)
	var b: SimEntity = _unit(w, "us_ifv", 1, 110, 100)
	var c: SimEntity = _unit(w, "us_ifv", 1, 120, 100)
	var tank: SimEntity = _unit(w, "us_mbt", 1, 130, 100)
	_command(w, SimCommand.make_upgrade_unit([a.id, b.id, tank.id], "us_ifv_aps_kit"))
	w.step()
	assert_eq(a.aps_charges, 2)
	assert_eq(b.aps_charges, 2)
	assert_eq(c.aps_charges, 0, "an unselected IFV got the kit")
	assert_eq(tank.aps_charges, 0, "the kit went on a unit it doesn't apply to")
	assert_eq(w.get_player(1).credits, 10000 - 600)
	_command(w, SimCommand.make_upgrade_unit([a.id], "us_ifv_aps_kit"))
	w.step()
	assert_eq(a.aps_charges, 2, "the same kit was bought twice")
	assert_true(Upgrades.has_upgrade(w, a, "us_ifv_aps_kit"))


func test_kits_need_their_building() -> void:
	var w := _world()
	var ifv: SimEntity = _unit(w, "kp_ifv", 2, 100, 100)
	_command(w, SimCommand.make_upgrade_unit([ifv.id], "kp_ifv_cage_kit"), 2)
	w.step()
	assert_eq(ifv.cage_hits, 0, "bought a kit without a vehicle plant")
	_building(w, "kp_vehicle_plant", 2, 20, 20)
	_command(w, SimCommand.make_upgrade_unit([ifv.id], "kp_ifv_cage_kit"), 2)
	w.step()
	assert_eq(ifv.cage_hits, 2)


func test_range_upgrade_extends_weapons() -> void:
	var w := _world()
	w.get_player(2).upgrades.append("kp_extended_range_shells")
	var gun: SimEntity = _unit(w, "kp_howitzer", 2, 100, 100)
	assert_eq(gun.weapons[0].max_range, (_content().get_weapon("kp_howitzer_152").max_range * 115) / 100)


func test_commands_round_trip() -> void:
	var r := SimCommand.from_dict(SimCommand.make_research(7, "us_composite_armor").to_dict())
	assert_eq(r.type, SimCommand.Type.RESEARCH)
	assert_eq(r.def_id, "us_composite_armor")
	var u := SimCommand.from_dict(SimCommand.make_upgrade_unit([3], "us_ifv_aps_kit").to_dict())
	assert_eq(u.type, SimCommand.Type.UPGRADE_UNIT)


func _upgrade_hash() -> int:
	var w := _world()
	_power(w, 1)
	var depot: SimEntity = _building(w, "us_vehicle_depot", 1, 20, 20)
	var ifv: SimEntity = _unit(w, "us_ifv", 1, 100, 100)
	_command(w, SimCommand.make_research(depot.id, "us_composite_armor"))
	_command(w, SimCommand.make_upgrade_unit([ifv.id], "us_ifv_aps_kit"))
	_run(w, 800)
	return w.state_hash()


func test_upgrades_are_deterministic() -> void:
	assert_eq(_upgrade_hash(), _upgrade_hash())
