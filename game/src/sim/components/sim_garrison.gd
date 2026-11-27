class_name SimGarrison
extends RefCounted
## A structure infantry can enter and fire from (P3-05). Ints only.

var capacity: int = 0            ## infantry units (squads) it holds
var occupants: Array[int] = []   ## entity ids, in the order they entered
var neutral: bool = false        ## civilian building: neutral again when empty


func has_room() -> bool:
	return occupants.size() < capacity


func write_hash(h: SimHash) -> void:
	h.add_int(capacity)
	h.add_bool(neutral)
	h.add_int(occupants.size())
	for id: int in occupants:
		h.add_int(id)
