class_name AirSystem
extends RefCounted
## Aircraft ammo and rearming (P3-04a), right after DroneSystem.
##
## - An aircraft's weapons with "ammo" fire only while they have some left;
##   nothing refills them in the air.
## - When every ammo weapon is empty, an aircraft with a living airbase of its
##   own flies home and ignores other orders until rearmed.
## - Parked near its airbase (not moving), it rearms: all ammo weapons from
##   empty to full in rearm_ticks, one round at a time, and repairs
##   REPAIR_PERCENT_PER_S of its max hp a second. Full again, it stays parked
##   until given an order.

const DOCK_RANGE: int = 8 * Fx.ONE
const REPAIR_PERCENT_PER_S: int = 2


static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.aircraft == null:
			continue
		var a: SimAircraft = e.aircraft
		var home: SimEntity = world.get_entity(a.home_id) if a.home_id != 0 else null
		if home != null and (home.dead or home.player_id != e.player_id):
			home = null
			a.home_id = 0
		var moving: bool = e.mover != null and (e.mover.has_target or e.mover.needs_path)
		a.docked = home != null and not moving and _near(e, home)
		if a.docked:
			_rearm(world, e)
			continue
		if home == null:
			continue
		if not a.returning and out_of_ammo(e):
			a.returning = true
		if a.returning:
			_head_home(world, e, home)


## True if the entity has ammo weapons and all of them are empty.
static func out_of_ammo(e: SimEntity) -> bool:
	var any: bool = false
	for w: SimWeapon in e.weapons:
		if w.stock_max > 0 and w.restock_ticks == 0:
			any = true
			if w.stock > 0:
				return false
	return any


static func _rearm(world: SimWorld, e: SimEntity) -> void:
	var a: SimAircraft = e.aircraft
	var total: int = 0
	var missing: int = 0
	for w: SimWeapon in e.weapons:
		if w.stock_max > 0 and w.restock_ticks == 0:
			total += w.stock_max
			missing += w.stock_max - w.stock
	if missing > 0:
		a.rearm_progress += 1
		if a.rearm_progress * total >= a.rearm_ticks:
			a.rearm_progress = 0
			for w: SimWeapon in e.weapons:
				if w.stock_max > 0 and w.restock_ticks == 0 and w.stock < w.stock_max:
					w.stock += 1
					break
	if world.tick % SimWorld.TICK_RATE == 0 and e.hp < e.max_hp:
		e.hp = mini(e.max_hp, e.hp + maxi(1, (e.max_hp * REPAIR_PERCENT_PER_S) / 100))
	if missing == 0:
		a.returning = false


static func _head_home(world: SimWorld, e: SimEntity, home: SimEntity) -> void:
	var p: Vector2i = world.approach_point(home, e.x, e.y)
	if e.order != SimEntity.Order.MOVE or not e.mover.has_target \
			or e.mover.target_x != p.x or e.mover.target_y != p.y:
		e.order = SimEntity.Order.MOVE
		e.order_target_id = 0
		for w: SimWeapon in e.weapons:
			w.target_id = 0
		e.mover.order_move(p.x, p.y)


static func _near(e: SimEntity, home: SimEntity) -> bool:
	var reach: int = DOCK_RANGE + home.radius
	var dx: int = e.x - home.x
	var dy: int = e.y - home.y
	return dx * dx + dy * dy <= reach * reach
