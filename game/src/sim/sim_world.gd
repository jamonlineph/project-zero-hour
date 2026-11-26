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
const INDEX_BUCKET: int = 16 * Fx.ONE

var tick: int = 0
var rng: SimRng
var map_width: int = 0      ## fixed-point meters
var map_height: int = 0
var map: SimMap             ## passability grid (see SimMap)
var pathfinder: Pathfinder  ## A* over `map`, shared by all movers
var entities: Dictionary[int, SimEntity] = {}
var entity_ids: Array[int] = []   ## ascending ids: always iterate this
var damage_matrix: DamageMatrix = DamageMatrix.new()
var vision: SimVision
## Player -> team. Players not listed are on a team of their own (team = id).
var player_team: Dictionary[int, int] = {}
var projectiles: Array[SimProjectile] = []   ## in creation order
## What happened this tick, for the view and audio (not part of the state hash).
## Dictionaries with a "type": "fired", "hit" or "died".
var events: Array[Dictionary] = []
var _next_id: int = 1
var _next_projectile_id: int = 1
var _index_cols: int = 1
var _index_rows: int = 1
var _index: Array[Array] = []
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


## Adds a unit and returns its id. x and y are fixed-point meters; facing is a
## binary angle (0 = +X).
func spawn_unit(def: UnitDef, player_id: int, x: int, y: int, facing: int = 0) -> int:
	var e := SimEntity.new()
	e.id = _next_id
	_next_id += 1
	e.player_id = player_id
	e.def_id = def.id
	e.armor_class = def.armor_class
	e.x = clampi(x, 0, map_width)
	e.y = clampi(y, 0, map_height)
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
	for w: WeaponDef in def.weapons:
		e.weapons.append(SimWeapon.from_def(w))
	entities[e.id] = e
	entity_ids.append(e.id)
	return e.id


func get_entity(id: int) -> SimEntity:
	return entities.get(id, null)


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
	PathingSystem.step(self)
	MovementSystem.step(self)
	SeparationSystem.step(self)
	if tick % SimVision.UPDATE_INTERVAL == 0:
		vision.update(self)
	_rebuild_index()
	CombatSystem.step(self)
	_remove_dead()
	tick += 1


func next_projectile_id() -> int:
	_next_projectile_id += 1
	return _next_projectile_id - 1


## Deals damage after armor (damage matrix). Returns the damage dealt. An
## entity reaching 0 hp is marked dead and removed at the end of the tick.
func apply_damage(target: SimEntity, amount: int, damage_type: String, attacker_id: int) -> int:
	if target.dead:
		return 0
	var dealt: int = mini(damage_matrix.apply(amount, damage_type, target.armor_class), target.hp)
	target.hp -= dealt
	if target.hp <= 0:
		target.dead = true
		events.append({"type": "died", "id": target.id, "def_id": target.def_id,
				"player": target.player_id, "x": target.x, "y": target.y, "killer": attacker_id})
	return dealt


## Living and dead entities whose position lies within `radius` of (x, y)
## (fixed-point), from the index built this tick. Order is deterministic.
func query_radius(x: int, y: int, radius: int) -> Array[SimEntity]:
	var result: Array[SimEntity] = []
	if _index.is_empty():
		_rebuild_index()
	var x0: int = clampi((x - radius) / INDEX_BUCKET, 0, _index_cols - 1)
	var x1: int = clampi((x + radius) / INDEX_BUCKET, 0, _index_cols - 1)
	var y0: int = clampi((y - radius) / INDEX_BUCKET, 0, _index_rows - 1)
	var y1: int = clampi((y + radius) / INDEX_BUCKET, 0, _index_rows - 1)
	for by: int in range(y0, y1 + 1):
		for bx: int in range(x0, x1 + 1):
			for e: SimEntity in _index[by * _index_cols + bx]:
				var dx: int = e.x - x
				var dy: int = e.y - y
				if absi(dx) <= radius and absi(dy) <= radius and Fx.length(dx, dy) <= radius:
					result.append(e)
	return result


func _rebuild_index() -> void:
	_index_cols = maxi(1, (map_width + INDEX_BUCKET - 1) / INDEX_BUCKET)
	_index_rows = maxi(1, (map_height + INDEX_BUCKET - 1) / INDEX_BUCKET)
	if _index.size() != _index_cols * _index_rows:
		_index.resize(_index_cols * _index_rows)
	for i: int in _index.size():
		_index[i] = []
	for id: int in entity_ids:
		var e: SimEntity = entities[id]
		var bx: int = clampi(e.x / INDEX_BUCKET, 0, _index_cols - 1)
		var by: int = clampi(e.y / INDEX_BUCKET, 0, _index_rows - 1)
		_index[by * _index_cols + bx].append(e)


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
		_index.clear()


