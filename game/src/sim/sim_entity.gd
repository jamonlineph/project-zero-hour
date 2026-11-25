class_name SimEntity
extends RefCounted
## One simulated object: units now, buildings and projectiles later.
##
## Holds only deterministic data (ints, fixed-point where noted, bools and
## Strings) plus optional component objects. Systems in res://src/sim/systems/
## read and change entities; nothing outside the sim writes to them.

var id: int = 0
var player_id: int = 0          ## 0 = neutral
var def_id: String = ""         ## content id, for example "us_mbt" (res://data/)
var x: int = 0                  ## fixed-point meters (sim X maps to Godot X)
var y: int = 0                  ## fixed-point meters (sim Y maps to Godot Z)
var prev_x: int = 0             ## position at the start of the tick, for view interpolation
var prev_y: int = 0
var facing: int = 0             ## binary angle (Fx.ANGLE_FULL per turn); 0 = +X, 1024 = +Y
var prev_facing: int = 0        ## facing at the start of the tick, for view interpolation
var radius: int = 0             ## fixed-point meters
var hp: int = 0
var max_hp: int = 0
var mover: SimMover = null      ## only on entities that can move


func write_hash(h: SimHash) -> void:
	h.add_int(id)
	h.add_int(player_id)
	h.add_string(def_id)
	h.add_int(x)
	h.add_int(y)
	h.add_int(facing)
	h.add_int(radius)
	h.add_int(hp)
	h.add_int(max_hp)
	if mover != null:
		mover.write_hash(h)
	else:
		h.add_int(-1)
