class_name SimBuilding
extends RefCounted
## Building component: footprint, construction progress, power, production
## queue and rally point (P1-12, P1-13, P1-16).

const MAX_QUEUE: int = 9

var cell_x: int = 0             ## footprint origin (map cells)
var cell_y: int = 0
var w: int = 1                  ## footprint size in cells
var h: int = 1
var built: bool = true
var progress: int = 0           ## construction progress in half-steps
var total: int = 1              ## half-steps needed (2 per tick of build time)
var power: int = 0              ## + produces, - uses (only counts once built)
var produces: PackedStringArray = []
var dropoff: bool = false       ## gatherers unload here
var free_unit: String = ""      ## unit given once when construction finishes
var queue: PackedStringArray = []
var queue_progress: int = 0     ## ticks spent on queue[0]
var has_rally: bool = false
var rally_x: int = 0            ## fixed-point meters
var rally_y: int = 0


func write_hash(h_: SimHash) -> void:
	h_.add_int(cell_x)
	h_.add_int(cell_y)
	h_.add_int(w)
	h_.add_int(h)
	h_.add_bool(built)
	h_.add_int(progress)
	h_.add_int(total)
	h_.add_int(power)
	h_.add_bool(dropoff)
	h_.add_int(queue.size())
	for item: String in queue:
		h_.add_string(item)
	h_.add_int(queue_progress)
	h_.add_bool(has_rally)
	h_.add_int(rally_x)
	h_.add_int(rally_y)
