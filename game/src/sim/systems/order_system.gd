class_name OrderSystem
extends RefCounted
## Carries out unit orders each tick, before pathing (P1-10).
##
## - MOVE: becomes IDLE on arrival. Weapons still fire at anything in range.
## - ATTACK: chase the target until a weapon has it in range, then stop and
##   fire. The chase path is re-planned every REPATH_TICKS while the target
##   moves. Ends when the target dies.
## - ATTACK_MOVE: drive toward the point, but pause to fight whenever a weapon
##   has a target in range. Becomes IDLE on arrival.
## - HOLD / IDLE: never move on their own; weapons fire at anything in range.

const REPATH_TICKS: int = 15


static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead:
			continue
		match e.order:
			SimEntity.Order.MOVE:
				if e.mover == null or (not e.mover.has_target and not e.mover.needs_path):
					e.order = SimEntity.Order.IDLE
			SimEntity.Order.ATTACK:
				_attack(world, e)
			SimEntity.Order.ATTACK_MOVE:
				_attack_move(world, e)


static func _attack(world: SimWorld, e: SimEntity) -> void:
	var t: SimEntity = world.get_entity(e.order_target_id)
	if t == null or t.dead:
		e.order = SimEntity.Order.IDLE
		e.order_target_id = 0
		if e.mover != null:
			e.mover.stop()
		return
	var in_range: bool = false
	for w: SimWeapon in e.weapons:
		if DamageMatrix.can_target(w.targets, t.armor_class):
			w.target_id = t.id
			if CombatSystem.in_range(e, w, t):
				in_range = true
	if e.mover == null:
		return
	if in_range:
		if e.mover.has_target:
			e.mover.stop()
	elif not e.mover.has_target or world.tick - e.order_repath_tick >= REPATH_TICKS:
		e.mover.order_move(t.x, t.y)
		e.order_repath_tick = world.tick


static func _attack_move(world: SimWorld, e: SimEntity) -> void:
	var engaging: bool = false
	for w: SimWeapon in e.weapons:
		var t: SimEntity = world.get_entity(w.target_id)
		if t != null and not t.dead and CombatSystem.in_range(e, w, t):
			engaging = true
	if e.mover == null:
		return
	e.mover.paused = engaging
	if not engaging and not e.mover.has_target and not e.mover.needs_path:
		e.order = SimEntity.Order.IDLE
