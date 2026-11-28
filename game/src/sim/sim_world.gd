class_name SimWorld
extends RefCounted
## The deterministic game state and its fixed-tick update.
##
## Rules (details in docs/02-architecture.md):
## - ints only (fixed-point through Fx). No float, Vector2/3, Node, engine time
##   or engine random in here.
## - iterate entities through entity_ids (ascending id), the canonical order.
## - all randomness comes from rng; all input arrives through queue_command().

const TICK_RATE: int = 15  ## simulation ticks per second
## Upper bound on any entity's radius, used to pad area searches.
const MAX_UNIT_RADIUS: int = 12 * Fx.ONE
## Bucket size of the spatial index used for area searches.
const INDEX_BUCKET: int = SpatialIndex.BUCKET

var tick: int = 0
var rng: SimRng
var map_width: int = 0      ## fixed-point meters
var map_height: int = 0
var map: SimMap             ## passability grid (see SimMap)
var pathfinder: Pathfinder  ## A* over `map`, shared by all movers
## Stealthy entity id -> teams that can see it this tick (StealthSystem, P3-09).
var stealth_seen: Dictionary[int, Dictionary] = {}
var entities: Dictionary[int, SimEntity] = {}
var entity_ids: Array[int] = []   ## ascending ids: always iterate this
var damage_matrix: DamageMatrix = DamageMatrix.new()
var rules: SimRules = SimRules.new()
## Set when only one team (or none) is left (P1-19). winner_team 0 = draw.
var game_over: bool = false
var winner_team: int = 0
## Read-only content (unit and building definitions) for production and
## construction. Set by MatchSetup; tests may leave it null.
var content: ContentDb
var players: Dictionary[int, SimPlayer] = {}
## How players lose (P1-19): "buildings" (all buildings and builders gone),
## "units" (everything gone) or "none". Worlds made without a scenario (tests)
## default to "none"; MatchSetup defaults scenarios to "buildings".
var victory_rule: String = "none"
var vision: SimVision
## Player -> team. Players not listed are on a team of their own (team = id).
var player_team: Dictionary[int, int] = {}
var projectiles: Array[SimProjectile] = []   ## in creation order
## Jammers that are on this tick (rebuilt by JammingSystem; derived, not hashed).
var active_jammers: Array[SimEntity] = []
## Spotters that can mark targets this tick (KillChainSystem; derived, not hashed).
var active_spotters: Array[SimEntity] = []
## What happened this tick, for the view and audio (not part of the state hash).
## Dictionaries with a "type": "fired", "hit" or "died".
var events: Array[Dictionary] = []
var _next_id: int = 1
var _next_projectile_id: int = 1
var _spatial := SpatialIndex.new()   ## rebuilt each tick after movement
var _pending: Dictionary[int, Array] = {}   ## tick -> Array of SimCommand


func _init(seed_value: int = 1, width_m: int = 256, height_m: int = 256) -> void:
	rng = SimRng.new(seed_value)
	set_map(SimMap.new(width_m, height_m))


## Creates a world on a map from content data.
static func from_map(seed_value: int, def: MapDef) -> SimWorld:
	var world := SimWorld.new(seed_value, def.width_m, def.height_m)
	world.set_map(def.make_sim_map())
	return world


## Replaces the grid. Call before spawning anything.
func set_map(new_map: SimMap) -> void:
	map = new_map
	pathfinder = Pathfinder.new(new_map)
	map_width = new_map.width_cells * SimMap.CELL
	map_height = new_map.height_cells * SimMap.CELL
	vision = SimVision.new(map_width, map_height)


func team_of(player_id: int) -> int:
	return player_team.get(player_id, player_id)


func are_enemies(player_a: int, player_b: int) -> bool:
	return player_a != 0 and player_b != 0 and team_of(player_a) != team_of(player_b)


## True if `player_id`'s team currently sees the point (fixed-point meters).
func can_see(player_id: int, x: int, y: int) -> bool:
	return vision.is_visible(team_of(player_id), x, y)


## False only for a stealthy unit `player_id`'s team hasn't detected (P3-09).
func is_detected(player_id: int, t: SimEntity) -> bool:
	if not t.stealth or not are_enemies(player_id, t.player_id):
		return true
	return (stealth_seen.get(t.id, {}) as Dictionary).has(team_of(player_id))


## Adds a unit and returns its id. x and y are fixed-point meters; facing is a
## binary angle (0 = +X).
func spawn_unit(def: UnitDef, player_id: int, x: int, y: int, facing: int = 0) -> int:
	var e: SimEntity = WorldSpawn.make_unit(self, def, _next_id, player_id, x, y, facing)
	_next_id += 1
	entities[e.id] = e
	entity_ids.append(e.id)
	Upgrades.apply_global(self, e)
	return e.id


## True if a spotter on `player_id`'s team sees (x, y) this tick (P2-04).
func is_spotted(player_id: int, x: int, y: int) -> bool:
	var team: int = team_of(player_id)
	for sp: SimEntity in active_spotters:
		if team_of(sp.player_id) != team:
			continue
		var dx: int = x - sp.x
		var dy: int = y - sp.y
		if dx * dx + dy * dy <= sp.vision * sp.vision:
			return true
	return false


