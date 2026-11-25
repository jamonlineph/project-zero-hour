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
