extends TestCase
# Superweapons (P3-03): one per faction, rank 3, limit 1, a 4-minute charge
# that everyone can see, then interceptable strikes anywhere on the map.

var _db: ContentDb
var _seq: int = 0
const SITES: Dictionary = {"us": "us_hypersonic_battery", "ae": "ae_strike_package",
	"kp": "kp_heavy_missile_site", "eu": "eu_cruise_battery"}


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(53, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "kp" if pid == 1 else "us"
		p.credits = 20000
		p.rank = 3
	return w


func _site(w: SimWorld) -> SimEntity:
	return w.get_entity(w.spawn_building(_content().get_building("kp_heavy_missile_site"), 1, 10, 10, true))


func _fire(w: SimWorld, site: SimEntity, x_m: int, y_m: int) -> void:
	var c := SimCommand.make_use_ability([site.id], "kp_heavy_missile", Fx.from_int(x_m), Fx.from_int(y_m))
	c.player_id = 1
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)
	w.step()


func _strikes(w: SimWorld) -> int:
	var n: int = 0
	for id: int in w.entity_ids:
		if w.entities[id].strike != null and w.entities[id].player_id == 1:
			n += 1
	return n


func test_every_faction_has_one_superweapon() -> void:
	for f: String in MatchConfig.FACTIONS:
		var def: BuildingDef = _content().get_building(SITES[f])
		assert_true(def != null and def.faction == f, "%s has no superweapon building" % f)
		assert_eq(def.limit, 1)
		assert_eq(def.requires_rank, 3)
		assert_eq(def.cost, 5000)
		assert_eq(def.abilities.size(), 1)
		assert_eq(def.abilities[0].kind, "superweapon")
		assert_eq(def.abilities[0].cooldown_ticks, 240 * SimWorld.TICK_RATE, "%s: the charge should be 4 minutes" % f)
		assert_true(_content().strikes.has(def.abilities[0].strike_id), "%s: missing strike" % f)
		var ai: AiPlayer = AiPlayer.from_preset(_content(), f + "_default", 1)
		assert_eq(ai.superweapon, SITES[f], "%s's AI doesn't know its superweapon" % f)


func test_rank_and_limit_gate_building_it() -> void:
	var w := _world()
	var def: BuildingDef = _content().get_building("kp_heavy_missile_site")
	w.spawn_building(_content().get_building("kp_vehicle_plant"), 1, 60, 60, true)
	w.get_player(1).rank = 2
	assert_eq(BaseCommands.blocker(w, 1, def), "needs commander rank 3")
	w.get_player(1).rank = 3
	assert_eq(BaseCommands.blocker(w, 1, def), "")
	_site(w)
	assert_eq(BaseCommands.blocker(w, 1, def), "only 1 allowed")


func test_it_charges_then_strikes_anywhere_then_charges_again() -> void:
	var w := _world()
	var site := _site(w)
	assert_eq(int(site.ability_ready["kp_heavy_missile"]), 240 * SimWorld.TICK_RATE, "the charge didn't start")
	_fire(w, site, 220, 220)
	assert_eq(_strikes(w), 0, "it fired before it was charged")
	for i: int in 240 * SimWorld.TICK_RATE:
		w.step()
	_fire(w, site, 220, 220)   # far away and unseen: superweapons don't need sight
	assert_eq(_strikes(w), 1, "one heavy missile")
	assert_eq(int(site.ability_ready["kp_heavy_missile"]), w.tick - 1 + 240 * SimWorld.TICK_RATE, "the charge didn't restart")


func test_a_disabled_site_cannot_fire() -> void:
	var w := _world()
	var site := _site(w)
	site.ability_ready["kp_heavy_missile"] = 0
	site.building.disabled_until = w.tick + 100
	_fire(w, site, 220, 220)
	assert_eq(_strikes(w), 0)


func test_everyone_sees_the_countdown() -> void:
	var w := _world()
	_site(w)
	var timers := SuperweaponTimers.new()
	timers.refresh(w)
	assert_true(timers.text.contains("North Korea Heavy Missile  4:00"), "countdown text: '%s'" % timers.text)
	timers.free()


func test_the_ai_fires_a_charged_superweapon() -> void:
	var w := _world()
	var site := _site(w)
	assert_false(AiTactics.superweapon_ready(w, [site]))
	site.ability_ready["kp_heavy_missile"] = 0
	assert_true(AiTactics.superweapon_ready(w, [site]))
	var target: SimEntity = w.get_entity(w.spawn_building(_content().get_building("us_barracks"), 2, 100, 100, true))
	var cmds: Array[SimCommand] = []
	AiTactics.fire_superweapons(w, [site], target, cmds)
	assert_eq(cmds.size(), 1)
	assert_eq(cmds[0].type, SimCommand.Type.USE_ABILITY)
	assert_eq(cmds[0].target_x, target.x)
