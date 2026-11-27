class_name SpatialIndex
extends RefCounted
## Buckets of entities for area searches (split out of SimWorld in P2-11d).
## Rebuilt once per tick after movement; queries return entities in a
## deterministic order (bucket by bucket, ascending id inside a bucket).

## Bucket size of the index used for area searches.
const BUCKET: int = 16 * Fx.ONE

var _cols: int = 1
var _rows: int = 1
var _buckets: Array[Array] = []
## The same buckets split by team (players only, no neutrals), so enemy
## searches never walk through friendly units.
var _team_buckets: Dictionary[int, Array] = {}


func is_empty() -> bool:
	return _buckets.is_empty()


## Forgets everything (entities were removed); the next query rebuilds.
func clear() -> void:
	_buckets.clear()


func rebuild(world: SimWorld) -> void:
	_cols = maxi(1, (world.map_width + BUCKET - 1) / BUCKET)
	_rows = maxi(1, (world.map_height + BUCKET - 1) / BUCKET)
	if _buckets.size() != _cols * _rows:
		_buckets.resize(_cols * _rows)
	for i: int in _buckets.size():
		_buckets[i] = []
	_team_buckets.clear()
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var bx: int = clampi(e.x / BUCKET, 0, _cols - 1)
		var by: int = clampi(e.y / BUCKET, 0, _rows - 1)
		var b: int = by * _cols + bx
		_buckets[b].append(e)
		if e.player_id != 0:
			var team: int = world.team_of(e.player_id)
			if not _team_buckets.has(team):
				var buckets: Array[Array] = []
				buckets.resize(_buckets.size())
				for i: int in buckets.size():
					buckets[i] = []
				_team_buckets[team] = buckets
			(_team_buckets[team] as Array)[b].append(e)


## Entities whose position lies within `radius` of (x, y) (fixed-point).
func query_radius(x: int, y: int, radius: int) -> Array[SimEntity]:
	var result: Array[SimEntity] = []
	var x0: int = clampi((x - radius) / BUCKET, 0, _cols - 1)
	var x1: int = clampi((x + radius) / BUCKET, 0, _cols - 1)
	var y0: int = clampi((y - radius) / BUCKET, 0, _rows - 1)
	var y1: int = clampi((y + radius) / BUCKET, 0, _rows - 1)
	# Fx.length is floor(sqrt), so length <= r exactly when dx²+dy² < (r+1)².
	var limit: int = (radius + 1) * (radius + 1)
	for by: int in range(y0, y1 + 1):
		for bx: int in range(x0, x1 + 1):
			for e: SimEntity in _buckets[by * _cols + bx]:
				var dx: int = e.x - x
				var dy: int = e.y - y
				if absi(dx) <= radius and absi(dy) <= radius and dx * dx + dy * dy < limit:
					result.append(e)
	return result


## Like query_radius, but only entities of teams other than `team`.
func query_other_teams(team: int, x: int, y: int, radius: int) -> Array[SimEntity]:
	var result: Array[SimEntity] = []
	var x0: int = clampi((x - radius) / BUCKET, 0, _cols - 1)
	var x1: int = clampi((x + radius) / BUCKET, 0, _cols - 1)
	var y0: int = clampi((y - radius) / BUCKET, 0, _rows - 1)
	var y1: int = clampi((y + radius) / BUCKET, 0, _rows - 1)
	var limit: int = (radius + 1) * (radius + 1)
	for other: int in _team_buckets:
		if other == team:
			continue
		var buckets: Array = _team_buckets[other]
		for by: int in range(y0, y1 + 1):
			for bx: int in range(x0, x1 + 1):
				for e: SimEntity in buckets[by * _cols + bx]:
					var dx: int = e.x - x
					var dy: int = e.y - y
					if absi(dx) <= radius and absi(dy) <= radius and dx * dx + dy * dy < limit:
						result.append(e)
	return result
