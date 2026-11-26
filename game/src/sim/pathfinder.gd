class_name Pathfinder
extends RefCounted
## Deterministic pathfinding on the SimMap grid: Jump Point Search with JPS+
## tables (P1-04b), falling back to plain A* (P1-04) for unreachable goals.
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
## How far (in cells) to look for an open cell when the goal is blocked.
const NEAREST_RADIUS: int = 16
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
var _changes_seen: int = 0
var _jump_e: PackedInt32Array = PackedInt32Array()
var _jump_w: PackedInt32Array = PackedInt32Array()
var _jump_n: PackedInt32Array = PackedInt32Array()
var _jump_s: PackedInt32Array = PackedInt32Array()
var _run_e: PackedInt32Array = PackedInt32Array()
var _run_w: PackedInt32Array = PackedInt32Array()
var _run_n: PackedInt32Array = PackedInt32Array()
var _run_s: PackedInt32Array = PackedInt32Array()


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
	for arr_name: String in ["_jump_e", "_jump_w", "_jump_n", "_jump_s", "_run_e", "_run_w", "_run_n", "_run_s"]:
		var arr := PackedInt32Array()
		arr.resize(n)
		arr.fill(-1 if arr_name.begins_with("_jump") else 0)
		set(arr_name, arr)
	_rebuild_all()


## Waypoints (fixed-point positions) from (sx, sy) toward (tx, ty), excluding
## the start. The last waypoint is the exact target when its cell is reachable,
## otherwise the center of the reachable cell closest to it. Never empty.
func find_path(sx: int, sy: int, tx: int, ty: int) -> Array[Vector2i]:
	var start: Vector2i = _clamp_cell(_map.cell_of(sx, sy))
	var goal: Vector2i = _clamp_cell(_map.cell_of(tx, ty))
	var goal_ok: bool = _map.is_passable(goal.x, goal.y)
	if start == goal:
		return [Vector2i(tx, ty) if goal_ok else SimMap.cell_center(start.x, start.y)]
	# Fast path: Jump Point Search to the goal, or to the open cell nearest a
	# blocked goal. If that fails (the goal is cut off), plain A* finds the
	# reachable cell closest to the goal.
	_sync_tables()
	var search_goal: Vector2i = goal if goal_ok else _nearest_passable(goal, NEAREST_RADIUS)
	var end_index: int = -1
	if search_goal.x >= 0 and _search_jps(start, search_goal):
		end_index = _map.padded_index(search_goal.x, search_goal.y)
	else:
		end_index = _search(start, goal)
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


## Jump Point Search (P1-04b): A* that only stops at "jump points", the cells
## where a straight or diagonal run has to change direction because of an
## obstacle. Same movement rules as _search (8 directions, no corner cutting)
## and the same integer costs, so paths have the same length. Returns true if
## the goal was reached; parents then chain jump points back to the start.
func _search_jps(start: Vector2i, goal: Vector2i) -> bool:
	_gen += 1
	_heap_size = 0
	var gen: int = _gen
	var pw: int = _map.padded_width
	var walk: PackedByteArray = _map.walk    # read-only local: no copy is made
	var si: int = _map.padded_index(start.x, start.y)
	var gi: int = _map.padded_index(goal.x, goal.y)
	_seen_gen[si] = gen
	_g[si] = 0
	_parent[si] = -1
	var h0: int = _heuristic(start.x, start.y, goal)
	_push(_key((h0 * HEURISTIC_NUM) / HEURISTIC_DEN, h0, si))
	var expansions: int = 0
	var dirs: PackedInt32Array = PackedInt32Array()
	while _heap_size > 0 and expansions < MAX_EXPANSIONS:
		var ci: int = _pop() & _INDEX_MASK
		if _closed_gen[ci] == gen:
			continue
		_closed_gen[ci] = gen
		expansions += 1
		if ci == gi:
			last_expansions = expansions
			return true
		var cx: int = ci % pw - 1
		var cy: int = ci / pw - 1
		_jps_directions(ci, cx, cy, walk, pw, dirs)
		var gc: int = _g[ci]
		for n: int in range(0, dirs.size(), 2):
			var ddx: int = dirs[n]
			var ddy: int = dirs[n + 1]
			var jp: int = _jump(cx + ddx, cy + ddy, ddx, ddy, goal.x, goal.y, walk, pw)
			if jp == -1 or _closed_gen[jp] == gen:
				continue
			var jx: int = jp % pw - 1
			var jy: int = jp / pw - 1
			var adx: int = absi(jx - cx)
			var ady: int = absi(jy - cy)
			var ng: int = gc + COST_STRAIGHT * maxi(adx, ady) + (COST_DIAGONAL - COST_STRAIGHT) * mini(adx, ady)
			if _seen_gen[jp] != gen or ng < _g[jp]:
				_seen_gen[jp] = gen
				_g[jp] = ng
				_parent[jp] = ci
				var hn: int = _heuristic(jx, jy, goal)
				_push(_key(ng + (hn * HEURISTIC_NUM) / HEURISTIC_DEN, hn, jp))
	last_expansions = expansions
	return false


