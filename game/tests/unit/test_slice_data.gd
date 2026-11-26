extends TestCase
# Slice content data (P2-10): the numbers in game/data match the tables in
# docs/design/vertical-slice.md. Change both together when balancing.

const DOC: String = "../docs/design/vertical-slice.md"

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _rows() -> Array[PackedStringArray]:
	var path: String = ProjectSettings.globalize_path("res://").path_join(DOC).simplify_path()
	var out: Array[PackedStringArray] = []
	if not FileAccess.file_exists(path):
		return out
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("| `"):
			var cols := PackedStringArray()
			for c: String in line.trim_prefix("|").trim_suffix("|").split("|"):
				cols.append(c.strip_edges())
			out.append(cols)
	return out


static func _ids(cell: String) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("`([a-z_]+)`")
	for m: RegExMatch in re.search_all(cell):
		out.append(m.get_string(1))
	return out


## "1,500 / 400" -> the n-th number; "— (start)" -> -1.
static func _num(cell: String, n: int = 0) -> int:
	var parts: PackedStringArray = cell.replace(",", "").replace("−", "-").replace("+", "").split("/")
	var p: String = parts[mini(n, parts.size() - 1)].strip_edges()
	return p.to_int() if p.is_valid_int() else -1


func test_doc_tables_were_found() -> void:
	assert_true(_rows().size() >= 25, "could not read the slice tables from %s" % DOC)


func test_units_match_the_doc() -> void:
	var checked: int = 0
	for cols: PackedStringArray in _rows():
		var ids: PackedStringArray = _ids(cols[0])
		if ids.size() != 1 or not _content().units.has(ids[0]):
			continue
		var u: UnitDef = _content().get_unit(ids[0])
		assert_eq(u.cost, _num(cols[2]), "%s cost" % u.id)
		assert_eq(u.max_hp, _num(cols[3]), "%s hp" % u.id)
		assert_eq(u.armor_class, cols[4], "%s armor" % u.id)
		assert_eq(u.speed, Fx.from_ratio(_num(cols[5]), 100 * SimWorld.TICK_RATE), "%s speed" % u.id)
		_check_weapon(u, cols[6])
		checked += 1
	assert_eq(checked, 19, "every slice unit row should be checked")


func _check_weapon(u: UnitDef, cell: String) -> void:
	var re := RegEx.create_from_string("([a-z_]+) (\\d+)(?: \\(splash (\\d+) m\\))?, (\\d+) m, ([\\d.]+) s")
	var m: RegExMatch = re.search(cell)
	if m == null:
		assert_true(u.weapons.is_empty() or u.id == "us_recon_drone", "%s has a weapon the doc doesn't list" % u.id)
		return
	assert_false(u.weapons.is_empty(), "%s has no weapon but the doc lists one" % u.id)
	var w: WeaponDef = u.weapons[0]
	assert_eq(w.damage_type, m.get_string(1), "%s damage type" % u.id)
	assert_eq(w.damage, m.get_string(2).to_int(), "%s damage" % u.id)
	if m.get_string(3) != "":
		assert_eq(w.splash_radius, Fx.from_int(m.get_string(3).to_int()), "%s splash" % u.id)
	assert_eq(w.max_range, Fx.from_int(m.get_string(4).to_int()), "%s range" % u.id)
	var reload_ms: int = roundi(m.get_string(5).to_float() * 1000.0)
	assert_eq(w.reload_ticks, maxi(1, (reload_ms * SimWorld.TICK_RATE + 999) / 1000), "%s reload" % u.id)


func test_buildings_match_the_doc() -> void:
	var checked: int = 0
	for cols: PackedStringArray in _rows():
		var ids: PackedStringArray = _ids(cols[0])
		for i: int in ids.size():
			if not _content().buildings.has(ids[i]):
				continue
			var b: BuildingDef = _content().get_building(ids[i])
			var cost: int = _num(cols[1], i)
			if cost >= 0:
				assert_eq(b.cost, cost, "%s cost" % b.id)
			assert_eq(b.max_hp, _num(cols[2], i), "%s hp" % b.id)
			assert_eq(b.power, _num(cols[3], i), "%s power" % b.id)
			checked += 1
	assert_eq(checked, 16, "every slice building should be checked")
