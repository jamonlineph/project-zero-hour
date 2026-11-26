class_name JammingSystem
extends RefCounted
## Jamming fields and spoofing (P2-03), after DroneSystem, before pathing.
##
## - An active jammer (alive; a building must be finished and powered) blinds
##   enemy drones inside its radius: they lose control, hover and drift
##   slowly, can't fire, and ignore orders. Endurance still runs down, so a
##   drone that never drifts out crashes. Fiber-optic drones are immune.
## - Guided weapons aimed at a target inside a hostile field miss half the
##   time (CombatSystem asks SimWorld.jam_level()). Fields don't stack.
## - Spoofed drones (the SPOOF command, UnitCommands) fly to a random point
##   and, if armed, attack a random nearby entity of any side for SPOOF_TICKS.

const DRIFT_EVERY: int = SimWorld.TICK_RATE
const DRIFT_STEP: int = 2 * Fx.ONE
const SPOOF_TICKS: int = 5 * SimWorld.TICK_RATE


static func step(world: SimWorld) -> void:
	world.active_jammers.clear()
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.jammer == null:
			continue
		if e.building != null and (not e.building.built or world.get_player(e.player_id).low_power()):
			continue
		world.active_jammers.append(e)
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.drone == null:
			continue
		var d: SimDrone = e.drone
		if d.spoofed_ticks > 0:
			d.spoofed_ticks -= 1
			_hold_course(e, d.drift_x, d.drift_y)
			continue
		d.jammed = not d.fiber_optic and world.jam_level(e.player_id, e.x, e.y) > 0
		if not d.jammed:
			continue
		for w: SimWeapon in e.weapons:
			w.target_id = 0
		if world.tick % DRIFT_EVERY == (e.id % DRIFT_EVERY) or not e.mover.has_target:
			var angle: int = world.rng.range_int(Fx.ANGLE_FULL)
			d.drift_x = clampi(e.x + Fx.mul(Fx.cos_a(angle), DRIFT_STEP), 0, world.map_width)
			d.drift_y = clampi(e.y + Fx.mul(Fx.sin_a(angle), DRIFT_STEP), 0, world.map_height)
		_hold_course(e, d.drift_x, d.drift_y)


## Keeps a drone flying to (x, y), whatever it was ordered.
static func _hold_course(e: SimEntity, x: int, y: int) -> void:
	e.order = SimEntity.Order.MOVE
	e.order_target_id = 0
	if not e.mover.has_target or e.mover.target_x != x or e.mover.target_y != y:
		e.mover.order_move(x, y)
