class_name SimRules
extends RefCounted
## Game-wide tuning numbers (game/data/rules.json). Defaults match the file,
## so tests can use SimRules.new() directly.

## Unit XP needed for veterancy ranks 1, 2, 3, as multiples of the unit's cost.
var veterancy_xp_multipliers: PackedInt32Array = [1, 2, 4]
## Extra damage dealt at veterancy ranks 0..3, percent.
var veterancy_damage_bonus: PackedInt32Array = [0, 10, 10, 20]
## Damage taken reduction at veterancy ranks 0..3, percent.
var veterancy_armor_bonus: PackedInt32Array = [0, 0, 10, 20]
var self_repair_rank: int = 3
var self_repair_percent_per_2s: int = 1
## Commander XP needed for ranks 1..5 (the first is always 0).
var commander_rank_xp: PackedInt32Array = [0, 2000, 5000, 10000, 18000]
## Extra commander XP for destroying a building, percent of its cost.
var building_kill_xp_percent: int = 50


func write_hash(h: SimHash) -> void:
	for arr: PackedInt32Array in [veterancy_xp_multipliers, veterancy_damage_bonus, veterancy_armor_bonus, commander_rank_xp]:
		h.add_int(arr.size())
		for v: int in arr:
			h.add_int(v)
	h.add_int(self_repair_rank)
	h.add_int(self_repair_percent_per_2s)
	h.add_int(building_kill_xp_percent)