## Strongest hostile jamming field covering (x, y) for `victim_player`'s
## drones and guided weapons; 0 = none (P2-03). Fields don't stack.
func jam_level(victim_player: int, x: int, y: int) -> int:
	if victim_player != 0 and tick < get_player(victim_player).jam_immune_until:
		return 0   # cyber defense (P3-12a)
	var level: int = 0
	for j: SimEntity in active_jammers:
		if not are_enemies(j.player_id, victim_player):
			continue
		var r: int = j.jammer.radius
		var dx: int = x - j.x
		var dy: int = y - j.y
		if dx * dx + dy * dy <= r * r:
			level = maxi(level, j.jammer.strength)
	return level


## Reserves the next entity id (for systems that build entities themselves).
func claim_entity_id() -> int:
	_next_id += 1
	return _next_id - 1


## Adds an entity built outside spawn_unit/spawn_building (strikes, P2-07).
func add_entity(e: SimEntity) -> void:
	entities[e.id] = e
	entity_ids.append(e.id)


func get_entity(id: int) -> SimEntity:
	return entities.get(id, null)


## The player's state, created on first use (0 credits, own team).
func get_player(player_id: int) -> SimPlayer:
	if not players.has(player_id):
		var p := SimPlayer.new()
		p.id = player_id
		p.team = team_of(player_id)
		players[player_id] = p
	return players[player_id]


## Places a building with its footprint origin at cell (cx, cy). Returns its id,
## or 0 if the footprint is blocked. Unbuilt buildings start at 10% health.
func spawn_building(def: BuildingDef, player_id: int, cx: int, cy: int, built: bool) -> int:
	var id: int = _next_id
	# Walkable buildings (minefields, P3-10a) leave the map open.
	if not def.walkable and not map.place_footprint(cx, cy, def.footprint_w, def.footprint_h, id):
		return 0
	_next_id += 1
	add_entity(WorldSpawn.make_building(def, id, player_id, cx, cy, built))
	if built:
		AbilitySystem.start_charge(self, entities[id])   # a superweapon placed finished (P3-03)
	return id


## True if the footprint at `origin` is open terrain with no building on it and
## no unit standing on it (a unit there would be trapped).
func can_place(def: BuildingDef, origin: Vector2i) -> bool:
	return WorldPlacement.can_place(self, def, origin)


## Footprint origin (cells) that centers a building as near as possible on the
## point (fixed-point meters); ties go toward the middle of the map (P2-11c).
func footprint_origin(def: BuildingDef, x: int, y: int) -> Vector2i:
	return Vector2i(WorldPlacement.footprint_start(x, def.footprint_w, map_width),
		WorldPlacement.footprint_start(y, def.footprint_h, map_height))


## A neutral building on a map rectangle in meters, sized from the rectangle
## (town houses, P3-05). Returns its id, or 0 if the area is blocked.
func spawn_structure(def: BuildingDef, x_m: int, y_m: int, w_m: int, h_m: int) -> int:
	var cx: int = SimMap.cell_coord(Fx.from_int(x_m))
	var cy: int = SimMap.cell_coord(Fx.from_int(y_m))
	var size := Vector2i(maxi(1, (w_m * 100) / SimMap.CELL_CM), maxi(1, (h_m * 100) / SimMap.CELL_CM))
	var id: int = _next_id
	if not def.walkable and not map.place_footprint(cx, cy, size.x, size.y, id):
		return 0   # walkable structures (bridges, P3-11) claim no cells
	_next_id += 1
	var e: SimEntity = WorldSpawn.make_building(def, id, 0, cx, cy, true, size)
	if e.garrison != null:
		e.garrison.neutral = true
	add_entity(e)
	return id


## A neutral supply site holding `amount` credits, blocking a 2x2-cell area.
func spawn_supply_site(x: int, y: int, amount: int) -> int:
	var id: int = _next_id
	var cx: int = SimMap.cell_coord(x) - 1
	var cy: int = SimMap.cell_coord(y) - 1
	if not map.place_footprint(cx, cy, 2, 2, id):
		return 0
	_next_id += 1
	add_entity(WorldSpawn.make_supply_site(id, cx, cy, amount))
	return id


## True if the player owns a finished building of every id in `requires`.
func has_requirements(player_id: int, requires: PackedStringArray) -> bool:
	for req: String in requires:
		var found: bool = false
		for id: int in entity_ids:
			var e: SimEntity = entities[id]
			if e.player_id == player_id and e.def_id == req and e.building != null and e.building.built and not e.dead:
				found = true
				break
		if not found:
			return false
	return true


## Distance from a point to the nearest edge of an entity: its footprint for
## buildings and supply sites, its circle otherwise (fixed-point meters).
func distance_to_body(x: int, y: int, target: SimEntity) -> int:
	return WorldPlacement.distance_to_body(x, y, target)


