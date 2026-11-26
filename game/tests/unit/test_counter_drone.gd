extends TestCase
# Counter-drone weapons (P2-02): laser, microwave cone, airburst gun, and
# splash that only hurts what a weapon can target.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _world() -> SimWorld:
	var w := SimWorld.new(9, 200, 200)
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	return w


func _spawn(w: SimWorld, def_id: String, player: int, x_m: int, y_m: int) -> SimEntity:
	return w.get_entity(w.spawn_unit(_content().get_unit(def_id), player, Fx.from_int(x_m), Fx.from_int(y_m)))


## A test unit carrying one given weapon (no unit in the slice has it yet).
func _armed(w: SimWorld, weapon_id: String, x_m: int, y_m: int) -> SimEntity:
	var def := UnitDef.new()
	def.id = "test_" + weapon_id
	def.armor_class = "light_vehicle"
	def.max_hp = 500
	def.radius = Fx.from_int(2)
	def.vision = Fx.from_int(60)
	def.weapons = [_content().get_weapon(weapon_id)]
	return w.get_entity(w.spawn_unit(def, 1, Fx.from_int(x_m), Fx.from_int(y_m)))


func _run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.step()


func test_laser_hits_drones_only() -> void:
	var w := _world()
	var laser: SimEntity = _spawn(w, "us_laser_cuas", 1, 50, 50)
	var drone: SimEntity = _spawn(w, "kp_recon_drone", 2, 80, 50)
	var tank: SimEntity = _spawn(w, "kp_mbt", 2, 70, 55)
	_run(w, 30)
	assert_eq(w.get_entity(drone.id), null, "the laser did not shoot down the drone")
	assert_eq(tank.hp, tank.max_hp, "the laser hurt a tank")
	assert_true(laser.weapons[0].targets.has("drone"))


func test_microwave_cone_hits_every_drone_inside_it() -> void:
	var w := _world()
	_armed(w, "hpm_emitter", 50, 100)
	var a: SimEntity = _spawn(w, "kp_recon_drone", 2, 70, 100)   # straight ahead
	var b: SimEntity = _spawn(w, "kp_recon_drone", 2, 72, 104)   # ~10 degrees off: inside
	var c: SimEntity = _spawn(w, "kp_recon_drone", 2, 50, 124)   # 90 degrees off: outside
	var tank: SimEntity = _spawn(w, "kp_mbt", 2, 68, 100)        # inside, but not a drone
	_run(w, 3)
	assert_true(a.hp < a.max_hp and b.hp < b.max_hp, "drones inside the cone were not hit")
	assert_eq(c.hp, c.max_hp, "a drone outside the cone was hit")
	assert_eq(tank.hp, tank.max_hp, "the microwave hurt a tank")


func test_airburst_gun_splash_hits_nearby_drones() -> void:
	var w := _world()
	_armed(w, "cuas_airburst_gun", 50, 100)
	var a: SimEntity = _spawn(w, "kp_recon_drone", 2, 75, 100)
	var b: SimEntity = _spawn(w, "kp_recon_drone", 2, 77, 101)   # 2 m from a: inside the burst
	_run(w, 8)   # vision and target acquisition take a few ticks; 1-2 shots can't kill a 50 hp drone
	assert_true(a.hp < a.max_hp and b.hp < b.max_hp, "the burst did not hit both drones")


func test_artillery_splash_does_not_hit_drones_overhead() -> void:
	var w := _world()
	var gun: SimEntity = _spawn(w, "kp_howitzer", 2, 20, 100)
	gun.vision = Fx.from_int(200)
	var tank: SimEntity = _spawn(w, "us_mbt", 1, 100, 100)
	var drone: SimEntity = _spawn(w, "us_recon_drone", 1, 101, 101)
	drone.drone.endurance = 100000
	_run(w, 200)
	assert_true(w.get_entity(tank.id) == null or tank.hp < tank.max_hp, "the howitzer never hit the tank")
	assert_eq(drone.hp, drone.max_hp, "artillery splash hurt a drone in the air")


func test_cone_weapon_must_be_instant() -> void:
	var db := ContentDb.new()
	db.load_all()
	var path: String = "user://test_bad_cone.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "test_bad_cone", "damage": 1, "damage_type": "counter_drone",
		"range_cm": 100, "reload_ms": 100, "projectile": "guided", "projectile_speed_cm_per_s": 100,
		"cone_deg": 30, "targets": ["drone"]}))
	f.close()
	db.errors.clear()
	db._load_weapon(path)
	assert_true(db.errors.size() >= 1 and db.errors[db.errors.size() - 1].contains("cone_deg"), str(db.errors))
