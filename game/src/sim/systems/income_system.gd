class_name IncomeSystem
extends RefCounted
## Income from buildings (P3-08a): every INTERVAL ticks each owned, built
## building with `income` (BuildingDef.income, data "income_per_10s") pays
## its owner that many credits. Oil fields, once captured. Entities in id
## order, so every machine adds the same amounts in the same order.

const INTERVAL: int = 10 * SimWorld.TICK_RATE


static func step(world: SimWorld) -> void:
	if world.content == null or world.tick == 0 or world.tick % INTERVAL != 0:
		return
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.player_id == 0 or e.building == null or not e.building.built:
			continue
		var def: BuildingDef = world.content.get_building(e.def_id)
		if def == null or def.income <= 0 or e.building.is_disabled(world.tick):
			continue
		world.get_player(e.player_id).credits += def.income
		world.events.append({"type": "income", "id": e.id, "player": e.player_id, "amount": def.income})
