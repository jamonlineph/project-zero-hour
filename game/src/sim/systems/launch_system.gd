class_name LaunchSystem
extends RefCounted
## Swarm-drone launchers (P3-02c): when a launcher's cooldown is over and an
## enemy ground target it can see is within range, it launches `count` drones
## of its `unit_id` around itself and sends them to attack-move to that
## target's position. The drones are ordinary flying units: lasers, jammers
## and rifles can bring them down, and they crash when their endurance runs
## out (they have no launcher building to return to).
## Runs after the spatial index is rebuilt, before crushing and combat.

const SPAWN_RING: int = 2 * Fx.ONE   ## drones appear this far around the launcher


static func step(world: SimWorld) -> void:
	# Collect first: launching adds entities, and entity_ids must not change
	# while it is being walked.
	var ready: Array[SimEntity] = []
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.launcher != null and not e.dead and e.inside_id == 0 and world.tick >= e.launcher.ready_tick:
			ready.append(e)
	for e: SimEntity in ready:
		var target: SimEntity = _target(world, e)
		if target == null:
			continue
		_launch(world, e, target)


## The nearest enemy on the ground that the launcher's side can see (lowest
## id on a tie, so every machine agrees).
static func _target(world: SimWorld, e: SimEntity) -> SimEntity:
	var best: SimEntity = null
	var best_dist: int = 0
	for t: SimEntity in world.query_enemies(e.player_id, e.x, e.y, e.launcher.range):
		if t.dead or t.inside_id != 0 or (t.mover != null and t.mover.flying):
			continue
		if not world.can_see(e.player_id, t.x, t.y) or DecoySystem.is_known_decoy(world, e.player_id, t):
			continue
		var d: int = Fx.length(t.x - e.x, t.y - e.y)
		if best == null or d < best_dist or (d == best_dist and t.id < best.id):
			best = t
			best_dist = d
	return best


static func _launch(world: SimWorld, e: SimEntity, target: SimEntity) -> void:
	var def: UnitDef = world.content.get_unit(e.launcher.unit_id) if world.content != null else null
	if def == null:
		return
	var ids: Array[int] = []
	for i: int in e.launcher.count:
		var angle: int = (i * Fx.ANGLE_FULL) / maxi(1, e.launcher.count)
		var x: int = clampi(e.x + Fx.mul(Fx.cos_a(angle), SPAWN_RING), 0, world.map_width)
		var y: int = clampi(e.y + Fx.mul(Fx.sin_a(angle), SPAWN_RING), 0, world.map_height)
		ids.append(world.spawn_unit(def, e.player_id, x, y, angle))
	var c := SimCommand.make_attack_move(ids, target.x, target.y)
	c.player_id = e.player_id
	WorldCommands.apply_all(world, [c])
	e.launcher.ready_tick = world.tick + e.launcher.cooldown_ticks
	world.events.append({"type": "launched", "id": e.id, "player": e.player_id, "count": ids.size(),
			"x": target.x, "y": target.y})
