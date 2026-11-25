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

var tick: int = 0
var rng: SimRng
var map_width: int = 0      ## fixed-point meters
var map_height: int = 0
var entities: Dictionary[int, SimEntity] = {}
var entity_ids: Array[int] = []   ## ascending ids: always iterate this
var _next_id: int = 1
var _pending: Dictionary[int, Array] = {}   ## tick -> Array of SimCommand


func _init(seed_value: int = 1, width_m: int = 256, height_m: int = 256) -> void:
	rng = SimRng.new(seed_value)
	map_width = Fx.from_int(width_m)
	map_height = Fx.from_int(height_m)


## Adds a unit and returns its id. x and y are fixed-point meters.
func spawn_unit(def: UnitDef, player_id: int, x: int, y: int) -> int:
	var e := SimEntity.new()
	e.id = _next_id
	_next_id += 1
	e.player_id = player_id
	e.def_id = def.id
	e.x = clampi(x, 0, map_width)
	e.y = clampi(y, 0, map_height)
	e.prev_x = e.x
	e.prev_y = e.y
	e.radius = def.radius
	e.max_hp = def.max_hp
	e.hp = def.max_hp
	if def.speed > 0:
		e.mover = SimMover.new()
		e.mover.speed = def.speed
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
	for id: int in entity_ids:
		var e: SimEntity = entities[id]
		e.prev_x = e.x
		e.prev_y = e.y
	_apply_commands()
	# System order is part of the rules. Add new systems here, in order, and
	# document the order in docs/02-architecture.md.
	MovementSystem.step(self)
	tick += 1


## Hash of the whole state. Equal hashes on two machines mean they agree.
func state_hash() -> int:
	var h := SimHash.new()
	h.add_int(tick)
	h.add_int(rng.state)
	h.add_int(entity_ids.size())
	for id: int in entity_ids:
		entities[id].write_hash(h)
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
			_:
				push_error("SimWorld: unknown command type %d" % c.type)


## Canonical command order within a tick: by player, then by sequence number.
func _command_before(a: SimCommand, b: SimCommand) -> bool:
	if a.player_id != b.player_id:
		return a.player_id < b.player_id
	return a.seq < b.seq


func _apply_move(c: SimCommand) -> void:
	var movers: Array[SimEntity] = _owned_movers(c)
	if movers.is_empty():
		return
	var spacing: int = 0
	for e: SimEntity in movers:
		spacing = maxi(spacing, e.radius * 2 + Fx.from_ratio(1, 2))
	var offsets: Array[Vector2i] = Formation.grid_offsets(movers.size(), spacing)
	for i: int in movers.size():
		var e: SimEntity = movers[i]
		e.mover.target_x = clampi(c.target_x + offsets[i].x, 0, map_width)
		e.mover.target_y = clampi(c.target_y + offsets[i].y, 0, map_height)
		e.mover.has_target = true


func _apply_stop(c: SimCommand) -> void:
	for e: SimEntity in _owned_movers(c):
		e.mover.has_target = false


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
