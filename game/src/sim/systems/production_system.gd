class_name ProductionSystem
extends RefCounted
## Finished buildings work through their production queues (P1-13).
##
## The first item gains one tick of progress per tick (every other tick when
## the player is low on power). When done, the unit appears at the building's
## exit (the open cell next to it nearest its south side), drives to the rally
## point if one is set, and gatherers start gathering on their own.


static func step(world: SimWorld) -> void:
	if world.content == null:
		return
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var b: SimBuilding = e.building
		if b == null or e.dead or not b.built or b.queue.is_empty():
			continue
		if world.get_player(e.player_id).low_power() and world.tick % 2 == 1:
			continue
		var def: UnitDef = world.content.get_unit(b.queue[0])
		if def == null:
			b.queue.remove_at(0)
			b.queue_progress = 0
			continue
		b.queue_progress += 1
		if b.queue_progress < def.build_ticks:
			continue
		b.queue.remove_at(0)
		b.queue_progress = 0
		spawn_from(world, e, def)


## Creates a unit at a building's exit and sends it to the rally point.
static func spawn_from(world: SimWorld, building: SimEntity, def: UnitDef) -> int:
	var b: SimBuilding = building.building
	var south := Vector2i(building.x, (b.cell_y + b.h) * SimMap.CELL + SimMap.CELL / 2)
	var exit: Vector2i = world.approach_point(building, south.x, south.y)
	var id: int = world.spawn_unit(def, building.player_id, exit.x, exit.y, Fx.ANGLE_QUARTER)
	var u: SimEntity = world.get_entity(id)
	world.events.append({"type": "produced", "id": id, "def_id": def.id, "player": building.player_id, "building": building.id})
	if b.has_rally and u.mover != null:
		u.mover.order_move(b.rally_x, b.rally_y)
		u.order = SimEntity.Order.MOVE
	return id