## Hash of the whole state. Equal hashes on two machines mean they agree.
func state_hash() -> int:
	var h := SimHash.new()
	h.add_int(tick)
	h.add_int(rng.state)
	map.write_hash(h)
	vision.write_hash(h)
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
	cmds.sort_custom(_command_before)
	for c: SimCommand in cmds:
		match c.type:
			SimCommand.Type.MOVE:
				_apply_move(c)
			SimCommand.Type.STOP:
				_apply_stop(c)
			SimCommand.Type.ATTACK:
				_apply_attack(c)
			SimCommand.Type.ATTACK_MOVE:
				_apply_move(c)
				for e: SimEntity in _owned_movers(c):
					e.order = SimEntity.Order.ATTACK_MOVE
					e.order_x = c.target_x
					e.order_y = c.target_y
			SimCommand.Type.HOLD:
				_apply_hold(c)
			_:
				push_error("SimWorld: unknown command type %d" % c.type)


## Canonical command order within a tick: by player, then by sequence number.
func _command_before(a: SimCommand, b: SimCommand) -> bool:
	if a.player_id != b.player_id:
		return a.player_id < b.player_id
	return a.seq < b.seq


## Groups closer together than this keep their layout at the destination;
## more spread-out groups form a grid there instead.
const KEEP_LAYOUT_RADIUS: int = 12 * Fx.ONE


## A move order. One unit near the group's center (the leader) plans a path;
## the others reuse it (see PathingSystem) and end in their own slot.
func _apply_move(c: SimCommand) -> void:
	var movers: Array[SimEntity] = _owned_movers(c)
	if movers.is_empty():
		return
	var n: int = movers.size()
	var cx: int = 0
	var cy: int = 0
	for e: SimEntity in movers:
		cx += e.x
		cy += e.y
	cx /= n
	cy /= n
	var spread: int = 0
	var leader: SimEntity = movers[0]
	var leader_dist: int = -1
	for e: SimEntity in movers:
		var d: int = Fx.length(e.x - cx, e.y - cy)
		spread = maxi(spread, d)
		if leader_dist < 0 or d < leader_dist:
			leader = e
			leader_dist = d
	var offsets: Array[Vector2i] = []
	if spread <= KEEP_LAYOUT_RADIUS:
		for e: SimEntity in movers:
			offsets.append(Vector2i(e.x - cx, e.y - cy))
	else:
		var spacing: int = 0
		for e: SimEntity in movers:
			spacing = maxi(spacing, e.radius * 2 + Fx.from_ratio(1, 2))
		offsets = Formation.grid_offsets(n, spacing)
	for i: int in n:
		var e: SimEntity = movers[i]
		e.mover.order_move(
			clampi(c.target_x + offsets[i].x, 0, map_width),
			clampi(c.target_y + offsets[i].y, 0, map_height))
		e.mover.follow_leader = 0 if e == leader or n == 1 else leader.id
		e.order = SimEntity.Order.MOVE
		e.order_target_id = 0


func _apply_stop(c: SimCommand) -> void:
	for e: SimEntity in _owned_entities(c):
		if e.mover != null:
			e.mover.stop()
		e.order = SimEntity.Order.IDLE
		e.order_target_id = 0
		for w: SimWeapon in e.weapons:
			w.target_id = 0


## Orders armed units to destroy an enemy entity. Units with no weapon able
## to hit it ignore the order.
func _apply_attack(c: SimCommand) -> void:
	var t: SimEntity = get_entity(c.target_entity)
	if t == null or t.dead or not are_enemies(c.player_id, t.player_id) or not can_see(c.player_id, t.x, t.y):
		return
	for e: SimEntity in _owned_entities(c):
		var able: bool = false
		for w: SimWeapon in e.weapons:
			if DamageMatrix.can_target(w.targets, t.armor_class):
				able = true
		if not able:
			continue
		e.order = SimEntity.Order.ATTACK
		e.order_target_id = t.id
		e.order_repath_tick = tick
		if e.mover != null:
			e.mover.order_move(t.x, t.y)


func _apply_hold(c: SimCommand) -> void:
	for e: SimEntity in _owned_entities(c):
		if e.mover != null:
			e.mover.stop()
		e.order = SimEntity.Order.HOLD
		e.order_target_id = 0


## Entities named in the command that exist, are alive and belong to the
## issuing player. Sorted by id, duplicates removed.
func _owned_entities(c: SimCommand) -> Array[SimEntity]:
	var ids: Array[int] = c.entity_ids.duplicate()
	ids.sort()
	var result: Array[SimEntity] = []
	var last: int = -1
	for id: int in ids:
		if id == last:
			continue
		last = id
		var e: SimEntity = get_entity(id)
		if e != null and not e.dead and e.player_id == c.player_id:
			result.append(e)
	return result


## Entities named in the command that exist, belong to the issuing player and
## can move. Sorted by id, duplicates removed.
func _owned_movers(c: SimCommand) -> Array[SimEntity]:
	var ids: Array[int] = c.entity_ids.duplicate()
	ids.sort()
	var result: Array[SimEntity] = []
	var last: int = -1
	for id: int in ids:
		if id == last:
			continue
		last = id
		var e: SimEntity = get_entity(id)
		if e != null and e.player_id == c.player_id and e.mover != null:
			result.append(e)
	return result
