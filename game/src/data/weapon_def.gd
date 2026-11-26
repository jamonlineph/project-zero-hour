class_name WeaponDef
extends RefCounted
## A weapon's content definition in sim units, built by ContentDb from
## res://data/weapons/<id>.json (fields in docs/design/combat.md).

var id: String = ""
var damage: int = 0
var damage_type: String = ""
var max_range: int = 0             ## fixed-point meters
var min_range: int = 0             ## fixed-point meters
var reload_ticks: int = 1
var projectile: String = "instant" ## "instant", "ballistic" or "guided"
var projectile_speed: int = 0      ## fixed-point meters per tick (0 for instant)
var splash_radius: int = 0         ## fixed-point meters (0 = single target)
var splash_edge_percent: int = 50  ## damage at the edge of the splash, percent
var targets: PackedStringArray = ["ground"]
## Cone weapons (microwave, P2-02): half the cone's width in binary angle
## units; every valid target inside the cone and range is hit. 0 = single target.
var cone_half: int = 0
