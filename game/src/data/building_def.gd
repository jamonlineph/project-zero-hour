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
var weapons: Array[WeaponDef] = []
var model_path: String = ""
var icon_path: String = ""
