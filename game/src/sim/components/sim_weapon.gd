class_name SimWeapon
extends RefCounted
## One weapon on an entity: its stats (copied from WeaponDef at spawn) and its
## state (cooldown and current target). Ints and strings only.

var def_id: String = ""
var damage: int = 0
var damage_type: String = ""
var max_range: int = 0          ## fixed-point meters
var min_range: int = 0
var reload_ticks: int = 1
var projectile: String = "instant"
var projectile_speed: int = 0   ## fixed-point meters per tick
var splash_radius: int = 0
var splash_edge_percent: int = 50
var targets: PackedStringArray = []
var cone_half: int = 0           ## binary angle units; 0 = single target (P2-02)
var needs_spotter: bool = false  ## kill chain (P2-04)
var drone_attack: bool = false   ## cage armor softens it (P2-06)
var stock_max: int = 0           ## interceptor stock (P2-07); 0 = unlimited
var stock: int = 0
var restock_ticks: int = 0
var restock_progress: int = 0

var cooldown: int = 0           ## ticks until it can fire again
var target_id: int = 0          ## entity id, 0 = none


static func from_def(def: WeaponDef) -> SimWeapon:
	var w := SimWeapon.new()
	w.def_id = def.id
	w.damage = def.damage
	w.damage_type = def.damage_type
	w.max_range = def.max_range
	w.min_range = def.min_range
	w.reload_ticks = def.reload_ticks
	w.projectile = def.projectile
	w.projectile_speed = def.projectile_speed
	w.splash_radius = def.splash_radius
	w.splash_edge_percent = def.splash_edge_percent
	w.targets = def.targets.duplicate()
	w.cone_half = def.cone_half
	w.needs_spotter = def.needs_spotter
	w.drone_attack = def.drone_attack
	w.stock_max = def.stock
	w.stock = def.stock
	w.restock_ticks = def.restock_ticks
	return w


func write_hash(h: SimHash) -> void:
	h.add_string(def_id)
	h.add_int(cooldown)
	h.add_int(target_id)
	if stock_max > 0:   # only then, so older replays hash as before
		h.add_int(stock)
		h.add_int(restock_progress)