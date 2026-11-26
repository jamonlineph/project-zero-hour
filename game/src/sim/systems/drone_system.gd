class_name DroneSystem
extends RefCounted
## Drone endurance (P2-01), after OrderSystem and before PathingSystem.
##
## - Airborne drones use one tick of endurance per tick.
## - At RETURN_PERCENT or less, a drone with a living launcher flies home and
##   ignores other orders until it has recharged.
## - Parked near its launcher (not moving), a drone recharges, full in
##   RECHARGE_TICKS. It counts as docked and uses no endurance.
## - At 0 a drone crashes (destroyed, "died" event with cause "crashed").

const RETURN_PERCENT: int = 20
const RECHARGE_TICKS: int = 10 * SimWorld.TICK_RATE
const DOCK_RANGE: int = 6 * Fx.ONE


static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.drone == null:
			continue
		var d: SimDrone = e.drone
		var home: SimEntity = world.get_entity(d.home_id) if d.home_id != 0 else null
		if home != null and (home.dead or home.player_id != e.player_id):
			home = null
			d.home_id = 0
		var moving: bool = e.mover != null and (e.mover.has_target or e.mover.needs_path)
		d.docked = home != null and not moving and _near(e, home)
		if d.docked:
			d.endurance = mini(d.endurance_max, d.endurance + maxi(1, d.endurance_max / RECHARGE_TICKS))
			if d.endurance == d.endurance_max:
				d.returning = false
			continue
		d.endurance -= 1
		if d.endurance <= 0:
			_crash(world, e)
			continue
		if home == null:
			continue
		if not d.returning and d.endurance * 100 <= d.endurance_max * RETURN_PERCENT:
			d.returning = true
		if d.returning:
			_head_home(world, e, home)


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


static func _crash(world: SimWorld, e: SimEntity) -> void:
	e.hp = 0
	e.dead = true
	world.events.append({"type": "died", "id": e.id, "def_id": e.def_id, "player": e.player_id,
			"x": e.x, "y": e.y, "killer": 0, "cause": "crashed"})
