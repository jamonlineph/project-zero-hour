class_name SimEntity
extends RefCounted
## One simulated object: units now, buildings later.
##
## Holds only deterministic data (ints, fixed-point where noted, bools and
## Strings) plus optional component objects. Systems in res://src/sim/systems/
## read and change entities; nothing outside the sim writes to them.

## What the unit was told to do (P1-10; GUARD and PATROL from P1-24b).
enum Order { IDLE = 0, MOVE = 1, ATTACK = 2, ATTACK_MOVE = 3, HOLD = 4, GUARD = 5, PATROL = 6 }

var id: int = 0
var player_id: int = 0          ## 0 = neutral
var def_id: String = ""         ## content id, for example "us_mbt" (res://data/)
var armor_class: String = ""    ## see docs/design/combat.md
var x: int = 0                  ## fixed-point meters (sim X maps to Godot X)
var y: int = 0                  ## fixed-point meters (sim Y maps to Godot Z)
var prev_x: int = 0             ## position at the start of the tick, for view interpolation
var prev_y: int = 0
var facing: int = 0             ## binary angle (Fx.ANGLE_FULL per turn); 0 = +X, 1024 = +Y
var prev_facing: int = 0        ## facing at the start of the tick, for view interpolation
var radius: int = 0             ## fixed-point meters
var vision: int = 0             ## sight radius, fixed-point meters
var hp: int = 0
var max_hp: int = 0
var dead: bool = false          ## set when hp reaches 0; removed at the end of the tick
var cost: int = 0               ## credits; weights veterancy XP (P1-17)
var xp: int = 0                 ## veterancy XP (cost-weighted damage dealt)
var vet_rank: int = 0           ## 0..3
var mover: SimMover = null      ## only on entities that can move
var weapons: Array[SimWeapon] = []
var building: SimBuilding = null
var builder: SimBuilder = null
var gatherer: SimGatherer = null
var supply: SimSupply = null    ## supply sites only

var order: Order = Order.IDLE
var order_target_id: int = 0    ## ATTACK: the entity to destroy; GUARD: the entity to protect
var order_x: int = 0            ## ATTACK_MOVE / PATROL: where to go (fixed-point meters)
var order_y: int = 0
var order_repath_tick: int = 0  ## ATTACK / GUARD: when the chase path was last planned
var order_from_x: int = 0       ## PATROL: the other end of the route
var order_from_y: int = 0


func is_armed() -> bool:
	return not weapons.is_empty()


func write_hash(h: SimHash) -> void:
	h.add_int(id)
	h.add_int(player_id)
	h.add_string(def_id)
	h.add_string(armor_class)
	h.add_int(x)
	h.add_int(y)
	h.add_int(facing)
	h.add_int(radius)
	h.add_int(vision)
	h.add_int(hp)
	h.add_int(max_hp)
	h.add_bool(dead)
	h.add_int(order)
	h.add_int(order_target_id)
	h.add_int(order_x)
	h.add_int(order_y)
	h.add_int(order_repath_tick)
	# Only while patrolling, so states without patrols hash as they always did
	# (golden replays recorded before P1-24b stay valid).
	if order == Order.PATROL:
		h.add_int(order_from_x)
		h.add_int(order_from_y)
	if mover != null:
		mover.write_hash(h)
	else:
		h.add_int(-1)
	h.add_int(weapons.size())
	for w: SimWeapon in weapons:
		w.write_hash(h)
	h.add_int(cost)
	h.add_int(xp)
	h.add_int(vet_rank)
	for c: Variant in [building, builder, gatherer, supply]:
		if c == null:
			h.add_int(-1)
		else:
			c.write_hash(h)
