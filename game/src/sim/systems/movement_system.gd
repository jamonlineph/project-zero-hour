class_name MovementSystem
extends RefCounted
## Moves every entity that has a mover along its path by one tick.
##
## Each tick a mover first turns toward its current waypoint by at most
## turn_rate. It moves at full speed only once it faces within FULL_SPEED_ANGLE
## of that heading; until then it creeps at SLOW_NUM/SLOW_DEN speed. Units
## waiting for a path (needs_path) stand still.


static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var m: SimMover = e.mover
		if m == null or not m.has_target or m.needs_path or m.paused:
			continue
		var wx: int = m.target_x
		var wy: int = m.target_y
		if m.path_index < m.path.size():
			wx = m.path[m.path_index].x
			wy = m.path[m.path_index].y
		var dx: int = wx - e.x
		var dy: int = wy - e.y
		var dist: int = Fx.length(dx, dy)
		if dist > 0:
			var heading: int = Fx.atan2_a(dy, dx)
			var turn: int = clampi(Fx.angle_diff(e.facing, heading), -m.turn_rate, m.turn_rate)
			e.facing = Fx.wrap_angle(e.facing + turn)
			var step_len: int = m.current_speed()
			if absi(Fx.angle_diff(e.facing, heading)) > SimMover.FULL_SPEED_ANGLE:
				step_len = (step_len * SimMover.SLOW_NUM) / SimMover.SLOW_DEN
			if dist > step_len:
				# Integer division truncates toward zero the same way on every CPU.
				e.x += (dx * step_len) / dist
				e.y += (dy * step_len) / dist
				continue
		# Reached the waypoint this tick.
		e.x = wx
		e.y = wy
		if m.path_index < m.path.size() - 1:
			m.path_index += 1
		else:
			m.stop()
