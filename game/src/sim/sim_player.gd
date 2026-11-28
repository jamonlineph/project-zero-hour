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
var upgrades: PackedStringArray = []   ## researched global upgrades, in order (P2-05)
var powers: PackedStringArray = []     ## chosen commander powers and unlocks (P2-09)
var power_ready: Dictionary[String, int] = {}   ## power id -> first tick it can be used again
var blinded_until: int = 0      ## enemy cyberattack: minimap and radar off until this tick
var jam_immune_until: int = 0   ## cyber defense (P3-12a): jamming and spoofing don't affect us until this tick


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
	if not powers.is_empty() or blinded_until != 0:   # only then, so older replays hash as before
		for p: String in powers:
			h.add_string(p)
		var keys: Array = power_ready.keys()
		keys.sort()
		for k: String in keys:
			h.add_string(k)
			h.add_int(power_ready[k])
		h.add_int(blinded_until)
	if jam_immune_until != 0:   # only after a cyber defense (P3-12a)
		h.add_int(jam_immune_until)
	if not upgrades.is_empty():   # only then, so older replays hash as before
		for u: String in upgrades:
			h.add_string(u)
