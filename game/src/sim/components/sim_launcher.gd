class_name SimLauncher
extends RefCounted
## A vehicle that launches a group of drones at enemies in range (P3-02c, the
## UAE swarm-drone truck). See LaunchSystem.

var unit_id: String = ""     ## the drone unit it launches
var count: int = 1           ## drones per launch
var range: int = 0           ## fixed-point meters: launches at enemies this close
var cooldown_ticks: int = 1  ## between launches
var ready_tick: int = 0      ## first tick it can launch again


func write_hash(h: SimHash) -> void:
	h.add_string(unit_id)
	h.add_int(count)
	h.add_int(range)
	h.add_int(cooldown_ticks)
	h.add_int(ready_tick)
