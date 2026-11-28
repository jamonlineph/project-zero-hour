class_name BuildingDef
extends RefCounted
## A building's content definition in sim units, built by ContentDb from
## res://data/buildings/<id>.json.

var id: String = ""
var faction: String = ""
var name: String = ""
var armor_class: String = "structure"
var max_hp: int = 1
var cost: int = 0
var footprint_w: int = 1        ## cells (2 m each)
var footprint_h: int = 1
var build_ticks: int = 1
var power: int = 0
var vision: int = 50 * Fx.ONE
var requires: PackedStringArray = []
var produces: PackedStringArray = []
var dropoff: bool = false
var free_unit: String = ""
## Infantry units it can hold (P3-05); 0 = can't be garrisoned.
var garrison_capacity: int = 0
var limit: int = 0              ## most a player may have at once (0 = any number; superweapons: 1)
var requires_rank: int = 1      ## commander rank needed to build it (P3-03)
## Abilities (P3-03: the superweapon is one; AbilitySystem).
var abilities: Array[AbilityDef] = []
var weapons: Array[WeaponDef] = []
var model_path: String = ""
var icon_path: String = ""
