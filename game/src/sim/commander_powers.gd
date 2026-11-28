class_name CommanderPowers
extends RefCounted
## Commander power tree (P2-09): choosing powers with rank points, and using
## them. Every effect builds ordinary sim entities (strikes, units, sensors),
## so they are deterministic and interceptable where that makes sense.
##
## Points: rank 1 gives 1 point and every rank one more, so a player can
## hold `rank` powers. A power's tier is the rank needed to choose it.

const SENSOR_HP: int = 1


## Points not yet spent.
static func points(player: SimPlayer) -> int:
	return player.rank - player.powers.size()


## True if the player can't choose another power of this group (P3-12b):
## one is allowed, plus one for each chosen power with extra_in_group.
static func in_group(world: SimWorld, player: SimPlayer, group: String) -> bool:
	var chosen: int = 0
	var allowed: int = 1
	for id: String in player.powers:
		var p: PowerDef = world.content.get_power(id)
		if p == null:
			continue
		if p.group == group:
			chosen += 1
		if p.extra_in_group == group:
			allowed += 1
	return chosen >= allowed


static func apply_command(world: SimWorld, c: SimCommand) -> void:
	if world.content == null:
		return
	var def: PowerDef = world.content.get_power(c.def_id)
	var player: SimPlayer = world.get_player(c.player_id)
	if def == null or (def.faction != player.faction and player.faction != ""):
		return
	match c.type:
		SimCommand.Type.CHOOSE_POWER:
			if player.powers.has(def.id) or player.rank < def.tier or points(player) <= 0:
				return
			if def.group != "" and in_group(world, player, def.group):
				return   # one doctrine per match (P3-12b)
			player.powers.append(def.id)
			world.events.append({"type": "power_chosen", "player": c.player_id, "power": def.id})
			if def.grants_upgrade != "":
				Upgrades.grant(world, c.player_id, def.grants_upgrade)
		SimCommand.Type.USE_POWER:
			if not player.powers.has(def.id) or def.kind == "unlock":
				return
			if world.tick < int(player.power_ready.get(def.id, 0)):
				return
			if _use(world, c, def):
				player.power_ready[def.id] = world.tick + def.cooldown_ticks
				world.events.append({"type": "power_used", "player": c.player_id, "power": def.id,
						"x": c.target_x, "y": c.target_y})


