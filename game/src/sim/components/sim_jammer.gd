class_name SimJammer
extends RefCounted
## Jammer component (P2-03): a jamming field around the entity, and the
## spoofing ability. Ints only.

var radius: int = 0              ## field radius, fixed-point meters
var strength: int = 1            ## overlapping fields don't stack: the strongest wins
var spoof_radius: int = 0        ## 0 = can't spoof
var spoof_range: int = 0         ## how far from the jammer it can spoof
var spoof_cooldown: int = 0      ## ticks
var spoof_ready_tick: int = 0    ## first tick it can spoof again


func write_hash(h: SimHash) -> void:
	h.add_int(radius)
	h.add_int(strength)
	h.add_int(spoof_radius)
	h.add_int(spoof_range)
	h.add_int(spoof_cooldown)
	h.add_int(spoof_ready_tick)
