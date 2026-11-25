class_name MovementSystem
extends RefCounted
## Moves every entity that has a mover toward its target by one tick.


static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var m: SimMover = e.mover
		if m == null or not m.has_target:
			continue
		var dx: int = m.target_x - e.x
		var dy: int = m.target_y - e.y
		var dist: int = Fx.length(dx, dy)
		if dist <= m.speed:
			e.x = m.target_x
			e.y = m.target_y
			m.has_target = false
			continue
		# Integer division truncates toward zero the same way on every CPU.
		e.x += (dx * m.speed) / dist
		e.y += (dy * m.speed) / dist
