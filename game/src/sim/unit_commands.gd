class_name UnitCommands
extends RefCounted
## GUARD and PATROL commands (P1-24b). Kept out of SimWorld, which is already
## large; SimWorld._apply_commands() calls apply(). Ints only.


static func apply(world: SimWorld, c: SimCommand) -> void:
	match c.type:
		SimCommand.Type.GUARD:
			_guard(world, c)
		SimCommand.Type.PATROL:
			_patrol(world, c)
		SimCommand.Type.SPOOF:
			_spoof(world, c)


## Armed movers stay near the ward and defend it. The ward must be our own or
## an ally's (not neutral, not an enemy) and alive.
static func _guard(world: SimWorld, c: SimCommand) -> void:
	var ward: SimEntity = world.get_entity(c.target_entity)
	if ward == null or ward.dead or ward.player_id == 0 or world.are_enemies(c.player_id, ward.player_id):
		return
	for e: SimEntity in WorldCommands.owned_movers(world, c):
		if e.id == ward.id or e.weapons.is_empty():
			continue
		e.order = SimEntity.Order.GUARD
		e.order_target_id = ward.id
		e.order_repath_tick = world.tick
		for w: SimWeapon in e.weapons:
			w.target_id = 0
		e.mover.order_move(ward.x, ward.y)


## Moves like attack-move, then OrderSystem sends each unit back and forth
## between its own start and the slot it reached.
static func _patrol(world: SimWorld, c: SimCommand) -> void:
	var movers: Array[SimEntity] = WorldCommands.owned_movers(world, c)
	var starts: Dictionary[int, Vector2i] = {}
	for e: SimEntity in movers:
		starts[e.id] = Vector2i(e.x, e.y)
	WorldCommands.move(world, c)
	for e: SimEntity in movers:
		e.order = SimEntity.Order.PATROL
		e.order_x = c.target_x
		e.order_y = c.target_y
		e.order_from_x = starts[e.id].x
		e.order_from_y = starts[e.id].y


## The first ready jammer in range spoofs every enemy drone (not fiber-optic)
## within its spoof radius of the point: each flies to a random point and,
## if armed, attacks a random entity nearby, of any side (P2-03).
static func _spoof(world: SimWorld, c: SimCommand) -> void:
	for e: SimEntity in WorldCommands.owned(world, c):
		var j: SimJammer = e.jammer
		if j == null or j.spoof_radius <= 0 or world.tick < j.spoof_ready_tick:
			continue
		var dx: int = c.target_x - e.x
		var dy: int = c.target_y - e.y
		if dx * dx + dy * dy > j.spoof_range * j.spoof_range:
			continue
		j.spoof_ready_tick = world.tick + j.spoof_cooldown
		world.events.append({"type": "spoofed", "id": e.id, "x": c.target_x, "y": c.target_y, "radius": j.spoof_radius})
		var victims: Array[SimEntity] = world.query_enemies(e.player_id, c.target_x, c.target_y, j.spoof_radius)
		victims.sort_custom(func(a: SimEntity, b: SimEntity) -> bool: return a.id < b.id)
		for v: SimEntity in victims:
			if v.dead or v.drone == null or v.drone.fiber_optic:
				continue
			if world.tick >= world.get_player(v.player_id).jam_immune_until:   # cyber defense (P3-12a)
				_spoof_one(world, v)
		return


static func _spoof_one(world: SimWorld, v: SimEntity) -> void:
	var d: SimDrone = v.drone
	d.spoofed_ticks = JammingSystem.SPOOF_TICKS
	var angle: int = world.rng.range_int(Fx.ANGLE_FULL)
	var dist: int = 10 * Fx.ONE + world.rng.range_int(20 * Fx.ONE)
	d.drift_x = clampi(v.x + Fx.mul(Fx.cos_a(angle), dist), 0, world.map_width)
	d.drift_y = clampi(v.y + Fx.mul(Fx.sin_a(angle), dist), 0, world.map_height)
	for w: SimWeapon in v.weapons:
		var reach: int = w.max_range + SimWorld.MAX_UNIT_RADIUS
		var near: Array[SimEntity] = []
		for t: SimEntity in world.query_radius(v.x, v.y, reach):
			if t.id != v.id and not t.dead and t.player_id != 0 and DamageMatrix.can_target(w.targets, t.armor_class):
				near.append(t)
		near.sort_custom(func(a: SimEntity, b: SimEntity) -> bool: return a.id < b.id)
		w.target_id = near[world.rng.range_int(near.size())].id if not near.is_empty() else 0
