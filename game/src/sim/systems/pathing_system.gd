class_name PathingSystem
extends RefCounted
## Plans paths for movers that asked for one (after a move order).
##
## At most MAX_SEARCHES_PER_TICK searches run per tick, in entity-id order, so
## a big group order spreads its cost over a few ticks. Units wait in place
## until their path is ready (at most a few ticks).

## Measured after P1-04b (Jump Point Search + JPS+ tables, desktop, GDScript):
## about 0.1 ms per typical search and 2.5 ms worst case. 8 per tick keeps a
## typical tick under 1 ms; phones are roughly 3-5x slower.
const MAX_SEARCHES_PER_TICK: int = 8


static func step(world: SimWorld) -> void:
	var budget: int = MAX_SEARCHES_PER_TICK
	for id: int in world.entity_ids:
		var m: SimMover = world.entities[id].mover
		if m == null or not m.needs_path:
			continue
		if budget == 0:
			return
		budget -= 1
		var e: SimEntity = world.entities[id]
		m.path = world.pathfinder.find_path(e.x, e.y, m.target_x, m.target_y)
		m.path_index = 0
		m.needs_path = false
		# The destination may have moved to the nearest reachable spot.
		var last: Vector2i = m.path[m.path.size() - 1]
		m.target_x = last.x
		m.target_y = last.y
