class_name SimVision
extends RefCounted
## Per-team fog of war (P1-11).
##
## The map is divided into 8 m vision cells. Every UPDATE_INTERVAL ticks each
## team's "visible" layer is rebuilt from its units' vision circles, and every
## visible cell is also marked "explored" (remembered forever). Teams share
## vision between all their players. Ints only.

const CELL: int = 8 * Fx.ONE
const UPDATE_INTERVAL: int = 3

var cols: int = 1
var rows: int = 1
var _visible: Dictionary[int, PackedByteArray] = {}    ## team -> 1 per visible cell
var _explored: Dictionary[int, PackedByteArray] = {}   ## team -> 1 per explored cell
var _circles: Dictionary[int, PackedInt32Array] = {}   ## radius in cells -> flat (dx, dy) pairs


func _init(map_width: int, map_height: int) -> void:
	cols = maxi(1, (map_width + CELL - 1) / CELL)
	rows = maxi(1, (map_height + CELL - 1) / CELL)


func cell_index(x: int, y: int) -> int:
	return clampi(y / CELL, 0, rows - 1) * cols + clampi(x / CELL, 0, cols - 1)


func is_visible(team: int, x: int, y: int) -> bool:
	var layer: PackedByteArray = _visible.get(team, PackedByteArray())
	return not layer.is_empty() and layer[cell_index(x, y)] != 0


func is_explored(team: int, x: int, y: int) -> bool:
	var layer: PackedByteArray = _explored.get(team, PackedByteArray())
	return not layer.is_empty() and layer[cell_index(x, y)] != 0


## Rebuilds every team's visible layer from its living units' vision.
func update(world: SimWorld) -> void:
	var fresh: Dictionary[int, PackedByteArray] = {}
	# Units of one team in the same cell with the same sight stamp the same
	# circle; stamp it once. (Stamping is an OR, so the result is identical.)
	var stamped: Dictionary[int, bool] = {}
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.player_id == 0 or e.vision <= 0:
			continue
		var team: int = world.team_of(e.player_id)
		if not fresh.has(team):
			var layer := PackedByteArray()
			layer.resize(cols * rows)
			layer.fill(0)
			fresh[team] = layer
		var cx: int = e.x / CELL
		var cy: int = e.y / CELL
		var r: int = (e.vision + CELL / 2) / CELL
		var key: int = ((team * 65536 + cy) * 65536 + cx) * 1024 + r
		if stamped.has(key):
			continue
		stamped[key] = true
		_stamp(fresh, team, cx, cy, r)
	for team: int in fresh:
		_visible[team] = fresh[team]
		if not _explored.has(team):
			var ex := PackedByteArray()
			ex.resize(cols * rows)
			ex.fill(0)
			_explored[team] = ex
		var explored: PackedByteArray = _explored[team]
		var vis: PackedByteArray = fresh[team]
		for i: int in vis.size():
			if vis[i] != 0:
				explored[i] = 1
		_explored[team] = explored
	# Teams that lost every unit see nothing.
	for team: int in _visible.keys():
		if not fresh.has(team):
			var empty := PackedByteArray()
			empty.resize(cols * rows)
			empty.fill(0)
			_visible[team] = empty


func _stamp(layers: Dictionary[int, PackedByteArray], team: int, cx: int, cy: int, r: int) -> void:
	var layer: PackedByteArray = layers[team]
	var offsets: PackedInt32Array = _circle(r)
	for k: int in range(0, offsets.size(), 2):
		var x: int = cx + offsets[k]
		var y: int = cy + offsets[k + 1]
		if x >= 0 and y >= 0 and x < cols and y < rows:
			layer[y * cols + x] = 1
	layers[team] = layer


func _circle(r: int) -> PackedInt32Array:
	if _circles.has(r):
		return _circles[r]
	var out := PackedInt32Array()
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + r:
				out.append(dx)
				out.append(dy)
	_circles[r] = out
	return out


func write_hash(h: SimHash) -> void:
	var teams: Array[int] = []
	for t: int in _explored:
		teams.append(t)
	teams.sort()
	for team: int in teams:
		h.add_int(team)
		var vis: PackedByteArray = _visible.get(team, PackedByteArray())
		var ex: PackedByteArray = _explored[team]
		var vis_sum: int = 0
		var ex_sum: int = 0
		for i: int in ex.size():
			if ex[i] != 0:
				ex_sum += i + 1
			if not vis.is_empty() and vis[i] != 0:
				vis_sum += (i + 1) * 3
		h.add_int(vis_sum)
		h.add_int(ex_sum)
