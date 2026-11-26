class_name SimGatherer
extends RefCounted
## Gatherer component (logistics trucks): load at a supply site, unload at a
## drop-off building, repeat (P1-15).

enum State { IDLE = 0, TO_SITE = 1, LOADING = 2, TO_DROPOFF = 3, UNLOADING = 4 }

var capacity: int = 300
var load_ticks: int = 45
var unload_ticks: int = 30
var state: State = State.IDLE
var auto: bool = true           ## idle gatherers look for the nearest site
var site_id: int = 0
var dropoff_id: int = 0
var carried: int = 0
var timer: int = 0


func write_hash(h: SimHash) -> void:
	h.add_int(capacity)
	h.add_int(state)
	h.add_bool(auto)
	h.add_int(site_id)
	h.add_int(dropoff_id)
	h.add_int(carried)
	h.add_int(timer)
