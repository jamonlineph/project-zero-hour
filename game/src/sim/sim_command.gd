class_name SimCommand
extends RefCounted
## A player order. Commands are the ONLY way input reaches the simulation,
## which is what makes replays and lockstep multiplayer possible.

enum Type { MOVE = 1, STOP = 2, ATTACK = 3, ATTACK_MOVE = 4, HOLD = 5 }

var tick: int = 0               ## tick on which the command is applied
var player_id: int = 0
var seq: int = 0                ## per-player sequence number; orders commands within a tick
var type: Type = Type.MOVE
var entity_ids: Array[int] = []
var target_x: int = 0           ## fixed-point meters
var target_y: int = 0
var target_entity: int = 0      ## ATTACK: entity to destroy


static func make_move(ids: Array[int], tx: int, ty: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.MOVE
	c.entity_ids = ids.duplicate()
	c.target_x = tx
	c.target_y = ty
	return c


static func make_stop(ids: Array[int]) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.STOP
	c.entity_ids = ids.duplicate()
	return c


static func make_attack(ids: Array[int], target_id: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.ATTACK
	c.entity_ids = ids.duplicate()
	c.target_entity = target_id
	return c


static func make_attack_move(ids: Array[int], tx: int, ty: int) -> SimCommand:
	var c := make_move(ids, tx, ty)
	c.type = Type.ATTACK_MOVE
	return c


static func make_hold(ids: Array[int]) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.HOLD
	c.entity_ids = ids.duplicate()
	return c


func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"player_id": player_id,
		"seq": seq,
		"type": int(type),
		"entity_ids": entity_ids.duplicate(),
		"target_x": target_x,
		"target_y": target_y,
		"target_entity": target_entity,
	}


## Rebuilds a command from to_dict() output. JSON turns ints into floats, so
## every number is converted back with int().
static func from_dict(d: Dictionary) -> SimCommand:
	var c := SimCommand.new()
	c.tick = int(d.get("tick", 0))
	c.player_id = int(d.get("player_id", 0))
	c.seq = int(d.get("seq", 0))
	c.type = int(d.get("type", Type.MOVE)) as Type
	for v: Variant in d.get("entity_ids", []):
		c.entity_ids.append(int(v))
	c.target_x = int(d.get("target_x", 0))
	c.target_y = int(d.get("target_y", 0))
	c.target_entity = int(d.get("target_entity", 0))
	return c
