class_name SimStrike
extends RefCounted
## A strike in flight (P2-07). Ints and strings only.

var def_id: String = ""
var aircraft: bool = false
var dest_x: int = 0
var dest_y: int = 0
var exit_x: int = 0
var exit_y: int = 0
var delivered: bool = false


func write_hash(h: SimHash) -> void:
	h.add_string(def_id)
	h.add_bool(aircraft)
	h.add_int(dest_x)
	h.add_int(dest_y)
	h.add_int(exit_x)
	h.add_int(exit_y)
	h.add_bool(delivered)
