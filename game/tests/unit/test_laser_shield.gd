extends TestCase
# The UAE's laser shield (P3-02f): for 30 s, air-defense sites inside the
# power's area also burn down enemy shells and drones that come close.

var _db: ContentDb
var _seq: int = 0


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(103, 240, 240)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	for pid: int in [1, 2]:
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = "ae" if pid == 1 else "kp"
		p.credits = 20000
		p.rank = 3
	return w


func _cmd(w: SimWorld, c: SimCommand) -> void:
	c.player_id = 1
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)


## A powered UAE base with an air-defense site at (100, 100) m, a building
## to protect next to it, and North Korean artillery shelling that building.
func _shelled(w: SimWorld, shield: bool) -> SimEntity:
	w.spawn_building(_content().get_building("ae_power_plant"), 1, 4, 4, true)
	w.spawn_building(_content().get_building("ae_sam_site"), 1, 48, 48, true)
	var target: SimEntity = w.get_entity(w.spawn_building(_content().get_building("ae_barracks"), 1, 54, 48, true))
	var gun: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit("kp_howitzer"), 2, Fx.from_int(120), Fx.from_int(170)))
	gun.vision = Fx.from_int(120)
	if shield:
		_cmd(w, SimCommand.make_choose_power("ae_laser_shield"))
		w.step()
		_cmd(w, SimCommand.make_use_power("ae_laser_shield", Fx.from_int(100), Fx.from_int(100)))
		w.step()
	var c := SimCommand.make_attack([gun.id] as Array[int], target.id)
	c.player_id = 2
	_seq += 1
	c.seq = _seq
	c.tick = w.tick
	w.queue_command(c)
	return target


func test_the_power_is_data() -> void:
	var p: PowerDef = _content().get_power("ae_laser_shield")
	assert_eq(p.kind, "laser_shield")
	assert_eq(p.tier, 3)
	assert_eq(p.duration_ticks, 30 * SimWorld.TICK_RATE)


func test_shells_are_burned_down_near_a_shielded_site() -> void:
	var w := _world()
	var target := _shelled(w, true)
	var burned: int = 0
	for i: int in 25 * SimWorld.TICK_RATE:
		w.step()
		for ev: Dictionary in w.events:
			if ev.get("type") == "intercepted" and int(ev.get("id", -1)) == 0:
				burned += 1
	assert_true(burned > 0, "no shell was burned down")
	assert_eq(target.hp, target.max_hp, "a shell got through the shield")


func test_without_the_shield_the_shells_land() -> void:
	var w := _world()
	var target := _shelled(w, false)
	for i: int in 25 * SimWorld.TICK_RATE:
		w.step()
	assert_true(target.hp < target.max_hp, "the howitzer never hit (the test setup is wrong)")


func test_the_shield_wears_off() -> void:
	var w := _world()
	var target := _shelled(w, true)
	for i: int in 70 * SimWorld.TICK_RATE:
		w.step()
	assert_true(target.hp < target.max_hp, "the shield lasted past 30 s")


func test_drones_near_a_shielded_site_burn() -> void:
	var w := _world()
	_shelled(w, true)
	var drone: SimEntity = w.get_entity(w.spawn_unit(_content().get_unit("kp_recon_drone"), 2, Fx.from_int(100), Fx.from_int(110)))
	drone.weapons.clear()
	for i: int in 3 * SimWorld.TICK_RATE:
		w.step()
	assert_true(drone.dead or drone.hp < drone.max_hp, "a drone hovered next to a shielded site unharmed")


func _shield_hash() -> int:
	var w := _world()
	_shelled(w, true)
	for i: int in 20 * SimWorld.TICK_RATE:
		w.step()
	return w.state_hash()


func test_the_shield_is_deterministic() -> void:
	assert_eq(_shield_hash(), _shield_hash())
