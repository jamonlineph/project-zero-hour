class_name UpgradeDef
extends RefCounted
## An upgrade (P2-05), built by ContentDb from res://data/upgrades/<id>.json.
## "global" upgrades are researched once at a building and apply to every
## matching unit the player owns, now and later. "unit" upgrades are bought
## for individual selected units.

const EFFECT_KEYS: PackedStringArray = ["speed_percent", "max_hp_percent", "damage_percent",
		"range_percent", "vision_percent", "aps_charges", "cage_hits"]

var id: String = ""
var faction: String = ""
var name: String = ""
var scope: String = "global"         ## "global" or "unit"
var cost: int = 0                    ## per unit for "unit" upgrades
var research_ticks: int = 1          ## global only (data: research_time_ms)
var researched_at: String = ""       ## global only: building id that researches it
var granted: bool = false            ## never researched: a power grants it (P3-12b doctrines)
var requires: PackedStringArray = [] ## buildings the player must own (built)
var requires_rank: int = 1           ## commander rank needed
var applies_to: PackedStringArray = []  ## unit ids
var effects: Dictionary[String, int] = {}
var attachment: String = ""          ## model node shown once owned (named upg_*)


func applies(unit_id: String) -> bool:
	return applies_to.has(unit_id)