## The open cell next to an entity's body that is nearest to (x, y): where a
## builder or gatherer parks to work on it.
func approach_point(target: SimEntity, x: int, y: int) -> Vector2i:
	return WorldPlacement.approach_point(self, target, x, y)


func queue_command(cmd: SimCommand) -> void:
	if cmd.tick < tick:
		push_error("SimWorld: dropped command for past tick %d (now %d)" % [cmd.tick, tick])
		return
	if not _pending.has(cmd.tick):
		_pending[cmd.tick] = []
	_pending[cmd.tick].append(cmd)


## Advances the world by exactly one tick.
func step() -> void:
	events.clear()
	for id: int in entity_ids:
		var e: SimEntity = entities[id]
		e.prev_x = e.x
		e.prev_y = e.y
		e.prev_facing = e.facing
	_apply_commands()
	# System order is part of the rules. Add new systems here, in order, and
	# document the order in docs/02-architecture.md.
	OrderSystem.step(self)
	GarrisonSystem.step(self)
	CaptureSystem.step(self)
	DroneSystem.step(self)
	AirSystem.step(self)
	JammingSystem.step(self)
	KillChainSystem.step(self)
	StrikeSystem.step(self)
	DecoySystem.step(self)
	CommanderPowers.expire(self)
	PowerSystem.step(self)
	FundSystem.step(self)
	IncomeSystem.step(self)
	ConstructionSystem.step(self)
	ProductionSystem.step(self)
	Upgrades.step(self)
	HealSystem.step(self)
	GatherSystem.step(self)
	PathingSystem.step(self)
	MovementSystem.step(self)
	SeparationSystem.step(self)
	if tick % SimVision.UPDATE_INTERVAL == 0:
		vision.update(self)
	_spatial.rebuild(self)
	StealthSystem.step(self)
	MineSystem.step(self)
	LaunchSystem.step(self)
	CrushSystem.step(self)
	InteropSystem.step(self)
	CombatSystem.step(self)
	ProtectionSystem.step(self)
	VeterancySystem.step(self)
	VictorySystem.step(self)
	_remove_dead()
	tick += 1


func next_projectile_id() -> int:
	_next_projectile_id += 1
	return _next_projectile_id - 1


## Deals damage after armor and grants XP (WorldDamage). Returns the damage
## dealt. An entity reaching 0 hp is marked dead and removed at the end of the tick.
func apply_damage(target: SimEntity, amount: int, damage_type: String, attacker_id: int, drone_hit: bool = false) -> int:
	return WorldDamage.apply(self, target, amount, damage_type, attacker_id, drone_hit)


## Extra damage percent for an attacker's veterancy rank.
func damage_bonus(e: SimEntity) -> int:
	return rules.veterancy_damage_bonus[e.vet_rank]


## Living and dead entities whose position lies within `radius` of (x, y)
## (fixed-point), from the index built this tick. Order is deterministic.
func query_radius(x: int, y: int, radius: int) -> Array[SimEntity]:
	if _spatial.is_empty():
		_spatial.rebuild(self)
	return _spatial.query_radius(x, y, radius)


## Like query_radius, but only entities that are enemies of `player_id`
## (another team, not neutral). Skips friendly units before any distance math,
## which matters inside big blobs of one player's units.
func query_enemies(player_id: int, x: int, y: int, radius: int) -> Array[SimEntity]:
	if player_id == 0:
		return []
	if _spatial.is_empty():
		_spatial.rebuild(self)
	return _spatial.query_other_teams(team_of(player_id), x, y, radius)


## Rebuilds the area-search index (the perf harness times it alone).
func rebuild_index() -> void:
	_spatial.rebuild(self)


func _remove_dead() -> void:
	var alive: Array[int] = []
	for id: int in entity_ids:
		var e: SimEntity = entities[id]
		if e.dead:
			map.clear_footprint(id)
			entities.erase(id)
		else:
			alive.append(id)
	if alive.size() != entity_ids.size():
		entity_ids = alive
		_spatial.clear()


## Hash of the whole state. Equal hashes on two machines mean they agree.
func state_hash() -> int:
	var h := SimHash.new()
	h.add_int(tick)
	h.add_int(rng.state)
	rules.write_hash(h)
	h.add_bool(game_over)
	h.add_int(winner_team)
	map.write_hash(h)
	vision.write_hash(h)
	var player_ids: Array[int] = []
	for pid: int in players:
		player_ids.append(pid)
	player_ids.sort()
	for pid: int in player_ids:
		players[pid].write_hash(h)
	h.add_int(entity_ids.size())
	for id: int in entity_ids:
		entities[id].write_hash(h)
	h.add_int(projectiles.size())
	for p: SimProjectile in projectiles:
		p.write_hash(h)
	return h.value


func _apply_commands() -> void:
	if not _pending.has(tick):
		return
	var cmds: Array = _pending[tick]
	_pending.erase(tick)
	WorldCommands.apply_all(self, cmds)
