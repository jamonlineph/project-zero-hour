class_name SimCommand
extends RefCounted
## A player order. Commands are the ONLY way input reaches the simulation,
## which is what makes replays and lockstep multiplayer possible.

enum Type {
	MOVE = 1, STOP = 2, ATTACK = 3, ATTACK_MOVE = 4, HOLD = 5,
	BUILD = 6, PRODUCE = 7, CANCEL = 8, RALLY = 9, GATHER = 10, SELL = 11, REPAIR = 12,
	GUARD = 13, PATROL = 14, SPOOF = 15, RESEARCH = 16, UPGRADE_UNIT = 17,
	CHOOSE_POWER = 18, USE_POWER = 19, GARRISON = 20, UNLOAD = 21,
}

var tick: int = 0               ## tick on which the command is applied
var player_id: int = 0
var seq: int = 0                ## per-player sequence number; orders commands within a tick
var type: Type = Type.MOVE
var entity_ids: Array[int] = []
var target_x: int = 0           ## fixed-point meters
var target_y: int = 0
var target_entity: int = 0      ## ATTACK target, PRODUCE/CANCEL/RALLY/SELL/REPAIR building, GATHER site, GUARD ward
var def_id: String = ""         ## BUILD: building id; PRODUCE: unit id
var index: int = 0              ## CANCEL: queue slot


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


## Armed units in `ids` stay near `ward_id` (an own or allied unit or
## building) and fight enemies that come close to it.
static func make_guard(ids: Array[int], ward_id: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.GUARD
	c.entity_ids = ids.duplicate()
	c.target_entity = ward_id
	return c


## Units in `ids` attack-move back and forth between where they are and (tx, ty).
static func make_patrol(ids: Array[int], tx: int, ty: int) -> SimCommand:
	var c := make_move(ids, tx, ty)
	c.type = Type.PATROL
	return c


## Jammers in `ids` spoof enemy drones around (tx, ty) (P2-03).
static func make_spoof(ids: Array[int], tx: int, ty: int) -> SimCommand:
	var c := make_move(ids, tx, ty)
	c.type = Type.SPOOF
	return c


## Start researching a global upgrade at one of the player's buildings (P2-05).
static func make_research(building_id: int, upgrade_id: String) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.RESEARCH
	c.target_entity = building_id
	c.def_id = upgrade_id
	return c


## Buy a per-unit upgrade for every unit in `ids` it applies to (P2-05).
static func make_upgrade_unit(ids: Array[int], upgrade_id: String) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.UPGRADE_UNIT
	c.entity_ids = ids.duplicate()
	c.def_id = upgrade_id
	return c


## Spend a commander point on a power or unlock (P2-09).
static func make_choose_power(power_id: String) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.CHOOSE_POWER
	c.def_id = power_id
	return c


## Use a chosen power, aimed at (tx, ty) when it needs a point (P2-09).
## Infantry go into a structure (P3-05).
static func make_garrison(ids: Array[int], structure_id: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.GARRISON
	c.entity_ids = ids.duplicate()
	c.target_entity = structure_id
	return c


## Everyone inside one of the player's structures comes out (P3-05).
static func make_unload(structure_id: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.UNLOAD
	c.target_entity = structure_id
	return c


static func make_use_power(power_id: String, tx: int, ty: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.USE_POWER
	c.def_id = power_id
	c.target_x = tx
	c.target_y = ty
	return c


## Builders in `ids` place and construct `building_id` centered on (cx, cy).
static func make_build(ids: Array[int], building_id: String, cx: int, cy: int) -> SimCommand:
	var c := make_move(ids, cx, cy)
	c.type = Type.BUILD
	c.def_id = building_id
	return c


static func make_produce(building_entity: int, unit_id: String) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.PRODUCE
	c.target_entity = building_entity
	c.def_id = unit_id
	return c


static func make_cancel(building_entity: int, slot: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.CANCEL
	c.target_entity = building_entity
	c.index = slot
	return c


static func make_rally(building_entity: int, x: int, y: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.RALLY
	c.target_entity = building_entity
	c.target_x = x
	c.target_y = y
	return c


static func make_gather(ids: Array[int], site_entity: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.GATHER
	c.entity_ids = ids.duplicate()
	c.target_entity = site_entity
	return c


static func make_sell(building_entity: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.SELL
	c.target_entity = building_entity
	return c


static func make_repair(ids: Array[int], building_entity: int) -> SimCommand:
	var c := SimCommand.new()
	c.type = Type.REPAIR
	c.entity_ids = ids.duplicate()
	c.target_entity = building_entity
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
		"def_id": def_id,
		"index": index,
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
	c.def_id = str(d.get("def_id", ""))
	c.index = int(d.get("index", 0))
	return c
