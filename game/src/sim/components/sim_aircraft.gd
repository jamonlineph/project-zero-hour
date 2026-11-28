class_name SimAircraft
extends RefCounted
## Aircraft with limited ammo (P3-04a, AirSystem): the airbase they came from,
## and whether they are flying home or parked there rearming.

var home_id: int = 0          ## airbase (0 = none: it just hovers when empty)
var rearm_ticks: int = 1      ## from empty to full ammo while parked at home
var returning: bool = false   ## out of ammo, flying home; ignores other orders
var docked: bool = false      ## parked at home, rearming and repairing
var rearm_progress: int = 0


func write_hash(h: SimHash) -> void:
	h.add_int(home_id)
	h.add_int(rearm_ticks)
	h.add_bool(returning)
	h.add_bool(docked)
	h.add_int(rearm_progress)
