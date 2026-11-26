extends TestCase
# Kill chain (P2-04): long-range weapons need a spotter beyond their own sight.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(13, 256, 256)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	w.content = _content()
	return w


func _spawn(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


func _fired(w: SimWorld, shooter: SimEntity, ticks: int) -> int:
	var n: int = 0
	for i: int in ticks:
		w.step()
		for ev: Dictionary in w.events:
			if ev["type"] == "fired" and ev["attacker"] == shooter.id:
				n += 1
	return n


## A target 100 m away, seen by a friendly tank (team vision) but beyond the
## rocket launcher's own 40 m sight.
func _setup(w: SimWorld) -> Array[SimEntity]:
	var launcher: SimEntity = _spawn(w, "us_rocket_artillery", 1, 30, 128)
	var target: SimEntity = _spawn(w, "kp_mbt", 2, 130, 128)
	target.weapons.clear()
	target.max_hp = 1000000
	target.hp = 1000000
	var watcher: SimEntity = _spawn(w, "us_mbt", 1, 100, 160)   # sees the target, isn't a spotter
	watcher.weapons.clear()
	return [launcher, target]


func test_data_marks_spotters_and_kill_chain_weapons() -> void:
	assert_true(_content().get_weapon("us_rocket_pod").needs_spotter)
	assert_true(_content().get_unit("us_recon_drone").spotter)
	assert_false(_content().get_weapon("tank_cannon_120").needs_spotter)


func test_no_spotter_no_long_range_fire() -> void:
	var w := _world()
	var units: Array[SimEntity] = _setup(w)
	assert_eq(_fired(w, units[0], 300), 0, "fired at a target only a non-spotter could see")


func test_spotted_targets_can_be_hit_from_far_away() -> void:
	var w := _world()
	var units: Array[SimEntity] = _setup(w)
	var drone: SimEntity = _spawn(w, "us_recon_drone", 1, 125, 120)
	drone.drone.endurance = 100000
	assert_true(_fired(w, units[0], 300) > 0, "did not fire at a spotted target")


func test_targets_in_own_sight_need_no_spotter() -> void:
	var w := _world()
	var launcher: SimEntity = _spawn(w, "us_rocket_artillery", 1, 30, 128)
	var target: SimEntity = _spawn(w, "kp_mbt", 2, 60, 128)   # 30 m: inside its own sight, beyond min range
	target.weapons.clear()
	assert_true(_fired(w, launcher, 300) > 0)


func test_jammed_spotters_do_not_count() -> void:
	var w := _world()
	var units: Array[SimEntity] = _setup(w)
	var drone: SimEntity = _spawn(w, "us_recon_drone", 1, 125, 120)
	drone.drone.endurance = 100000
	_spawn(w, "kp_ew_vehicle", 2, 125, 122).weapons.clear()   # right under the drone
	assert_eq(_fired(w, units[0], 300), 0, "fired using a jammed spotter")


func test_guided_shot_loses_guidance_when_the_spotter_dies() -> void:
	var w := _world()
	var units: Array[SimEntity] = _setup(w)
	var drone: SimEntity = _spawn(w, "us_recon_drone", 1, 125, 120)
	drone.drone.endurance = 100000
	var lost: bool = false
	var killed: bool = false
	for i: int in 400:
		w.step()
		if not killed and not w.projectiles.is_empty():
			w.apply_damage(drone, 1000000, "counter_drone", 0)   # spotter shot down mid-flight
			killed = true
		for ev: Dictionary in w.events:
			if ev["type"] == "lost_guidance":
				lost = true
		if lost:
			break
	assert_true(killed, "no rocket was fired")
	assert_true(lost, "the rocket kept its guidance after the spotter died")


func _chain_hash() -> int:
	var w := _world()
	var units: Array[SimEntity] = _setup(w)
	_spawn(w, "us_rocket_artillery", 1, 30, 100)
	var drone: SimEntity = _spawn(w, "us_recon_drone", 1, 120, 120)
	drone.drone.endurance = 600
	units[1].weapons.clear()
	for i: int in 700:
		w.step()
	return w.state_hash()


func test_kill_chain_is_deterministic() -> void:
	assert_eq(_chain_hash(), _chain_hash())
