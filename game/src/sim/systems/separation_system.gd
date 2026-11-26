class_name SeparationSystem
extends RefCounted
## Pushes overlapping units apart, once per tick, after movement (P1-06).
##
## - Pairs are found with a bucket grid and handled in a fixed order (lower id
##   first, neighbor buckets in a fixed order), so every machine agrees.
## - A moving unit pushing an idle unit moves the idle one most of the way
##   ("excuse me"); two moving or two idle units share the push equally.
## - A push that would put a unit on a blocked cell (rock, building) is
##   skipped for that unit, so buildings and rocks block movement.
## - Exactly stacked units are split in a direction derived from their ids.

const BUCKET: int = 8 * Fx.ONE
## Share of the overlap moved per tick, as PUSH_NUM / PUSH_DEN. Less than 1 to
## avoid jitter; overlaps clear within a few ticks.
const PUSH_NUM: int = 3
const PUSH_DEN: int = 4
## Out of 4 parts of a push between a moving and an idle unit, the idle one
## takes this many.
const IDLE_SHARE: int = 3


static func step(world: SimWorld) -> void:
	var cols: int = maxi(1, (world.map_width + BUCKET - 1) / BUCKET)
	var rows: int = maxi(1, (world.map_height + BUCKET - 1) / BUCKET)
	var buckets: Array[Array] = []
	buckets.resize(cols * rows)
	for i: int in buckets.size():
		buckets[i] = []
	var movers: Array[SimEntity] = []
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.mover == null or e.mover.flying:
			continue   # flyers don't push or get pushed
		movers.append(e)
		buckets[_bucket_of(e, cols, rows)].append(e)
	for a: SimEntity in movers:
		var bx: int = clampi(a.x / BUCKET, 0, cols - 1)
		var by: int = clampi(a.y / BUCKET, 0, rows - 1)
		for ny: int in range(by - 1, by + 2):
			if ny < 0 or ny >= rows:
				continue
			for nx: int in range(bx - 1, bx + 2):
				if nx < 0 or nx >= cols:
					continue
				for b: SimEntity in buckets[ny * cols + nx]:
					# Cheap box test inline; _separate repeats it exactly.
					if b.id > a.id:
						var reach: int = a.radius + b.radius
						if absi(b.x - a.x) < reach and absi(b.y - a.y) < reach:
							_separate(world, a, b)


static func _bucket_of(e: SimEntity, cols: int, rows: int) -> int:
	var bx: int = clampi(e.x / BUCKET, 0, cols - 1)
	var by: int = clampi(e.y / BUCKET, 0, rows - 1)
	return by * cols + bx


static func _separate(world: SimWorld, a: SimEntity, b: SimEntity) -> void:
	var min_dist: int = a.radius + b.radius
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	if absi(dx) >= min_dist or absi(dy) >= min_dist:
		return
	var dist: int = Fx.length(dx, dy)
	if dist >= min_dist:
		return
	var ux: int
	var uy: int
	if dist == 0:
		# Exactly stacked: split along an angle derived from the ids.
		var angle: int = Fx.wrap_angle(a.id * 977 + b.id * 131)
		ux = Fx.cos_a(angle)
		uy = Fx.sin_a(angle)
	else:
		ux = Fx.div(dx, dist)
		uy = Fx.div(dy, dist)
	var push: int = ((min_dist - dist) * PUSH_NUM) / PUSH_DEN
	var a_moving: bool = a.mover.has_target
	var b_moving: bool = b.mover.has_target
	var a_part: int = 2
	if a_moving and not b_moving:
		a_part = 4 - IDLE_SHARE
	elif b_moving and not a_moving:
		a_part = IDLE_SHARE
	var a_push: int = (push * a_part) / 4
	var b_push: int = push - a_push
	_try_move(world, a, a.x - Fx.mul(ux, a_push), a.y - Fx.mul(uy, a_push))
	_try_move(world, b, b.x + Fx.mul(ux, b_push), b.y + Fx.mul(uy, b_push))


static func _try_move(world: SimWorld, e: SimEntity, nx: int, ny: int) -> void:
	nx = clampi(nx, 0, world.map_width)
	ny = clampi(ny, 0, world.map_height)
	# Same as map.is_passable(cell_of(nx, ny)): `walk` is 0 for blocked,
	# claimed and out-of-bounds cells (positions are >= 0 here).
	var map: SimMap = world.map
	if map.walk[(ny / SimMap.CELL + 1) * map.padded_width + nx / SimMap.CELL + 1] == 0:
		return
	e.x = nx
	e.y = ny
