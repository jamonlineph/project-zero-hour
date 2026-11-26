class_name SimDrone
extends RefCounted
## Drone component (P2-01): flight endurance and the launcher it returns to.
## Ints and bools only.

var endurance_max: int = 0     ## ticks of flight on a full charge
var endurance: int = 0         ## ticks of flight left
var home_id: int = 0           ## launcher building (0 = none: it crashes when empty)
var returning: bool = false    ## flying home to recharge; ignores other orders
var docked: bool = false       ## parked at its launcher, recharging
var fiber_optic: bool = false  ## immune to jamming and spoofing (P2-03)
var jammed: bool = false       ## inside a hostile jamming field: no control
var spoofed_ticks: int = 0     ## ticks left flying to a spoofed point
var drift_x: int = 0           ## where a jammed or spoofed drone is heading
var drift_y: int = 0


func write_hash(h: SimHash) -> void:
	h.add_int(endurance_max)
	h.add_int(endurance)
	h.add_int(home_id)
	h.add_bool(returning)
	h.add_bool(docked)
	h.add_bool(fiber_optic)
	h.add_bool(jammed)
	h.add_int(spoofed_ticks)
	h.add_int(drift_x)
	h.add_int(drift_y)
