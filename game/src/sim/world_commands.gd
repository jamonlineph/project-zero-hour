class_name WorldCommands
extends RefCounted
## Applies one tick's player commands to a SimWorld (split out of SimWorld in
## P2-11d): unit orders (move, stop, attack, attack-move, hold) here, the rest
## through BaseCommands, CommanderPowers, Upgrades and UnitCommands.

## Groups closer together than this keep their layout at the destination;
## more spread-out groups form a grid there instead.
const KEEP_LAYOUT_RADIUS: int = 12 * Fx.ONE


## Applies `cmds` (all queued for this tick) in the canonical order.
static func apply_all(world: SimWorld, cmds: Array) -> void:
	cmds.sort_custom(_command_before)
	for c: SimCommand in cmds:
		match c.type:
			SimCommand.Type.MOVE:
				move(world, c)
			SimCommand.Type.STOP:
				_stop(world, c)
			SimCommand.Type.ATTACK:
				_attack(world, c)
			SimCommand.Type.ATTACK_MOVE:
				move(world, c)
				for e: SimEntity in owned_movers(world, c):
					e.order = SimEntity.Order.ATTACK_MOVE
					e.order_x = c.target_x
					e.order_y = c.target_y
			SimCommand.Type.HOLD:
				_hold(world, c)
			SimCommand.Type.BUILD, SimCommand.Type.PRODUCE, SimCommand.Type.CANCEL, \
					SimCommand.Type.RALLY, SimCommand.Type.GATHER, SimCommand.Type.SELL, SimCommand.Type.REPAIR:
				BaseCommands.apply(world, c)
			SimCommand.Type.CHOOSE_POWER, SimCommand.Type.USE_POWER:
				CommanderPowers.apply_command(world, c)
			SimCommand.Type.RESEARCH, SimCommand.Type.UPGRADE_UNIT:
				Upgrades.apply_command(world, c)
			SimCommand.Type.GUARD, SimCommand.Type.PATROL, SimCommand.Type.SPOOF:
				UnitCommands.apply(world, c)
			SimCommand.Type.GARRISON, SimCommand.Type.UNLOAD:
				GarrisonSystem.apply_command(world, c)
			SimCommand.Type.USE_ABILITY:
				AbilitySystem.apply_command(world, c)
			SimCommand.Type.CAPTURE:
				CaptureSystem.apply_command(world, c)
			_:
				push_error("SimWorld: unknown command type %d" % c.type)


## Canonical command order within a tick: by player, then by sequence number.
static func _command_before(a: SimCommand, b: SimCommand) -> bool:
	if a.player_id != b.player_id:
		return a.player_id < b.player_id
	return a.seq < b.seq


