class_name SimPlayer
extends RefCounted
## One player's economy and progress. Ints and strings only.

var id: int = 0
var team: int = 0
var faction: String = ""
var credits: int = 0
var power_produced: int = 0     ## recomputed every tick from built buildings
var power_used: int = 0
var xp: int = 0                 ## commander XP (P1-18)
var rank: int = 1               ## commander rank 1..5 (P1-18)
var defeated: bool = false      ## P1-19


func low_power() -> bool:
	return power_used > power_produced


func write_hash(h: SimHash) -> void:
	h.add_int(id)
	h.add_int(team)
	h.add_string(faction)
	h.add_int(credits)
	h.add_int(power_produced)
	h.add_int(power_used)
	h.add_int(xp)
	h.add_int(rank)
	h.add_bool(defeated)
