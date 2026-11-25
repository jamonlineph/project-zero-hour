class_name Pathfinder
extends RefCounted
## Deterministic A* on the SimMap grid (P1-04).
##
## - 8 directions; diagonal steps may not cut a blocked corner.
## - Integer costs (10 straight, 14 diagonal) and an octile heuristic weighted
##   by HEURISTIC_NUM/HEURISTIC_DEN (5/4): far fewer cells searched, paths at
##   most 25% longer than optimal (in practice a few percent, and smoothing
##   straightens them).
## - Ties broken by (f, h, cell index), so every machine finds the same path.
## - If the goal can't be reached, the path ends at the reachable cell closest
##   to it. Searches stop after MAX_EXPANSIONS cells and use the best so far.
## - The raw cell path is smoothed by line of sight into a few waypoints.

const COST_STRAIGHT: int = 10
const COST_DIAGONAL: int = 14
const MAX_EXPANSIONS: int = 6000
const HEURISTIC_NUM: int = 5
const HEURISTIC_DEN: int = 4
## Neighbor order is part of determinism: never reorder. First 4 are straight.
const DX: Array[int] = [1, 0, -1, 0, 1, -1, -1, 1]
const DY: Array[int] = [0, 1, 0, -1, 1, 1, -1, -1]
const _INDEX_BITS: int = 21
const _INDEX_MASK: int = (1 << _INDEX_BITS) - 1
const _H_MASK: int = (1 << _INDEX_BITS) - 1

var last_expansions: int = 0   ## cells expanded by the latest search (for tests/profiling)
var _map: SimMap
var _offset: PackedInt32Array = PackedInt32Array()   ## padded-index step per direction
var _gen: int = 0
var _seen_gen: PackedInt32Array = PackedInt32Array()
var _closed_gen: PackedInt32Array = PackedInt32Array()
var _g: PackedInt32Array = PackedInt32Array()
var _parent: PackedInt32Array = PackedInt32Array()
var _heap: PackedInt64Array = PackedInt64Array()
var _heap_size: int = 0


func _init(map: SimMap) -> void:
	_map = map
	# All search arrays use SimMap's padded indices (grid plus a blocked border).
	var n: int = map.walk.size()
	assert(n <= _INDEX_MASK, "Pathfinder: map too large for the heap key")
	for k: int in 8:
		_offset.append(DY[k] * map.padded_width + DX[k])
	# Packed arrays are values in GDScript, so resize each member directly.
	_seen_gen.resize(n)
	_closed_gen.resize(n)
	_g.resize(n)
	_parent.resize(n)
	_seen_gen.fill(0)
	_closed_gen.fill(0)


## Waypoints (fixed-point positions) from (sx, sy) toward (tx, ty), excluding
## the start. The last waypoint is the exact target when its cell is reachable,
## otherwise the center of the reachable cell closest to it. Never empty.
func find_path(sx: int, sy: int, tx: int, ty: int) -> Array[Vector2i]:
	var start: Vector2i = _clamp_cell(_map.cell_of(sx, sy))
	var goal: Vector2i = _clamp_cell(_map.cell_of(tx, ty))
	var goal_ok: bool = _map.is_passable(goal.x, goal.y)
	if start == goal:
		return [Vector2i(tx, ty) if goal_ok else SimMap.cell_center(start.x, start.y)]
	var end_index: int = _search(start, goal)
	var cells: Array[int] = _reconstruct(end_index)
	var result: Array[Vector2i] = []
	var anchor: int = _map.padded_index(start.x, start.y)
	var pw: int = _map.padded_width
	var i: int = 0
	while i < cells.size():
		# Furthest cell still in straight sight of the anchor.
		var j: int = cells.size() - 1
		while j > i and not _line_of_sight(anchor, cells[j]):
			j -= 1
		anchor = cells[j]
		result.append(SimMap.cell_center(anchor % pw - 1, anchor / pw - 1))
		i = j + 1
	if result.is_empty():
		result.append(SimMap.cell_center(start.x, start.y))
	if end_index == _map.padded_index(goal.x, goal.y) and goal_ok:
		result[result.size() - 1] = Vector2i(tx, ty)
	return result


