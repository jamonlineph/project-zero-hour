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
## - GUARD (P1-24b): stay within GUARD_FOLLOW of the ward. The nearest visible
##   enemy within GUARD_RADIUS of the ward is attacked (chased only while it
##   stays inside that radius). Ends when the ward dies.
## - PATROL (P1-24b): attack-move to the far end, then turn around: each unit
##   goes back and forth between its own start and the place it reached.

const REPATH_TICKS: int = 15
const GUARD_RADIUS: int = 25 * Fx.ONE
const GUARD_FOLLOW: int = 6 * Fx.ONE


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
			SimEntity.Order.GUARD:
				_guard(world, e)
			SimEntity.Order.PATROL:
				_patrol(world, e)


static func _attack(world: SimWorld, e: SimEntity) -> void:
	var t: SimEntity = world.get_entity(e.order_target_id)
	# Lose the target if it dies or drops out of sight (no chasing ghosts).
	if t == null or t.dead or not world.can_see(e.player_id, t.x, t.y):
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


static func _patrol(world: SimWorld, e: SimEntity) -> void:
	if e.mover == null:
		e.order = SimEntity.Order.IDLE
		return
	var engaging: bool = false
	for w: SimWeapon in e.weapons:
		var t: SimEntity = world.get_entity(w.target_id)
		if t != null and not t.dead and CombatSystem.in_range(e, w, t):
			engaging = true
	e.mover.paused = engaging
	if engaging or e.mover.has_target or e.mover.needs_path:
		return
	# Arrived: head back to the other end; this spot becomes the new far end.
	var to_x: int = e.order_from_x
	var to_y: int = e.order_from_y
	e.order_from_x = e.x
	e.order_from_y = e.y
	e.order_x = to_x
	e.order_y = to_y
	e.mover.order_move(to_x, to_y)


static func _guard(world: SimWorld, e: SimEntity) -> void:
	var ward: SimEntity = world.get_entity(e.order_target_id)
	if ward == null or ward.dead or e.mover == null:
		e.order = SimEntity.Order.IDLE
		e.order_target_id = 0
		if e.mover != null:
			e.mover.stop()
		return
	var threat: SimEntity = _threat_near(world, e, ward)
	var repath: bool = world.tick - e.order_repath_tick >= REPATH_TICKS
	if threat != null:
		var in_range: bool = false
		for w: SimWeapon in e.weapons:
			if DamageMatrix.can_target(w.targets, threat.armor_class):
				w.target_id = threat.id
				if CombatSystem.in_range(e, w, threat):
					in_range = true
		if in_range:
			if e.mover.has_target:
				e.mover.stop()
		elif not e.mover.has_target or repath:
			e.mover.order_move(threat.x, threat.y)
			e.order_repath_tick = world.tick
		return
	var reach: int = GUARD_FOLLOW + e.radius + ward.radius
	var dx: int = ward.x - e.x
	var dy: int = ward.y - e.y
	if dx * dx + dy * dy > reach * reach:
		if not e.mover.has_target or repath:
			e.mover.order_move(ward.x, ward.y)
			e.order_repath_tick = world.tick
	elif e.mover.has_target:
		e.mover.stop()


## The visible enemy nearest the ward within GUARD_RADIUS that one of e's
## weapons can hit (ties: lower id), or null.
static func _threat_near(world: SimWorld, e: SimEntity, ward: SimEntity) -> SimEntity:
	var best: SimEntity = null
	var best_d: int = 0
	for t: SimEntity in world.query_enemies(e.player_id, ward.x, ward.y, GUARD_RADIUS):
		if t.dead or not world.can_see(e.player_id, t.x, t.y):
			continue
		var hittable: bool = false
		for w: SimWeapon in e.weapons:
			if DamageMatrix.can_target(w.targets, t.armor_class):
				hittable = true
		if not hittable:
			continue
		var d: int = Fx.length_sq(t.x - ward.x, t.y - ward.y)
		if best == null or d < best_d or (d == best_d and t.id < best.id):
			best = t
			best_d = d
	return best
