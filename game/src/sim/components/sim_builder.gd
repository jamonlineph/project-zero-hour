class_name SimBuilder
extends RefCounted
## Builder component (engineer vehicles, field crews): constructs and repairs
## its player's buildings (P1-12).

var target_id: int = 0          ## building being built or repaired, 0 = none
var repair: bool = false        ## true when the job is a repair


func write_hash(h: SimHash) -> void:
	h.add_int(target_id)
	h.add_bool(repair)
