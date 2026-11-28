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
## Crushing (P3-07): damage per second to a unit a moving crusher drives
## into, percent of the victim's max hp (who can be crushed: damage type
## "crush" in the damage matrix).
var crush_percent_per_s: int = 100
## Sovereign fund (P3-02b, FundSystem): the faction that earns interest, how
## often, how much of its unspent credits, the most per payment, and the
## power id that doubles that cap. An empty faction turns it off.
var fund_faction: String = "ae"
var fund_interval_ticks: int = 60 * 15
var fund_percent: int = 3
var fund_cap: int = 300
var fund_cap_doubler: String = "ae_unlock_fund"
## EU interoperability (P3-12c, InteropSystem): a unit of this faction with
## at least interop_min_types different unit types of its own side within
## interop_radius (itself included) reloads interop_reload_percent faster;
## twice that once the player chose interop_doubler. Empty faction: off.
var interop_faction: String = "eu"
var interop_radius: int = 25 * Fx.ONE
var interop_min_types: int = 3
var interop_reload_percent: int = 15
var interop_doubler: String = "eu_unlock_interop"


func write_hash(h: SimHash) -> void:
	for arr: PackedInt32Array in [veterancy_xp_multipliers, veterancy_damage_bonus, veterancy_armor_bonus, commander_rank_xp]:
		h.add_int(arr.size())
		for v: int in arr:
			h.add_int(v)
	h.add_int(self_repair_rank)
	h.add_int(self_repair_percent_per_2s)
	h.add_int(building_kill_xp_percent)
	h.add_int(crush_percent_per_s)
	h.add_string(fund_faction)
	h.add_int(fund_interval_ticks)
	h.add_int(fund_percent)
	h.add_int(fund_cap)
	h.add_string(fund_cap_doubler)
	if interop_faction != "":   # hashed only when on, so older rules hash as before
		h.add_string(interop_faction)
		h.add_int(interop_radius)
		h.add_int(interop_min_types)
		h.add_int(interop_reload_percent)
		h.add_string(interop_doubler)
