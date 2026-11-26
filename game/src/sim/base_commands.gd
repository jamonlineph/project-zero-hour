class_name BaseCommands
extends RefCounted
## Validates and applies base-building and economy commands (P1-12 to P1-15).
## Every check happens here, in the sim, so invalid commands from any client
## are ignored the same way on every machine.


static func apply(world: SimWorld, c: SimCommand) -> void:
	match c.type:
		SimCommand.Type.BUILD:
			_build(world, c)
		SimCommand.Type.PRODUCE:
			_produce(world, c)
		SimCommand.Type.CANCEL:
			_cancel(world, c)
		SimCommand.Type.RALLY:
			_rally(world, c)
		SimCommand.Type.GATHER:
			_gather(world, c)
		SimCommand.Type.SELL:
			_sell(world, c)
		SimCommand.Type.REPAIR:
			_repair(world, c)


## The player's own living building with this id, or null.
static func _own_building(world: SimWorld, c: SimCommand) -> SimEntity:
	var b: SimEntity = world.get_entity(c.target_entity)
	if b == null or b.dead or b.building == null or b.player_id != c.player_id:
		return null
	return b


static func _build(world: SimWorld, c: SimCommand) -> void:
	if world.content == null:
		return
	var def: BuildingDef = world.content.get_building(c.def_id)
	var player: SimPlayer = world.get_player(c.player_id)
	if def == null or def.faction != player.faction and player.faction != "":
		return
	var builders: Array[SimEntity] = []
	for e: SimEntity in world.owned_entities(c):
		if e.builder != null:
			builders.append(e)
	if builders.is_empty() or player.credits < def.cost:
		return
	if not world.has_requirements(c.player_id, def.requires):
		return
	var origin: Vector2i = SimWorld.footprint_origin(def, c.target_x, c.target_y)
	if not world.can_place(def, origin):
		return
	var id: int = world.spawn_building(def, c.player_id, origin.x, origin.y, false)
	if id == 0:
		return
	player.credits -= def.cost
	world.events.append({"type": "placed", "id": id, "def_id": def.id, "player": c.player_id})
	for e: SimEntity in builders:
		_assign_builder(world, e, id, false)


static func _assign_builder(world: SimWorld, e: SimEntity, building_id: int, repair: bool) -> void:
	e.builder.target_id = building_id
	e.builder.repair = repair
	e.order = SimEntity.Order.IDLE
	var b: SimEntity = world.get_entity(building_id)
	var spot: Vector2i = world.approach_point(b, e.x, e.y)
	e.mover.order_move(spot.x, spot.y)


static func _produce(world: SimWorld, c: SimCommand) -> void:
	var b: SimEntity = _own_building(world, c)
	if b == null or world.content == null or not b.building.built:
		return
	if not b.building.produces.has(c.def_id) or b.building.queue.size() >= SimBuilding.MAX_QUEUE:
		return
	var def: UnitDef = world.content.get_unit(c.def_id)
	var player: SimPlayer = world.get_player(c.player_id)
	if def == null or player.credits < def.cost or not world.has_requirements(c.player_id, def.requires):
		return
	if def.requires_unlock != "" and not player.powers.has(def.requires_unlock):
		return   # a commander unlock is needed first (P2-09)
	player.credits -= def.cost
	b.building.queue.append(def.id)


static func _cancel(world: SimWorld, c: SimCommand) -> void:
	var b: SimEntity = _own_building(world, c)
	if b == null or c.index < 0 or c.index >= b.building.queue.size():
		return
	var unit_id: String = b.building.queue[c.index]
	b.building.queue.remove_at(c.index)
	if c.index == 0:
		b.building.queue_progress = 0
	if world.content != null:
		world.get_player(c.player_id).credits += world.content.cost_of(unit_id)


static func _rally(world: SimWorld, c: SimCommand) -> void:
	var b: SimEntity = _own_building(world, c)
	if b == null:
		return
	b.building.has_rally = true
	b.building.rally_x = clampi(c.target_x, 0, world.map_width)
	b.building.rally_y = clampi(c.target_y, 0, world.map_height)


static func _gather(world: SimWorld, c: SimCommand) -> void:
	var site: SimEntity = world.get_entity(c.target_entity)
	if site == null or site.supply == null or site.supply.remaining <= 0:
		return
	for e: SimEntity in world.owned_entities(c):
		if e.gatherer == null:
			continue
		e.order = SimEntity.Order.IDLE
		e.gatherer.auto = true
		e.gatherer.site_id = site.id
		e.gatherer.state = SimGatherer.State.TO_SITE if e.gatherer.carried == 0 else SimGatherer.State.TO_DROPOFF
		e.mover.stop()


## Sells a finished building for half its cost, scaled by remaining health.
static func _sell(world: SimWorld, c: SimCommand) -> void:
	var b: SimEntity = _own_building(world, c)
	if b == null or not b.building.built:
		return
	world.get_player(c.player_id).credits += (b.cost * b.hp) / (2 * b.max_hp)
	b.dead = true
	world.events.append({"type": "sold", "id": b.id, "def_id": b.def_id, "player": b.player_id, "x": b.x, "y": b.y})


static func _repair(world: SimWorld, c: SimCommand) -> void:
	var b: SimEntity = _own_building(world, c)
	if b == null:
		return
	for e: SimEntity in world.owned_entities(c):
		if e.builder != null:
			_assign_builder(world, e, b.id, b.building.built)