func _search(start: Vector2i, goal: Vector2i) -> int:
	_gen += 1
	_heap_size = 0
	var gen: int = _gen
	var pw: int = _map.padded_width
	var walk: PackedByteArray = _map.walk    # read-only local: no copy is made
	var si: int = _map.padded_index(start.x, start.y)
	var gi: int = _map.padded_index(goal.x, goal.y)
	var gx: int = goal.x
	var gy: int = goal.y
	_seen_gen[si] = gen
	_g[si] = 0
	_parent[si] = -1
	var h0: int = _heuristic(start.x, start.y, goal)
	_push(_key((h0 * HEURISTIC_NUM) / HEURISTIC_DEN, h0, si))
	var best: int = si
	var best_h: int = h0
	var best_g: int = 0
	var expansions: int = 0
	while _heap_size > 0 and expansions < MAX_EXPANSIONS:
		var ci: int = _pop() & _INDEX_MASK
		if _closed_gen[ci] == gen:
			continue
		_closed_gen[ci] = gen
		expansions += 1
		if ci == gi:
			best = gi
			break
		var cx: int = ci % pw - 1
		var cy: int = ci / pw - 1
		var gc: int = _g[ci]
		var adx: int = absi(cx - gx)
		var ady: int = absi(cy - gy)
		var hc: int = COST_STRAIGHT * maxi(adx, ady) + (COST_DIAGONAL - COST_STRAIGHT) * mini(adx, ady)
		if hc < best_h or (hc == best_h and gc < best_g):
			best = ci
			best_h = hc
			best_g = gc
		for k: int in 8:
			var ni: int = ci + _offset[k]
			if walk[ni] == 0 or _closed_gen[ni] == gen:
				continue
			var ng: int = gc + COST_STRAIGHT
			if k >= 4:
				# Diagonal: both orthogonal neighbors must be open (no corner cutting).
				if walk[ci + DX[k]] == 0 or walk[ci + DY[k] * pw] == 0:
					continue
				ng = gc + COST_DIAGONAL
			if _seen_gen[ni] != gen or ng < _g[ni]:
				_seen_gen[ni] = gen
				_g[ni] = ng
				_parent[ni] = ci
				var ndx: int = absi(cx + DX[k] - gx)
				var ndy: int = absi(cy + DY[k] - gy)
				var hn: int = COST_STRAIGHT * maxi(ndx, ndy) + (COST_DIAGONAL - COST_STRAIGHT) * mini(ndx, ndy)
				_push(_key(ng + (hn * HEURISTIC_NUM) / HEURISTIC_DEN, hn, ni))
	last_expansions = expansions
	return best


## Cell indices from just after the start to `end_index`, in walking order.
func _reconstruct(end_index: int) -> Array[int]:
	var cells: Array[int] = []
	var c: int = end_index
	while c != -1 and _parent[c] != -1:
		cells.append(c)
		c = _parent[c]
	cells.reverse()
	return cells


## True if a straight walk between two cell centers only crosses passable
## cells and never squeezes diagonally between two blocked cells.
func _line_of_sight(from_index: int, to_index: int) -> bool:
	var pw: int = _map.padded_width
	var x: int = from_index % pw - 1
	var y: int = from_index / pw - 1
	var x1: int = to_index % pw - 1
	var y1: int = to_index / pw - 1
	var dx: int = absi(x1 - x)
	var dy: int = absi(y1 - y)
	var sx: int = 1 if x1 > x else -1
	var sy: int = 1 if y1 > y else -1
	var err: int = dx - dy
	while not (x == x1 and y == y1):
		var e2: int = err * 2
		var moved_x: bool = false
		var moved_y: bool = false
		if e2 > -dy:
			err -= dy
			x += sx
			moved_x = true
		if e2 < dx:
			err += dx
			y += sy
			moved_y = true
		if not _map.is_passable(x, y):
			return false
		if moved_x and moved_y and (not _map.is_passable(x - sx, y) or not _map.is_passable(x, y - sy)):
			return false
	return true


func _heuristic(x: int, y: int, goal: Vector2i) -> int:
	var dx: int = absi(x - goal.x)
	var dy: int = absi(y - goal.y)
	# Octile distance: straight moves cost 10, diagonals 14.
	return COST_STRAIGHT * maxi(dx, dy) + (COST_DIAGONAL - COST_STRAIGHT) * mini(dx, dy)


func _clamp_cell(c: Vector2i) -> Vector2i:
	return Vector2i(clampi(c.x, 0, _map.width_cells - 1), clampi(c.y, 0, _map.height_cells - 1))


static func _key(f: int, h: int, index: int) -> int:
	return (f << (2 * _INDEX_BITS)) | ((h & _H_MASK) << _INDEX_BITS) | index


# --- Binary min-heap of int keys ---

func _push(k: int) -> void:
	if _heap_size == _heap.size():
		_heap.resize(maxi(64, _heap_size * 2))
	var i: int = _heap_size
	_heap_size += 1
	while i > 0:
		var p: int = (i - 1) >> 1
		if _heap[p] <= k:
			break
		_heap[i] = _heap[p]
		i = p
	_heap[i] = k


func _pop() -> int:
	var top: int = _heap[0]
	_heap_size -= 1
	if _heap_size == 0:
		return top
	var k: int = _heap[_heap_size]
	var i: int = 0
	while true:
		var l: int = i * 2 + 1
		if l >= _heap_size:
			break
		var r: int = l + 1
		var c: int = l
		if r < _heap_size and _heap[r] < _heap[l]:
			c = r
		if _heap[c] >= k:
			break
		_heap[i] = _heap[c]
		i = c
	_heap[i] = k
	return top