## Directions worth exploring from a jump point, as flat (dx, dy) pairs.
## Without a parent: every open direction. Otherwise only the continuation of
## the arrival direction plus turns that an obstacle may have forced.
func _jps_directions(ci: int, x: int, y: int, walk: PackedByteArray, pw: int, out: PackedInt32Array) -> void:
	out.clear()
	var p: int = _parent[ci]
	if p == -1:
		for k: int in 8:
			if walk[ci + _offset[k]] == 0:
				continue
			if k >= 4 and (walk[ci + DX[k]] == 0 or walk[ci + DY[k] * pw] == 0):
				continue
			out.append(DX[k])
			out.append(DY[k])
		return
	var dx: int = signi(x - (p % pw - 1))
	var dy: int = signi(y - (p / pw - 1))
	if dx != 0 and dy != 0:
		var open_y: bool = walk[ci + dy * pw] != 0
		var open_x: bool = walk[ci + dx] != 0
		if open_y:
			out.append_array([0, dy])
		if open_x:
			out.append_array([dx, 0])
		if open_x and open_y:
			out.append_array([dx, dy])
	elif dx != 0:
		var next: bool = walk[ci + dx] != 0
		var up: bool = walk[ci + pw] != 0
		var down: bool = walk[ci - pw] != 0
		if next:
			out.append_array([dx, 0])
			if up:
				out.append_array([dx, 1])
			if down:
				out.append_array([dx, -1])
		if up:
			out.append_array([0, 1])
		if down:
			out.append_array([0, -1])
	else:
		var next: bool = walk[ci + dy * pw] != 0
		var right: bool = walk[ci + 1] != 0
		var left: bool = walk[ci - 1] != 0
		if next:
			out.append_array([0, dy])
			if right:
				out.append_array([1, dy])
			if left:
				out.append_array([-1, dy])
		if right:
			out.append_array([1, 0])
		if left:
			out.append_array([-1, 0])


## Runs from (x, y) in direction (dx, dy) and returns the padded index of the
## first jump point, or -1 if the run hits an obstacle first. Straight runs
## stop next to an obstacle's end; diagonal runs stop where a straight run
## from them would find a jump point. Straight runs are table lookups (JPS+),
## so a diagonal run costs one step per diagonal cell.
func _jump(x: int, y: int, dx: int, dy: int, gx: int, gy: int, walk: PackedByteArray, pw: int) -> int:
	if dx == 0 or dy == 0:
		return _jump_straight(x, y, dx, dy, gx, gy, walk, pw)
	while true:
		var i: int = (y + 1) * pw + x + 1
		if walk[i] == 0:
			return -1
		if x == gx and y == gy:
			return i
		if _jump_straight(x + dx, y, dx, 0, gx, gy, walk, pw) != -1 or _jump_straight(x, y + dy, 0, dy, gx, gy, walk, pw) != -1:
			return i
		if walk[i + dx] == 0 or walk[i + dy * pw] == 0:
			return -1
		x += dx
		y += dy
	return -1


## Straight run from (x, y) (inclusive) using the precomputed tables.
func _jump_straight(x: int, y: int, dx: int, dy: int, gx: int, gy: int, walk: PackedByteArray, pw: int) -> int:
	var i: int = (y + 1) * pw + x + 1
	if walk[i] == 0:
		return -1
	var steps: int
	var run: int
	var to_goal: int = -1
	var stride: int
	if dy == 0:
		stride = dx
		if dx > 0:
			steps = _jump_e[i]
			run = _run_e[i]
			if gy == y:
				to_goal = gx - x
		else:
			steps = _jump_w[i]
			run = _run_w[i]
			if gy == y:
				to_goal = x - gx
	else:
		stride = dy * pw
		if dy > 0:
			steps = _jump_n[i]
			run = _run_n[i]
			if gx == x:
				to_goal = gy - y
		else:
			steps = _jump_s[i]
			run = _run_s[i]
			if gx == x:
				to_goal = y - gy
	if to_goal >= 0 and to_goal < run and (steps < 0 or to_goal <= steps):
		return i + to_goal * stride
	if steps < 0:
		return -1
	return i + steps * stride


## Reference version of _jump_straight that scans cell by cell. Only used by
## tests to check the tables; never call it in game code.
func _jump_straight_scan(x: int, y: int, dx: int, dy: int, gx: int, gy: int) -> int:
	var walk: PackedByteArray = _map.walk
	var pw: int = _map.padded_width
	while true:
		var i: int = (y + 1) * pw + x + 1
		if walk[i] == 0:
			return -1
		if x == gx and y == gy:
			return i
		if dx != 0:
			if (walk[i - pw] != 0 and walk[i - dx - pw] == 0) or (walk[i + pw] != 0 and walk[i - dx + pw] == 0):
				return i
		elif (walk[i - 1] != 0 and walk[i - 1 - dy * pw] == 0) or (walk[i + 1] != 0 and walk[i + 1 - dy * pw] == 0):
			return i
		x += dx
		y += dy
	return -1