## A move order. One unit near the group's center (the leader) plans a path;
## the others reuse it (see PathingSystem) and end in their own slot.
static func move(world: SimWorld, c: SimCommand) -> void:
	var movers: Array[SimEntity] = owned_movers(world, c)
	if movers.is_empty():
		return
	var n: int = movers.size()
	var cx: int = 0
	var cy: int = 0
	for e: SimEntity in movers:
		cx += e.x
		cy += e.y
	cx /= n
	cy /= n
	var spread: int = 0
	var leader: SimEntity = movers[0]
	var leader_dist: int = -1
	for e: SimEntity in movers:
		var d: int = Fx.length(e.x - cx, e.y - cy)
		spread = maxi(spread, d)
		if leader_dist < 0 or d < leader_dist:
			leader = e
			leader_dist = d
	var offsets: Array[Vector2i] = []
	if spread <= KEEP_LAYOUT_RADIUS:
		for e: SimEntity in movers:
			offsets.append(Vector2i(e.x - cx, e.y - cy))
	else:
		var spacing: int = 0
		for e: SimEntity in movers:
			spacing = maxi(spacing, e.radius * 2 + Fx.from_ratio(1, 2))
		offsets = Formation.grid_offsets(n, spacing)
		# Fill the grid from the side facing the destination, so two armies
		# marching at each other form up as mirror images (P2-12b: the grid
		# always filled west to east, which favored one side of a map).
		var fx: int = -1 if c.target_x < cx else 1
		var fy: int = -1 if c.target_y < cy else 1
		for i: int in n:
			offsets[i] = Vector2i(offsets[i].x * fx, offsets[i].y * fy)
	# Ground units in a group keep to the slowest one's pace (P2-11f); flyers
	# keep their own.
	var slowest: int = 0
	for e: SimEntity in movers:
		if not e.mover.flying and (slowest == 0 or e.mover.speed < slowest):
			slowest = e.mover.speed
	for i: int in n:
		var e: SimEntity = movers[i]
		e.mover.order_move(
			clampi(c.target_x + offsets[i].x, 0, world.map_width),
			clampi(c.target_y + offsets[i].y, 0, world.map_height))
		e.mover.follow_leader = 0 if e == leader or n == 1 else leader.id
		if n > 1 and not e.mover.flying:
			e.mover.group_speed = slowest
		e.order = SimEntity.Order.MOVE
		e.order_target_id = 0
		# A direct move order takes builders and gatherers off their jobs.
		if e.builder != null:
			e.builder.target_id = 0
		if e.gatherer != null:
			e.gatherer.state = SimGatherer.State.IDLE
			e.gatherer.auto = false
			e.gatherer.site_id = 0


static func _stop(world: SimWorld, c: SimCommand) -> void:
	for e: SimEntity in owned(world, c):
		if e.mover != null:
			e.mover.stop()
		e.order = SimEntity.Order.IDLE
		e.order_target_id = 0
		for w: SimWeapon in e.weapons:
			w.target_id = 0


## Orders armed units to destroy an enemy entity. Units with no weapon able
## to hit it ignore the order.
static func _attack(world: SimWorld, c: SimCommand) -> void:
	var t: SimEntity = world.get_entity(c.target_entity)
	if t == null or t.dead or not world.can_see(c.player_id, t.x, t.y):
		return
	if not world.are_enemies(c.player_id, t.player_id) and not BridgeSystem.standing(t):
		return   # bridges are the one neutral target (P3-11)
	for e: SimEntity in owned(world, c):
		var able: bool = false
		for w: SimWeapon in e.weapons:
			if DamageMatrix.can_target(w.targets, t.armor_class):
				able = true
		if not able:
			continue
		e.order = SimEntity.Order.ATTACK
		e.order_target_id = t.id
		e.order_repath_tick = world.tick
		if e.mover != null:
			e.mover.order_move(t.x, t.y)


static func _hold(world: SimWorld, c: SimCommand) -> void:
	for e: SimEntity in owned(world, c):
		if e.mover != null:
			e.mover.stop()
		e.order = SimEntity.Order.HOLD
		e.order_target_id = 0


## Entities named in the command that exist, are alive, belong to the
## issuing player and aren't inside a garrison. Sorted by id, duplicates removed.
static func owned(world: SimWorld, c: SimCommand) -> Array[SimEntity]:
	var ids: Array[int] = c.entity_ids.duplicate()
	ids.sort()
	var result: Array[SimEntity] = []
	var last: int = -1
	for id: int in ids:
		if id == last:
			continue
		last = id
		var e: SimEntity = world.get_entity(id)
		if e != null and not e.dead and e.player_id == c.player_id and e.inside_id == 0:
			result.append(e)
	return result


## Entities named in the command that exist, belong to the issuing player and
## can move. Sorted by id, duplicates removed.
static func owned_movers(world: SimWorld, c: SimCommand) -> Array[SimEntity]:
	var ids: Array[int] = c.entity_ids.duplicate()
	ids.sort()
	var result: Array[SimEntity] = []
	var last: int = -1
	for id: int in ids:
		if id == last:
			continue
		last = id
		var e: SimEntity = world.get_entity(id)
		if e != null and e.player_id == c.player_id and e.mover != null and e.inside_id == 0:
			result.append(e)
	return result
