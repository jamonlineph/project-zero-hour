class_name SimMap
extends RefCounted
## The battlefield grid: 2 m cells with passability, a building-footprint layer
## and integer heights (flat until P1-30). Ints only, like the rest of the sim.
##
## Cell (cx, cy) covers sim X in [cx * 2 m, (cx + 1) * 2 m) and likewise Y.
## Terrain blocking comes from the map data; footprints are claimed and released
## by buildings (P1-12). Pathfinding (P1-04) reads is_passable().

const CELL_CM: int = 200
const CELL: int = (CELL_CM * Fx.ONE) / 100    ## cell size in fixed-point meters

var width_cells: int = 0
var height_cells: int = 0
var _blocked: PackedByteArray = PackedByteArray()      ## 1 = terrain blocks movement
var _footprint: PackedInt32Array = PackedInt32Array()  ## entity id occupying the cell, 0 = none
var _heights: PackedInt32Array = PackedInt32Array()    ## fixed-point meters
## Combined walkability with a 1-cell blocked border, for the pathfinder's
## inner loop (no bounds checks). 1 = walkable. Index with padded_index().
var walk: PackedByteArray = PackedByteArray()
var padded_width: int = 0


func _init(width_m: int = 256, height_m: int = 256) -> void:
	width_cells = maxi(1, (width_m * 100 + CELL_CM - 1) / CELL_CM)
	height_cells = maxi(1, (height_m * 100 + CELL_CM - 1) / CELL_CM)
	var count: int = width_cells * height_cells
	_blocked.resize(count)
	_blocked.fill(0)
	_footprint.resize(count)
	_footprint.fill(0)
	_heights.resize(count)
	_heights.fill(0)
	padded_width = width_cells + 2
	walk.resize(padded_width * (height_cells + 2))
	walk.fill(0)
	for cy: int in height_cells:
		for cx: int in width_cells:
			walk[padded_index(cx, cy)] = 1


func in_bounds(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < width_cells and cy < height_cells


func index(cx: int, cy: int) -> int:
	return cy * width_cells + cx


## Index into `walk` (grid with a blocked border). Valid for -1..width/height.
func padded_index(cx: int, cy: int) -> int:
	return (cy + 1) * padded_width + cx + 1


## Cell coordinate containing a fixed-point position (may be out of bounds).
static func cell_coord(v: int) -> int:
	# Floor division, so negative positions land in negative cells.
	if v >= 0:
		return v / CELL
	return -((-v + CELL - 1) / CELL)


func cell_of(x: int, y: int) -> Vector2i:
	return Vector2i(cell_coord(x), cell_coord(y))


## Center of a cell, in fixed-point meters.
static func cell_center(cx: int, cy: int) -> Vector2i:
	return Vector2i(cx * CELL + CELL / 2, cy * CELL + CELL / 2)


func is_blocked_terrain(cx: int, cy: int) -> bool:
	return not in_bounds(cx, cy) or _blocked[index(cx, cy)] != 0


func is_passable(cx: int, cy: int) -> bool:
	if not in_bounds(cx, cy):
		return false
	var i: int = index(cx, cy)
	return _blocked[i] == 0 and _footprint[i] == 0


func footprint_owner(cx: int, cy: int) -> int:
	return _footprint[index(cx, cy)] if in_bounds(cx, cy) else 0


func height_at(cx: int, cy: int) -> int:
	return _heights[index(cx, cy)] if in_bounds(cx, cy) else 0


## Blocks every cell that overlaps the rectangle (meters, from its corner).
func add_obstacle_m(x_m: int, y_m: int, w_m: int, h_m: int) -> void:
	var x0: int = cell_coord(Fx.from_int(x_m))
	var y0: int = cell_coord(Fx.from_int(y_m))
	var x1: int = cell_coord(Fx.from_int(x_m + w_m) - 1)
	var y1: int = cell_coord(Fx.from_int(y_m + h_m) - 1)
	for cy: int in range(maxi(y0, 0), mini(y1, height_cells - 1) + 1):
		for cx: int in range(maxi(x0, 0), mini(x1, width_cells - 1) + 1):
			_blocked[index(cx, cy)] = 1
			walk[padded_index(cx, cy)] = 0


## Claims a w x h cell rectangle for an entity. Fails (claims nothing) unless
## every cell is in bounds and passable.
func place_footprint(cx: int, cy: int, w: int, h: int, entity_id: int) -> bool:
	assert(entity_id > 0, "SimMap.place_footprint: entity id must be positive")
	for y: int in range(cy, cy + h):
		for x: int in range(cx, cx + w):
			if not is_passable(x, y):
				return false
	for y: int in range(cy, cy + h):
		for x: int in range(cx, cx + w):
			_footprint[index(x, y)] = entity_id
			walk[padded_index(x, y)] = 0
	return true


## Releases every cell claimed by an entity. Returns how many were released.
func clear_footprint(entity_id: int) -> int:
	var released: int = 0
	for i: int in _footprint.size():
		if _footprint[i] == entity_id:
			_footprint[i] = 0
			released += 1
			if _blocked[i] == 0:
				walk[padded_index(i % width_cells, i / width_cells)] = 1
	return released


## Number of terrain-blocked cells (handy for tests and debug overlays).
func blocked_count() -> int:
	var n: int = 0
	for b: int in _blocked:
		n += b
	return n


func write_hash(h: SimHash) -> void:
	h.add_int(width_cells)
	h.add_int(height_cells)
	# Terrain only changes when the map loads; footprints change in play.
	h.add_int(blocked_count())
	for i: int in _footprint.size():
		if _footprint[i] != 0:
			h.add_int(i)
			h.add_int(_footprint[i])
