extends TestCase


func test_all_content_loads_without_errors() -> void:
	var db := ContentDb.new()
	var ok: bool = db.load_all()
	assert_true(ok, "errors: %s" % ", ".join(db.errors))
	assert_true(db.units.size() > 0, "no units loaded")


func test_every_unit_file_is_listed_in_index() -> void:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ContentDb.INDEX_PATH))
	var listed: Array = index.get("units", [])
	for file: String in DirAccess.get_files_at("res://data/units/"):
		if file.ends_with(".json"):
			assert_true(listed.has("res://data/units/" + file), "%s is missing from data/index.json" % file)


func test_every_map_file_is_listed_in_index() -> void:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ContentDb.INDEX_PATH))
	var listed: Array = index.get("maps", [])
	# Maps are folders (P1-30): every folder's map.json must be listed.
	var folders: PackedStringArray = DirAccess.get_directories_at("res://data/maps/")
	assert_true(folders.size() > 0, "no map folders found")
	for folder: String in folders:
		var file: String = "res://data/maps/%s/map.json" % folder
		assert_true(FileAccess.file_exists(file), "%s has no map.json" % folder)
		assert_true(listed.has(file), "%s is missing from data/index.json" % file)
	for file: String in DirAccess.get_files_at("res://data/maps/"):
		assert_false(file.ends_with(".json"), "%s: maps are folders now (data/maps/<id>/map.json)" % file)


func test_units_have_sane_values() -> void:
	var db := ContentDb.new()
	db.load_all()
	for id: String in db.units:
		var u: UnitDef = db.units[id]
		assert_true(u.max_hp > 0, id)
		assert_true(u.radius > 0, id)
		assert_true(u.speed >= 0, id)
		assert_true(u.faction in ["us", "cn", "ru", "irr"], "%s has unknown faction %s" % [id, u.faction])


func test_speed_converts_to_meters_per_tick() -> void:
	var db := ContentDb.new()
	db.load_all()
	var tank: UnitDef = db.get_unit("us_mbt")
	assert_true(tank != null, "us_mbt missing")
	# 750 cm/s at 15 ticks/s = 0.5 m per tick.
	assert_eq(tank.speed, Fx.from_ratio(1, 2))


func test_every_unit_and_building_has_a_model_and_icon() -> void:
	# P1-34: every playable id ships with a Blender placeholder model and icon.
	var db := ContentDb.new()
	db.load_all()
	for id: String in db.units:
		var u: UnitDef = db.units[id]
		assert_true(ResourceLoader.exists(u.model_path), "%s: missing model %s" % [id, u.model_path])
		assert_true(ResourceLoader.exists(u.icon_path), "%s: missing icon %s" % [id, u.icon_path])
	for id: String in db.buildings:
		var b: BuildingDef = db.buildings[id]
		assert_true(ResourceLoader.exists(b.model_path), "%s: missing model %s" % [id, b.model_path])
		assert_true(ResourceLoader.exists(b.icon_path), "%s: missing icon %s" % [id, b.icon_path])


func test_vertical_slice_roster_is_complete() -> void:
	# docs/design/vertical-slice.md lists these ids; each needs data.
	var units: PackedStringArray = [
		"us_engineer", "us_logistics_truck", "us_rifle_squad", "us_at_team", "us_ifv", "us_mbt",
		"us_rocket_artillery", "us_laser_cuas", "us_recon_drone",
		"ru_engineer", "ru_logistics_truck", "ru_motor_rifle_squad", "ru_at_team", "ru_ifv", "ru_mbt",
		"ru_howitzer", "ru_ew_vehicle", "ru_recon_drone", "ru_loitering_team"]
	var buildings: PackedStringArray = [
		"us_command_hq", "us_microreactor", "us_barracks", "us_logistics_hub", "us_vehicle_depot",
		"us_drone_center", "us_bunker", "us_sam_site",
		"ru_command_hq", "ru_power_plant", "ru_barracks", "ru_logistics_hub", "ru_vehicle_plant",
		"ru_drone_launch_site", "ru_trench_line", "ru_sam_site"]
	var db := ContentDb.new()
	db.load_all()
	for id: String in units:
		assert_true(db.units.has(id), "missing unit data: " + id)
	for id: String in buildings:
		assert_true(db.buildings.has(id), "missing building data: " + id)
	# Everything a building produces must be a known unit.
	for id: String in db.buildings:
		for p: String in (db.buildings[id] as BuildingDef).produces:
			assert_true(db.units.has(p), "%s produces unknown unit %s" % [id, p])
