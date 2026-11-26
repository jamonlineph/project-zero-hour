class_name SimSupply
extends RefCounted
## Supply site component: a finite stock of credits that gatherers load (P1-15).

var remaining: int = 0


func write_hash(h: SimHash) -> void:
	h.add_int(remaining)
