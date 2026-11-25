class_name UnitDef
extends RefCounted
## A unit's content definition, already converted into simulation units.
## Built by ContentDb from res://data/units/<id>.json. Treat it as read-only.

var id: String = ""
var faction: String = ""        ## "us", "cn", "ru" or "irr" (Irregulars)
var role: String = ""           ## see docs/design/units-and-buildings.md
var name: String = ""           ## generic display name (localization keys come later)
var armor_class: String = ""    ## see docs/design/combat.md
var max_hp: int = 1
var cost: int = 0
var speed: int = 0              ## fixed-point meters per tick
var turn_rate: int = Fx.ANGLE_FULL  ## binary angle units per tick; ANGLE_FULL = turns instantly
var radius: int = 0             ## fixed-point meters
var model_path: String = ""     ## res:// path to a .glb; may not exist yet
var icon_path: String = ""      ## res:// path to a .png build icon; may not exist yet


func is_infantry() -> bool:
	return armor_class == "infantry"
