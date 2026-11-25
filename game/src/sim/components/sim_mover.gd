class_name SimMover
extends RefCounted
## Movement component: straight-line movement toward a target point.
##
## Turning, pathfinding and collision avoidance are later backlog tasks
## (tasks/BACKLOG.md: P1-02, P1-04 to P1-06).

var speed: int = 0          ## fixed-point meters per tick
var has_target: bool = false
var target_x: int = 0       ## fixed-point meters
var target_y: int = 0


func write_hash(h: SimHash) -> void:
	h.add_int(speed)
	h.add_bool(has_target)
	h.add_int(target_x)
	h.add_int(target_y)
