class_name WorldSpawn
extends RefCounted
## Builds new entities from their definitions (split out of SimWorld in
## P2-11d). SimWorld assigns the ids and registers the entities.


## A unit with id `id` at (x, y) (fixed-point meters, clamped to the map).
static func make_unit(world: SimWorld, def: UnitDef, id: int, player_id: int, x: int, y: int, facing: int) -> SimEntity:
	var e := SimEntity.new()
	e.id = id
	e.player_id = player_id
	e.def_id = def.id
	e.armor_class = def.armor_class
	e.x = clampi(x, 0, world.map_width)
	e.y = clampi(y, 0, world.map_height)
	e.prev_x = e.x
	e.prev_y = e.y
	e.facing = Fx.wrap_angle(facing)
	e.prev_facing = e.facing
	e.radius = def.radius
	e.vision = def.vision
	e.max_hp = def.max_hp
	e.hp = def.max_hp
	if def.speed > 0:
		e.mover = SimMover.new()
		e.mover.speed = def.speed
		e.mover.turn_rate = def.turn_rate
		e.mover.flying = def.flying
	if def.endurance_ticks > 0:
		e.drone = SimDrone.new()
		e.drone.endurance_max = def.endurance_ticks
		e.drone.endurance = def.endurance_ticks
		e.drone.fiber_optic = def.fiber_optic
	e.spotter = def.spotter
	e.crusher = def.crusher
	if def.launch_unit != "":
		e.launcher = SimLauncher.new()
		e.launcher.unit_id = def.launch_unit
		e.launcher.count = def.launch_count
		e.launcher.range = def.launch_range
		e.launcher.cooldown_ticks = def.launch_cooldown_ticks
	e.aps_max = def.aps_charges
	e.aps_charges = def.aps_charges
	e.cage_hits = def.cage_hits
	e.decoy_of = def.decoy_of
	if def.jam_radius > 0:
		e.jammer = SimJammer.new()
		e.jammer.radius = def.jam_radius
		e.jammer.strength = maxi(1, def.jam_strength)
		e.jammer.spoof_radius = def.spoof_radius
		e.jammer.spoof_range = def.spoof_range
		e.jammer.spoof_cooldown = def.spoof_cooldown_ticks
	for w: WeaponDef in def.weapons:
		e.weapons.append(SimWeapon.from_def(w))
	e.cost = def.cost
	if def.builder:
		e.builder = SimBuilder.new()
	if def.gatherer:
		e.gatherer = SimGatherer.new()
		e.gatherer.capacity = def.gather_capacity
		e.gatherer.load_ticks = def.gather_load_ticks
		e.gatherer.unload_ticks = def.gather_unload_ticks
	return e


## A building whose footprint origin is cell (cx, cy).
## `size` (cells) overrides the definition's footprint (map houses, P3-05).
static func make_building(def: BuildingDef, id: int, player_id: int, cx: int, cy: int, built: bool,
		size: Vector2i = Vector2i.ZERO) -> SimEntity:
	var fw: int = size.x if size.x > 0 else def.footprint_w
	var fh: int = size.y if size.y > 0 else def.footprint_h
	var e := SimEntity.new()
	e.id = id
	e.player_id = player_id
	e.def_id = def.id
	e.armor_class = def.armor_class
	e.x = cx * SimMap.CELL + (fw * SimMap.CELL) / 2
	e.y = cy * SimMap.CELL + (fh * SimMap.CELL) / 2
	e.prev_x = e.x
	e.prev_y = e.y
	e.radius = (mini(fw, fh) * SimMap.CELL) / 2
	e.vision = def.vision
	e.max_hp = def.max_hp
	e.hp = def.max_hp if built else maxi(1, def.max_hp / 10)
	e.cost = def.cost
	var b := SimBuilding.new()
	b.cell_x = cx
	b.cell_y = cy
	b.w = fw
	b.h = fh
	b.built = built
	b.capture_ticks = def.capture_ticks
	e.spotter = def.spotter   # cell towers (P3-08b)
	b.total = def.build_ticks * 2
	b.progress = b.total if built else 0
	b.power = def.power
	b.produces = def.produces.duplicate()
	b.dropoff = def.dropoff
	b.free_unit = def.free_unit
	e.building = b
	if def.garrison_capacity > 0:
		e.garrison = SimGarrison.new()
		e.garrison.capacity = def.garrison_capacity
	for w: WeaponDef in def.weapons:
		e.weapons.append(SimWeapon.from_def(w))
	return e


## A neutral supply site on the 2x2 cells from (cx, cy).
static func make_supply_site(id: int, cx: int, cy: int, amount: int) -> SimEntity:
	var e := SimEntity.new()
	e.id = id
	e.player_id = 0
	e.def_id = "supply_site"
	e.armor_class = "structure"
	e.x = cx * SimMap.CELL + SimMap.CELL
	e.y = cy * SimMap.CELL + SimMap.CELL
	e.prev_x = e.x
	e.prev_y = e.y
	e.radius = SimMap.CELL
	e.max_hp = 1
	e.hp = 1
	e.supply = SimSupply.new()
	e.supply.remaining = amount
	return e
