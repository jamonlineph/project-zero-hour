extends TestCase
# Mods (P3-17): folders with an index.json load on top of the game's data.
# A file with an existing id replaces it; a new id adds content; mistakes
# are reported like the game's own; the content hash changes.

const ROOT: String = "user://test_mods"


func _write(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func _clean() -> void:
	_rm(ROOT)


func _rm(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d: String in DirAccess.get_directories_at(dir):
		_rm(dir.path_join(d))
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## "heavier_tanks" makes America's tank cost 1500 and adds a new unit.
func _make_mod() -> void:
	_clean()
	var base := ContentDb.new()
	base.load_all()
	var tank: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units/us_mbt.json"))
	tank["cost"] = 1500
	var dir: String = ROOT.path_join("heavier_tanks")
	_write(dir.path_join("units/us_mbt.json"), tank)
	var scout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units/us_rifle_squad.json"))
	scout["id"] = "mod_scout_team"
	scout["name"] = "Scout Team"
	_write(dir.path_join("units/mod_scout_team.json"), scout)
	_write(dir.path_join("index.json"), {"units": ["units/us_mbt.json", "units/mod_scout_team.json"]})
	_write(dir.path_join("mod.json"), {"name": "Heavier tanks", "version": "1.0"})


func test_mods_are_found_in_name_order() -> void:
	_make_mod()
	_write(ROOT.path_join("a_first/index.json"), {})
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("not_a_mod"))
	var dirs: PackedStringArray = ModLoader.mod_dirs(ROOT)
	assert_eq(dirs, PackedStringArray([ROOT.path_join("a_first"), ROOT.path_join("heavier_tanks")]))
	assert_eq(ModLoader.info(dirs[1])["name"], "Heavier tanks")
	_clean()


func test_a_mod_replaces_and_adds_content() -> void:
	_make_mod()
	var base := ContentDb.new()
	assert_true(base.load_all())
	var modded := ContentDb.new()
	assert_true(modded.load_all(ContentDb.INDEX_PATH, ModLoader.mod_dirs(ROOT)), ", ".join(modded.errors))
	assert_eq(modded.get_unit("us_mbt").cost, 1500, "the mod didn't replace the tank")
	assert_true(modded.get_unit("mod_scout_team") != null, "the mod didn't add its unit")
	assert_eq(modded.units.size(), base.units.size() + 1)
	assert_eq(modded.mods, PackedStringArray(["heavier_tanks"]))
	assert_true(modded.content_hash != base.content_hash, "a mod didn't change the content hash")
	_clean()


func test_a_broken_mod_is_reported() -> void:
	_clean()
	var dir: String = ROOT.path_join("broken")
	var bad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units/us_mbt.json"))
	bad["weapons"] = ["no_such_weapon"]
	_write(dir.path_join("units/us_mbt.json"), bad)
	_write(dir.path_join("index.json"), {"units": ["units/us_mbt.json"]})
	var db := ContentDb.new()
	assert_false(db.load_all(ContentDb.INDEX_PATH, ModLoader.mod_dirs(ROOT)), "a broken mod loaded cleanly")
	var found: bool = false
	for e: String in db.errors:
		found = found or e.contains("no_such_weapon")
	assert_true(found, "the error doesn't name the problem: %s" % ", ".join(db.errors))
	_clean()


func test_no_mods_means_the_plain_game() -> void:
	_clean()
	assert_eq(ModLoader.mod_dirs(ROOT).size(), 0)
	var a := ContentDb.new()
	a.load_all()
	var b := ContentDb.new()
	b.load_all(ContentDb.INDEX_PATH, ModLoader.mod_dirs(ROOT))
	assert_eq(a.content_hash, b.content_hash)
