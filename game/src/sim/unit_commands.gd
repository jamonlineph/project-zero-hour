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


## Armed movers stay near the ward and defend it. The ward must be our own or
## an ally's (not neutral, not an enemy) and alive.
static func _guard(world: SimWorld, c: SimCommand) -> void:
	var ward: SimEntity = world.get_entity(c.target_entity)
	if ward == null or ward.dead or ward.player_id == 0 or world.are_enemies(c.player_id, ward.player_id):
		return
	for e: SimEntity in world.owned_movers_of(c):
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
	var movers: Array[SimEntity] = world.owned_movers_of(c)
	var starts: Dictionary[int, Vector2i] = {}
	for e: SimEntity in movers:
		starts[e.id] = Vector2i(e.x, e.y)
	world.apply_move(c)
	for e: SimEntity in movers:
		e.order = SimEntity.Order.PATROL
		e.order_x = c.target_x
		e.order_y = c.target_y
		e.order_from_x = starts[e.id].x
		e.order_from_y = starts[e.id].y
