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
var research_id: String = ""   ## upgrade being researched here (P2-05)
var research_progress: int = 0
## Shut down by a "disable" ability until this tick (P3-02f): no production,
## research, power or fire.
var disabled_until: int = 0
## Capturable buildings (P3-08a, CaptureSystem): ticks a capture takes (0 =
## can't be captured), who is capturing it and how far they got.
var capture_ticks: int = 0
var walkable: bool = false       ## no footprint on the map; doesn't keep a player alive (P3-10a)
var bridge: bool = false         ## from the def (P3-11); not hashed
var collapsed: bool = false      ## a bridge at 0 hp: its deck is blocked until repaired (P3-11)
var capture_player: int = 0
var capture_progress: int = 0


## True while a "disable" ability holds this building down (P3-02f).
func is_disabled(tick: int) -> bool:
	return tick < disabled_until


func write_hash(h_: SimHash) -> void:
	h_.add_int(cell_x)
	h_.add_int(cell_y)
	h_.add_int(w)
	h_.add_int(h)
	h_.add_bool(built)
	if collapsed:   # only while a bridge is down (P3-11)
		h_.add_bool(collapsed)
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
	if research_id != "":   # only then, so older replays hash as before
		h_.add_string(research_id)
		h_.add_int(research_progress)
	if disabled_until != 0:   # only after a disable ability (P3-02f)
		h_.add_int(disabled_until)
	if capture_ticks != 0:   # only capturable buildings (P3-08a)
		h_.add_int(capture_ticks)
		h_.add_int(capture_player)
		h_.add_int(capture_progress)
