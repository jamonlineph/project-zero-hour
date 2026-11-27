class_name WorldPlacement
extends RefCounted
## Footprints and the cells around bodies (split out of SimWorld in P2-11d).
## Callers use the SimWorld methods of the same names.


## True if the footprint at `origin` is open terrain with no building on it and
## no unit standing on it (a unit there would be trapped).
static func can_place(world: SimWorld, def: BuildingDef, origin: Vector2i) -> bool:
	for y: int in range(origin.y, origin.y + def.footprint_h):
		for x: int in range(origin.x, origin.x + def.footprint_w):
			if not world.map.is_passable(x, y):
				return false
	for id: int in world.entity_ids:
		var u: SimEntity = world.entities[id]
		if u.mover == null:
			continue
		var cell: Vector2i = world.map.cell_of(u.x, u.y)
		if cell.x >= origin.x and cell.y >= origin.y and cell.x < origin.x + def.footprint_w and cell.y < origin.y + def.footprint_h:
			return false
	return true


## First cell of a `size`-cell span centered near `p` on an axis `extent` long
## (both fixed-point meters). A point exactly between two choices goes toward
## the middle of the map, so mirrored points give mirrored footprints on a
## mirrored map (P2-11c fairness).
static func footprint_start(p: int, size: int, extent: int) -> int:
	var toward_low: bool = p > extent / 2   # past the middle, ties go to lower cells
	if size % 2 == 1:
		# The span's center is a cell center: the cell holding p.
		var c: int = SimMap.cell_coord(p)
		if toward_low and posmod(p, SimMap.CELL) == 0:
			c -= 1
		return c - size / 2
	# The span's center is a cell edge: the nearest one.
	var shifted: int = p + SimMap.CELL / 2
	var edge: int = SimMap.cell_coord(shifted)
	if toward_low and posmod(shifted, SimMap.CELL) == 0:
		edge -= 1
	return edge - size / 2


## Distance from a point to the nearest edge of an entity: its footprint for
## buildings and supply sites, its circle otherwise (fixed-point meters).
static func distance_to_body(x: int, y: int, target: SimEntity) -> int:
	if target.building == null and target.supply == null:
		return maxi(0, Fx.length(target.x - x, target.y - y) - target.radius)
	var half_w: int = target.radius
	var half_h: int = target.radius
	if target.building != null:
		half_w = (target.building.w * SimMap.CELL) / 2
		half_h = (target.building.h * SimMap.CELL) / 2
	var dx: int = maxi(0, absi(x - target.x) - half_w)
	var dy: int = maxi(0, absi(y - target.y) - half_h)
	return Fx.length(dx, dy)


## The open cell next to an entity's body that is nearest to (x, y): where a
## builder or gatherer parks to work on it.
static func approach_point(world: SimWorld, target: SimEntity, x: int, y: int) -> Vector2i:
	var cx0: int
	var cy0: int
	var w: int
	var h: int
	if target.building != null:
		cx0 = target.building.cell_x
		cy0 = target.building.cell_y
		w = target.building.w
		h = target.building.h
	else:
		var c: Vector2i = world.map.cell_of(target.x, target.y)
		cx0 = c.x - 1
		cy0 = c.y - 1
		w = 2
		h = 2
	var best := Vector2i(target.x, target.y)
	var best_d: int = -1
	for cy: int in range(cy0 - 1, cy0 + h + 1):
		for cx: int in range(cx0 - 1, cx0 + w + 1):
			var edge: bool = cx == cx0 - 1 or cy == cy0 - 1 or cx == cx0 + w or cy == cy0 + h
			if not edge or not world.map.is_passable(cx, cy):
				continue
			var p: Vector2i = SimMap.cell_center(cx, cy)
			var d: int = Fx.length_sq(p.x - x, p.y - y)
			if best_d < 0 or d < best_d or (d == best_d and _nearer_middle(world, p, best)):
				best = p
				best_d = d
	return best


## Tie-break for equally good cells: the one nearer the middle of the map, so
## mirrored bases pick mirrored cells (P2-11c fairness).
static func _nearer_middle(world: SimWorld, a: Vector2i, b: Vector2i) -> bool:
	var ax: int = absi(2 * a.x - world.map_width)
	var bx: int = absi(2 * b.x - world.map_width)
	if ax != bx:
		return ax < bx
	return absi(2 * a.y - world.map_height) < absi(2 * b.y - world.map_height)
