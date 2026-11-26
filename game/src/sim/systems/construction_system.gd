class_name ConstructionSystem
extends RefCounted
## Builders construct and repair buildings (P1-12).
##
## A builder drives next to its building, then works on it every tick. The
## first builder adds 2 half-steps of progress per tick and each extra one adds
## 1 (diminishing returns). Health rises with progress (damage taken during
## construction is kept). A finished building may give a free unit.
## Repairs restore 1% of max health per second per builder and cost half the
## building's price per 100% repaired.

const REACH: int = 2 * Fx.ONE
const REPAIR_PERCENT_PER_SECOND: int = 1


static func step(world: SimWorld) -> void:
	var workers: Dictionary[int, int] = {}   ## building id -> builders working this tick
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.builder == null or e.builder.target_id == 0 or e.dead:
			continue
		var t: SimEntity = world.get_entity(e.builder.target_id)
		var done: bool = t == null or t.dead or t.building == null or t.player_id != e.player_id
		if not done:
			done = t.building.built and (not e.builder.repair or t.hp >= t.max_hp)
		if done:
			e.builder.target_id = 0
			continue
		if world.distance_to_body(e.x, e.y, t) <= e.radius + REACH:
			if e.mover != null and e.mover.has_target:
				e.mover.stop()
			workers[t.id] = workers.get(t.id, 0) + 1
		elif e.mover != null and not e.mover.has_target:
			var spot: Vector2i = world.approach_point(t, e.x, e.y)
			e.mover.order_move(spot.x, spot.y)
	var ids: Array[int] = []
	for bid: int in workers:
		ids.append(bid)
	ids.sort()
	for bid: int in ids:
		var t: SimEntity = world.get_entity(bid)
		var n: int = workers[bid]
		if not t.building.built:
			_advance(world, t, 2 + (n - 1))
		elif world.tick % SimWorld.TICK_RATE == 0:
			_repair(world, t, n)


static func _advance(world: SimWorld, t: SimEntity, steps: int) -> void:
	var b: SimBuilding = t.building
	var start_hp: int = maxi(1, t.max_hp / 10)
	var before: int = start_hp + ((t.max_hp - start_hp) * b.progress) / b.total
	b.progress = mini(b.total, b.progress + steps)
	var after: int = start_hp + ((t.max_hp - start_hp) * b.progress) / b.total
	t.hp = mini(t.max_hp, t.hp + after - before)
	if b.progress < b.total:
		return
	b.built = true
	world.events.append({"type": "built", "id": t.id, "def_id": t.def_id, "player": t.player_id})
	if b.free_unit != "" and world.content != null:
		var def: UnitDef = world.content.get_unit(b.free_unit)
		if def != null:
			ProductionSystem.spawn_from(world, t, def)


static func _repair(world: SimWorld, t: SimEntity, builders: int) -> void:
	var player: SimPlayer = world.get_player(t.player_id)
	var heal: int = mini(t.max_hp - t.hp, maxi(1, (t.max_hp * REPAIR_PERCENT_PER_SECOND * builders) / 100))
	var price: int = (t.cost * heal) / (2 * t.max_hp)
	if player.credits < price:
		return
	player.credits -= price
	t.hp += heal
