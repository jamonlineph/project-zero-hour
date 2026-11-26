class_name UnitDef
extends RefCounted
## A unit's content definition, already converted into simulation units.
## Built by ContentDb from res://data/units/<id>.json. Treat it as read-only.

var id: String = ""
var faction: String = ""        ## "us" (America), "ae" (UAE), "kp" (North Korea) or "eu" (EU)
var role: String = ""           ## see docs/design/units-and-buildings.md
var name: String = ""           ## generic display name (localization keys come later)
var armor_class: String = ""    ## see docs/design/combat.md
var max_hp: int = 1
var cost: int = 0
var speed: int = 0              ## fixed-point meters per tick
var turn_rate: int = Fx.ANGLE_FULL  ## binary angle units per tick; ANGLE_FULL = turns instantly
var radius: int = 0             ## fixed-point meters
var vision: int = 45 * Fx.ONE   ## sight radius, fixed-point meters (data: vision_cm)
var weapons: Array[WeaponDef] = []
var build_ticks: int = 1        ## production time (data: build_time_ms)
var requires: PackedStringArray = []   ## building ids the player must own (built)
var builder: bool = false       ## can construct and repair buildings
var gatherer: bool = false      ## collects supply
var flying: bool = false        ## flies over terrain (default: armor class "drone")
var endurance_ticks: int = 0    ## drones: flight time on a full charge (data: endurance_s); 0 = unlimited
var fiber_optic: bool = false   ## drones: immune to jamming and spoofing
var spotter: bool = false       ## marks targets for kill-chain weapons (P2-04)
var aps_charges: int = 0        ## active protection charges (P2-06)
var cage_hits: int = 0          ## drone hits cage armor softens (P2-06)
var decoy_of: String = ""       ## decoys: the unit id it imitates (P2-08)
var requires_unlock: String = ""  ## a commander unlock (power id) needed to build it (P2-09)
## Jammer (data: "jammer": {radius_cm, strength, spoof_radius_cm, spoof_range_cm, spoof_cooldown_s}).
var jam_radius: int = 0
var jam_strength: int = 0
var spoof_radius: int = 0
var spoof_range: int = 0
var spoof_cooldown_ticks: int = 0
var gather_capacity: int = 0
var gather_load_ticks: int = 1
var gather_unload_ticks: int = 1
var model_path: String = ""     ## res:// path to a .glb; may not exist yet
var icon_path: String = ""      ## res:// path to a .png build icon; may not exist yet


func is_infantry() -> bool:
	return armor_class == "infantry"
