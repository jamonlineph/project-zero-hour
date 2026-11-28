class_name StrikeSystem
extends RefCounted
## Interceptable strikes (P2-07): missiles and strike aircraft are entities.
##
## launch() creates one at the map edge on the launching player's side, flying
## straight at the aim point. On arrival it delivers its payload (`count`
## impacts scattered by SimRng within `spread`, splash hurting enemies only).
## A missile is then gone; an aircraft flies back off the map. Air-defense
## weapons can shoot them down on the way (they are armor class "aircraft").
## Strikes can't be selected and don't count as units for victory.


## Launches `def` for `player_id` at (x, y). Returns the entity id (0 if not).
static func launch(world: SimWorld, def: StrikeDef, player_id: int, x: int, y: int) -> int:
	if def == null:
		return 0
	var from_x: int = home_edge(world, player_id)
	var e := SimEntity.new()
	e.id = world.claim_entity_id()
	e.player_id = player_id
	e.def_id = def.id
	e.armor_class = "aircraft"
	e.x = from_x
	e.y = clampi(y, 0, world.map_height)
	e.prev_x = e.x
	e.prev_y = e.y
	e.facing = 0 if from_x == 0 else Fx.ANGLE_HALF
	e.prev_facing = e.facing
	e.radius = def.radius
	e.vision = def.vision
	e.max_hp = def.max_hp
	e.hp = def.max_hp
	e.mover = SimMover.new()
	e.mover.speed = def.speed
	e.mover.flying = true
	e.strike = SimStrike.new()
	e.strike.def_id = def.id
	e.strike.aircraft = def.kind == "aircraft"
	e.strike.dest_x = clampi(x, 0, world.map_width)
	e.strike.dest_y = clampi(y, 0, world.map_height)
	e.strike.exit_x = from_x
	e.strike.exit_y = e.y
	e.order = SimEntity.Order.MOVE
	e.mover.order_move(e.strike.dest_x, e.strike.dest_y)
	world.add_entity(e)
	world.events.append({"type": "strike_launched", "id": e.id, "def_id": def.id, "player": player_id,
			"x": e.strike.dest_x, "y": e.strike.dest_y})
	return e.id


static func step(world: SimWorld) -> void:
	if world.content == null:
		return
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.strike == null:
			continue
		var s: SimStrike = e.strike
		var arrived: bool = not e.mover.has_target and not e.mover.needs_path
		if not arrived:
			continue
		if not s.delivered:
			if s.cargo != "":
				_drop_cargo(world, e)
			else:
				_deliver(world, e, world.content.get_strike(s.def_id))
			s.delivered = true
			if s.aircraft:
				e.mover.order_move(s.exit_x, s.exit_y)
				continue
		e.dead = true   # a missile after impact, or an aircraft back off the map
		world.events.append({"type": "strike_done", "id": e.id})


static func _deliver(world: SimWorld, e: SimEntity, def: StrikeDef) -> void:
	if def == null:
		return
	var ground := PackedStringArray(["ground"])
	for i: int in def.count:
		var x: int = e.strike.dest_x
		var y: int = e.strike.dest_y
		if def.spread > 0:
			var angle: int = world.rng.range_int(Fx.ANGLE_FULL)
			var dist: int = world.rng.range_int(def.spread + 1)
			x = clampi(x + Fx.mul(Fx.cos_a(angle), dist), 0, world.map_width)
			y = clampi(y + Fx.mul(Fx.sin_a(angle), dist), 0, world.map_height)
		CombatSystem.impact(world, e.player_id, e.id, 0, x, y, def.damage, def.damage_type,
				def.splash_radius, def.splash_edge_percent, ground)


## A cargo flight (P3-02e) drops its unit at the office it was ordered at,
## or where it was headed if that office is gone.
static func _drop_cargo(world: SimWorld, e: SimEntity) -> void:
	var def: UnitDef = world.content.get_unit(e.strike.cargo)
	if def == null:
		return
	var office: SimEntity = world.get_entity(e.strike.cargo_home)
	var id: int = 0
	if office != null and not office.dead and office.player_id == e.player_id:
		id = ProductionSystem.spawn_from(world, office, def)
	else:
		id = world.spawn_unit(def, e.player_id, e.strike.dest_x, e.strike.dest_y)
	world.events.append({"type": "delivered", "id": id, "def_id": def.id, "player": e.player_id})


## The map edge on the launching player's side: the side nearer their first
## building (their base), else the west edge.
static func home_edge(world: SimWorld, player_id: int) -> int:
	for id: int in world.entity_ids:
		var b: SimEntity = world.entities[id]
		if b.player_id == player_id and b.building != null and not b.dead:
			return 0 if b.x < world.map_width / 2 else world.map_width
	return 0