## Applies the effect. Returns false (no cooldown) if it couldn't be used.
static func _use(world: SimWorld, c: SimCommand, def: PowerDef) -> bool:
	var x: int = clampi(c.target_x, 0, world.map_width)
	var y: int = clampi(c.target_y, 0, world.map_height)
	match def.kind:
		"reveal":
			var s: SimEntity = _sensor(world, c.player_id, x, y, def.radius, def.duration_ticks)
			s.spotter = true
		"strike":
			if def.needs_spotted and not world.is_spotted(c.player_id, x, y):
				return false
			var strike: StrikeDef = world.content.get_strike(def.strike_id)
			for i: int in def.count:
				StrikeSystem.launch(world, strike, c.player_id, x, y)
		"drone_sweep":
			var from_x: int = StrikeSystem.home_edge(world, c.player_id)
			var s: SimEntity = _sensor(world, c.player_id, from_x, y, def.radius, def.duration_ticks)
			s.spotter = true
			s.mover = SimMover.new()
			s.mover.flying = true
			s.mover.speed = Fx.from_ratio(3000, 100 * SimWorld.TICK_RATE)   # 30 m/s
			s.order = SimEntity.Order.MOVE
			s.mover.order_move(world.map_width - from_x, y)
		"reinforce":
			var hq: SimEntity = _hq(world, c.player_id)
			if hq == null:
				return false
			var unit: UnitDef = world.content.get_unit(def.unit_id)
			for i: int in def.count:
				var p: Vector2i = world.approach_point(hq, hq.x + (i - 1) * 4 * Fx.ONE, hq.y + 20 * Fx.ONE)
				world.spawn_unit(unit, c.player_id, p.x, p.y, Fx.ANGLE_QUARTER)
		"jam_area":
			var s: SimEntity = _sensor(world, c.player_id, x, y, 0, def.duration_ticks)
			s.jammer = SimJammer.new()
			s.jammer.radius = def.radius
			s.jammer.strength = 1
		"wingmen":
			var unit: UnitDef = world.content.get_unit(def.unit_id)
			var from_x: int = StrikeSystem.home_edge(world, c.player_id)
			var ids: Array[int] = []
			for i: int in def.count:
				var id: int = world.spawn_unit(unit, c.player_id, from_x, clampi(y + (i * 2 - 1) * 6 * Fx.ONE, 0, world.map_height))
				world.get_entity(id).ttl = def.duration_ticks
				ids.append(id)
			var patrol := SimCommand.make_patrol(ids, x, y)
			patrol.player_id = c.player_id
			UnitCommands.apply(world, patrol)
		"repair_area":
			# Field repair (P3-12a): own vehicles in the area get `percent` of
			# their max hp back at once.
			for t: SimEntity in world.query_radius(x, y, def.radius):
				if t.player_id == c.player_id and not t.dead and t.building == null \
						and t.armor_class in ["light_vehicle", "heavy_armor"]:
					t.hp = mini(t.max_hp, t.hp + (t.max_hp * def.percent) / 100)
		"laser_shield":
			# Laser shield (P3-02f): air-defense sites in the area also burn
			# down shells, rockets, missiles and drones.
			LaserShield.activate(world, c.player_id, x, y, def.radius, def.duration_ticks)
		"procurement_rush":
			# Emergency procurement (P3-02e): the next off-map order is flown in
			# in half the time.
			world.get_player(c.player_id).procurement_rush = true
		"cyber_defense":
			# Your drones and guided weapons ignore jamming and spoofing (P3-12a).
			var me: SimPlayer = world.get_player(c.player_id)
			me.jam_immune_until = maxi(me.jam_immune_until, world.tick + def.duration_ticks)
		"cyber":
			for pid: int in world.players:
				if world.are_enemies(c.player_id, pid):
					world.players[pid].blinded_until = world.tick + def.duration_ticks
		"decoys":
			var unit: UnitDef = world.content.get_unit(def.unit_id)
			for i: int in def.count:
				var dx: int = ((i % 3) - 1) * 9 * Fx.ONE
				var dy: int = ((i / 3) - 1) * 9 * Fx.ONE
				var p: Vector2i = world.pathfinder.nearest_open_point(x + dx, y + dy)
				world.spawn_unit(unit, c.player_id, p.x, p.y, Fx.ANGLE_QUARTER)
		_:
			return false
	return true


## An untargetable, temporary entity that gives vision (and maybe jamming).
static func _sensor(world: SimWorld, player_id: int, x: int, y: int, vision: int, ttl: int) -> SimEntity:
	var e := SimEntity.new()
	e.id = world.claim_entity_id()
	e.player_id = player_id
	e.def_id = "sensor"
	e.armor_class = "sensor"   # in no target category: nothing can shoot it
	e.sensor = true
	e.x = x
	e.y = y
	e.prev_x = x
	e.prev_y = y
	e.vision = vision
	e.max_hp = SENSOR_HP
	e.hp = SENSOR_HP
	e.ttl = ttl
	world.add_entity(e)
	return e


static func _hq(world: SimWorld, player_id: int) -> SimEntity:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == player_id and not e.dead and e.def_id.ends_with("_command_hq"):
			return e
	return null


## Removes temporary entities (sensors, wingmen) when their time is up, and a
## drone sweep once it reaches the far edge.
static func expire(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.ttl <= 0:
			continue
		e.ttl -= 1
		var swept: bool = e.sensor and e.mover != null and not e.mover.has_target and not e.mover.needs_path
		if e.ttl == 0 or swept:
			e.dead = true
			world.events.append({"type": "expired", "id": e.id})
