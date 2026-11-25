class_name MovementSystem
extends RefCounted
## Moves every entity that has a mover toward its target by one tick.
##
## Each tick a mover first turns toward its heading by at most turn_rate. It
## moves at full speed only once it faces within FULL_SPEED_ANGLE of the
## heading; until then it creeps at SLOW_NUM/SLOW_DEN speed. It always moves
## along the straight line to the target, so paths stay exact.


static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var m: SimMover = e.mover
		if m == null or not m.has_target:
			continue
		var dx: int = m.target_x - e.x
		var dy: int = m.target_y - e.y
		var dist: int = Fx.length(dx, dy)
		if dist == 0:
			m.has_target = false
			continue
		var heading: int = Fx.atan2_a(dy, dx)
		var turn: int = Fx.angle_diff(e.facing, heading)
		turn = clampi(turn, -m.turn_rate, m.turn_rate)
		e.facing = Fx.wrap_angle(e.facing + turn)
		var step_len: int = m.speed
		if absi(Fx.angle_diff(e.facing, heading)) > SimMover.FULL_SPEED_ANGLE:
			step_len = (m.speed * SimMover.SLOW_NUM) / SimMover.SLOW_DEN
		if dist <= step_len:
			e.x = m.target_x
			e.y = m.target_y
			m.has_target = false
			continue
		# Integer division truncates toward zero the same way on every CPU.
		e.x += (dx * step_len) / dist
		e.y += (dy * step_len) / dist
