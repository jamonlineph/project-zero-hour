class_name SimProjectile
extends RefCounted
## A shell, rocket or missile in flight. Ballistic projectiles fly to the
## point the target was at when fired; guided ones follow the target.

var id: int = 0
var player_id: int = 0
var attacker_id: int = 0
var target_id: int = 0          ## followed by guided projectiles; 0 = none
var guided: bool = false
var x: int = 0                  ## fixed-point meters
var y: int = 0
var prev_x: int = 0
var prev_y: int = 0
var dest_x: int = 0
var dest_y: int = 0
var speed: int = 0              ## fixed-point meters per tick
var damage: int = 0
var damage_type: String = ""
var splash_radius: int = 0
var splash_edge_percent: int = 50
var weapon_id: String = ""
var targets: PackedStringArray = []   ## splash only hurts what the weapon can target (not hashed: follows weapon_id)


func write_hash(h: SimHash) -> void:
	h.add_int(id)
	h.add_int(player_id)
	h.add_int(attacker_id)
	h.add_int(target_id)
	h.add_bool(guided)
	h.add_int(x)
	h.add_int(y)
	h.add_int(dest_x)
	h.add_int(dest_y)
	h.add_int(speed)
	h.add_int(damage)
	h.add_string(damage_type)
	h.add_int(splash_radius)
