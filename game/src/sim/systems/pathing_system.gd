class_name PathingSystem
extends RefCounted
## Plans paths for movers that asked for one (after a move order).
##
## Group orders (P1-05): one unit near the group's center (the leader) plans a
## path; every other unit (a follower) copies it, swapping the final waypoint
## for its own slot. A follower plans its own path only if it can't drive
## straight onto the shared path or from the path's last turn to its slot.
##
## At most MAX_SEARCHES_PER_TICK searches run per tick (copies are free), in
## entity-id order, leaders first. Units wait in place until their path is ready.

## Measured after P1-04b (Jump Point Search + JPS+ tables, desktop, GDScript):
## about 0.1 ms per typical search and 2.5 ms worst case. 8 per tick keeps a
## typical tick under 1 ms; phones are roughly 3-5x slower.
const MAX_SEARCHES_PER_TICK: int = 8


static func step(world: SimWorld) -> void:
	var budget: int = MAX_SEARCHES_PER_TICK
	# Pass 1: units planning their own path.
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var m: SimMover = e.mover
		if m == null or not m.needs_path:
			continue
		if m.flying:
			_fly(world, e)
			continue
		if m.follow_leader != 0:
			continue
		if budget == 0:
			break
		budget -= 1
		_plan(world, e)
	# Pass 2: followers copy their leader's path when it is ready.
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var m: SimMover = e.mover
		if m == null or not m.needs_path or m.follow_leader == 0:
			continue
		var leader: SimEntity = world.get_entity(m.follow_leader)
		var leader_ready: bool = leader != null and leader.mover != null and not leader.mover.needs_path \
				and leader.mover.path.size() > 0
		if leader != null and leader.mover != null and leader.mover.needs_path:
			continue   # leader still waiting for its own search; try next tick
		if leader_ready and _copy_leader_path(world, e, leader):
			continue
		if budget == 0:
			continue
		budget -= 1
		m.follow_leader = 0
		_plan(world, e)


## Flyers go straight to their destination: no search, no budget.
static func _fly(world: SimWorld, e: SimEntity) -> void:
	var m: SimMover = e.mover
	m.target_x = clampi(m.target_x, 0, world.map_width)
	m.target_y = clampi(m.target_y, 0, world.map_height)
	m.path = [Vector2i(m.target_x, m.target_y)]
	m.path_index = 0
	m.needs_path = false
	m.follow_leader = 0


static func _plan(world: SimWorld, e: SimEntity) -> void:
	var m: SimMover = e.mover
	m.path = world.pathfinder.find_path(e.x, e.y, m.target_x, m.target_y)
	m.path_index = 0
	m.needs_path = false
	m.follow_leader = 0
	# The destination may have moved to the nearest reachable spot.
	var last: Vector2i = m.path[m.path.size() - 1]
	m.target_x = last.x
	m.target_y = last.y


## Gives `e` the leader's path with its own slot at the end. Returns false if
## the follower can't drive straight onto or off the shared route.
static func _copy_leader_path(world: SimWorld, e: SimEntity, leader: SimEntity) -> bool:
	var m: SimMover = e.mover
	var shared: Array[Vector2i] = leader.mover.path
	var slot: Vector2i = world.pathfinder.nearest_open_point(m.target_x, m.target_y)
	var path: Array[Vector2i] = []
	for i: int in shared.size() - 1:
		path.append(shared[i])
	var first: Vector2i = path[0] if path.size() > 0 else slot
	if not world.pathfinder.has_line_of_sight(e.x, e.y, first.x, first.y):
		return false
	if path.size() > 0:
		var last_turn: Vector2i = path[path.size() - 1]
		if not world.pathfinder.has_line_of_sight(last_turn.x, last_turn.y, slot.x, slot.y):
			return false
	path.append(slot)
	m.path = path
	m.path_index = 0
	m.needs_path = false
	m.follow_leader = 0
	m.target_x = slot.x
	m.target_y = slot.y
	return true
