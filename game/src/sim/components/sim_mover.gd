class_name SimMover
extends RefCounted
## Movement component: turns toward the target, then moves to it.
##
## Pathfinding and collision avoidance are later backlog tasks
## (tasks/BACKLOG.md: P1-04 to P1-06).

## Turn rate that means "turns instantly" (infantry, drones).
const INSTANT_TURN: int = Fx.ANGLE_FULL
## Units move at full speed only when facing within this angle of their heading.
const FULL_SPEED_ANGLE: int = Fx.ANGLE_QUARTER / 4   # 22.5 degrees
## Speed while still turning: SLOW_NUM / SLOW_DEN of full speed.
const SLOW_NUM: int = 1
const SLOW_DEN: int = 4

var speed: int = 0                  ## fixed-point meters per tick
var turn_rate: int = INSTANT_TURN   ## binary angle units per tick
var has_target: bool = false
var target_x: int = 0               ## fixed-point meters
var target_y: int = 0


func write_hash(h: SimHash) -> void:
	h.add_int(speed)
	h.add_int(turn_rate)
	h.add_bool(has_target)
	h.add_int(target_x)
	h.add_int(target_y)