# --- JPS+ tables -------------------------------------------------------------
# For every cell and straight direction: _jump_* = steps to the first jump
# point (0 = this cell), or -1 if a wall comes first; _run_* = how many open
# cells the run has, counting this one. Rebuilt per row/column when the map's
# walkability changes (SimMap.change_log).

func _sync_tables() -> void:
	var log: Array[Rect2i] = _map.change_log
	if _changes_seen == log.size():
		return
	var rows: Dictionary[int, bool] = {}
	var cols: Dictionary[int, bool] = {}
	for k: int in range(_changes_seen, log.size()):
		var r: Rect2i = log[k]
		for y: int in range(r.position.y - 1, r.end.y + 1):
			if y >= 0 and y < _map.height_cells:
				rows[y] = true
		for x: int in range(r.position.x - 1, r.end.x + 1):
			if x >= 0 and x < _map.width_cells:
				cols[x] = true
	_changes_seen = log.size()
	for y: int in rows:
		_rebuild_row(y)
	for x: int in cols:
		_rebuild_column(x)


func _rebuild_all() -> void:
	for y: int in _map.height_cells:
		_rebuild_row(y)
	for x: int in _map.width_cells:
		_rebuild_column(x)
	_changes_seen = _map.change_log.size()


func _rebuild_row(y: int) -> void:
	var walk: PackedByteArray = _map.walk
	var pw: int = _map.padded_width
	var base: int = (y + 1) * pw + 1
	var next_jump: int = -1
	var next_run: int = 0
	for x: int in range(_map.width_cells - 1, -1, -1):   # east-facing runs
		var i: int = base + x
		if walk[i] == 0:
			_jump_e[i] = -1
			_run_e[i] = 0
		else:
			_run_e[i] = next_run + 1
			if (walk[i - pw] != 0 and walk[i - 1 - pw] == 0) or (walk[i + pw] != 0 and walk[i - 1 + pw] == 0):
				_jump_e[i] = 0
			else:
				_jump_e[i] = next_jump + 1 if next_jump >= 0 else -1
		next_jump = _jump_e[i]
		next_run = _run_e[i]
	next_jump = -1
	next_run = 0
	for x: int in _map.width_cells:                       # west-facing runs
		var i: int = base + x
		if walk[i] == 0:
			_jump_w[i] = -1
			_run_w[i] = 0
		else:
			_run_w[i] = next_run + 1
			if (walk[i - pw] != 0 and walk[i + 1 - pw] == 0) or (walk[i + pw] != 0 and walk[i + 1 + pw] == 0):
				_jump_w[i] = 0
			else:
				_jump_w[i] = next_jump + 1 if next_jump >= 0 else -1
		next_jump = _jump_w[i]
		next_run = _run_w[i]


func _rebuild_column(x: int) -> void:
	var walk: PackedByteArray = _map.walk
	var pw: int = _map.padded_width
	var next_jump: int = -1
	var next_run: int = 0
	for y: int in range(_map.height_cells - 1, -1, -1):  # runs toward +Y
		var i: int = (y + 1) * pw + x + 1
		if walk[i] == 0:
			_jump_n[i] = -1
			_run_n[i] = 0
		else:
			_run_n[i] = next_run + 1
			if (walk[i - 1] != 0 and walk[i - 1 - pw] == 0) or (walk[i + 1] != 0 and walk[i + 1 - pw] == 0):
				_jump_n[i] = 0
			else:
				_jump_n[i] = next_jump + 1 if next_jump >= 0 else -1
		next_jump = _jump_n[i]
		next_run = _run_n[i]
	next_jump = -1
	next_run = 0
	for y: int in _map.height_cells:                      # runs toward -Y
		var i: int = (y + 1) * pw + x + 1
		if walk[i] == 0:
			_jump_s[i] = -1
			_run_s[i] = 0
		else:
			_run_s[i] = next_run + 1
			if (walk[i - 1] != 0 and walk[i - 1 + pw] == 0) or (walk[i + 1] != 0 and walk[i + 1 + pw] == 0):
				_jump_s[i] = 0
			else:
				_jump_s[i] = next_jump + 1 if next_jump >= 0 else -1
		next_jump = _jump_s[i]
		next_run = _run_s[i]


## The open cell nearest to `c` within `radius` cells (closest by straight-line
## distance, ties by cell index), or (-1, -1) if none.
func _nearest_passable(c: Vector2i, radius: int) -> Vector2i:
	for r: int in range(1, radius + 1):
		var best := Vector2i(-1, -1)
		var best_d: int = 0
		for y: int in range(c.y - r, c.y + r + 1):
			for x: int in range(c.x - r, c.x + r + 1):
				if maxi(absi(x - c.x), absi(y - c.y)) != r or not _map.is_passable(x, y):
					continue
				var d: int = (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y)
				if best.x < 0 or d < best_d:
					best = Vector2i(x, y)
					best_d = d
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


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
