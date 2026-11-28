class_name MapLoader
extends RefCounted
## Loads map folders into ContentDb (split out of ContentDb in P2-11d). See
## docs/design/maps-and-modes.md for the format.


static func load_map(db: ContentDb, path: String) -> void:
	var parsed: Variant = db.read_json(path)
	if not parsed is Dictionary:
		db.errors.append("%s: expected a JSON object" % path)
		return
	var src: Dictionary = parsed
	var m := MapDef.new()
	m.id = db.req_string(src, "id", path)
	m.name = db.req_string(src, "name", path)
	m.width_m = db.req_int(src, "width_m", path, 16)
	m.height_m = db.req_int(src, "height_m", path, 16)
	var obstacles: Variant = src.get("obstacles_m", [])
	if not obstacles is Array:
		db.errors.append("%s: 'obstacles_m' must be a list" % path)
		obstacles = []
	for i: int in (obstacles as Array).size():
		var o: Variant = obstacles[i]
		if not o is Array or (o as Array).size() != 4:
			db.errors.append("%s: obstacle %d must be [x_m, y_m, w_m, h_m]" % [path, i])
			continue
		var rect := PackedInt32Array()
		for v: Variant in o:
			if not (v is float or v is int) or float(v) != floorf(float(v)):
				db.errors.append("%s: obstacle %d must hold whole numbers" % [path, i])
				break
			rect.append(int(v))
		if rect.size() == 4:
			if rect[2] <= 0 or rect[3] <= 0:
				db.errors.append("%s: obstacle %d needs a positive size" % [path, i])
			else:
				m.obstacles_m.append(rect)
	for start: Variant in src.get("start_positions_m", []):
		if start is Array and (start as Array).size() == 2:
			m.start_positions.append(Vector2i(int(start[0]), int(start[1])))
		else:
			db.errors.append("%s: start positions must be [x_m, y_m]" % path)
	for site: Variant in src.get("supply_sites_m", []):
		if site is Array and (site as Array).size() == 3:
			m.supply_sites.append(PackedInt32Array([int(site[0]), int(site[1]), int(site[2])]))
		else:
			db.errors.append("%s: supply sites must be [x_m, y_m, amount]" % path)
	# Map folders: res://data/maps/<id>/map.json (P1-30). The folder name is the id.
	var name_from_path: String = path.get_base_dir().get_file() if path.get_file() == "map.json" \
			else path.get_file().get_basename()
	if name_from_path != m.id:
		db.errors.append("%s: folder or file name must match id '%s'" % [path, m.id])
	m.civilian_buildings_m = _int_rows(db, src, "civilian_buildings_m", 5, path)
	m.bridges_m = _int_rows(db, src, "bridges_m", 4, path)
	m.skirmish = bool(src.get("skirmish", false))
	for nb: Variant in src.get("neutral_buildings", []):
		if nb is Array and (nb as Array).size() == 3:
			m.neutral_buildings.append({"def": str(nb[0]), "x": int(nb[1]), "y": int(nb[2])})
		else:
			db.errors.append("%s: neutral buildings must be [building_id, x_m, y_m]" % path)
	m.biome = str(src.get("biome", "temperate"))
	if not MapDef.BIOMES.has(m.biome):
		db.errors.append("%s: unknown biome '%s' (temperate, desert or winter)" % [path, m.biome])
	m.max_step_cm = int(src.get("max_step_cm", m.max_step_cm))
	if src.has("water_level_cm"):
		m.water_level_cm = int(src["water_level_cm"])
	if src.has("height"):
		_load_heights(db, m, path.get_base_dir().path_join(str(src["height"])), int(src.get("height_scale_cm", 0)), path)
	db.maps[m.id] = m


## A list of whole-number rows of `size` values each (map rectangles).
static func _int_rows(db: ContentDb, src: Dictionary, key: String, size: int, path: String) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var rows: Variant = src.get(key, [])
	if not rows is Array:
		db.errors.append("%s: '%s' must be a list" % [path, key])
		return out
	for i: int in (rows as Array).size():
		var r: Variant = rows[i]
		if not r is Array or (r as Array).size() != size:
			db.errors.append("%s: %s entry %d must hold %d numbers" % [path, key, i, size])
			continue
		var row := PackedInt32Array()
		for v: Variant in r:
			row.append(int(v))
		if row[2] <= 0 or row[3] <= 0:
			db.errors.append("%s: %s entry %d needs a positive size" % [path, key, i])
			continue
		out.append(row)
	return out


## Reads a raw 16-bit little-endian heightmap: one sample per 2 m cell, row by
## row from the map's (0, 0) corner. 65535 = height_scale_cm. Raw bytes, not a
## PNG, because Godot re-encodes imported images; raw data is exact everywhere.
static func _load_heights(db: ContentDb, m: MapDef, file: String, scale_cm: int, path: String) -> void:
	if scale_cm <= 0:
		db.errors.append("%s: 'height_scale_cm' must be positive when 'height' is set" % path)
		return
	if not FileAccess.file_exists(file):
		db.errors.append("%s: height file %s not found" % [path, file])
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(file)
	var count: int = m.cells_x() * m.cells_y()
	if bytes.size() != count * 2:
		db.errors.append("%s: %s has %d bytes, expected %d (%d x %d cells, 2 bytes each)" % [
			path, file.get_file(), bytes.size(), count * 2, m.cells_x(), m.cells_y()])
		return
	m.heights_cm.resize(count)
	for i: int in count:
		var v: int = bytes.decode_u16(i * 2)
		m.heights_cm[i] = (v * scale_cm) / 65535
		db.hash_int(v)
