class_name GarrisonSystem
extends RefCounted
## Garrisons (P3-05), right after OrderSystem.
##
## - Infantry given a GARRISON order walk to the structure and go inside once
##   within ENTER_RANGE of its walls, if it has room and is theirs or an empty
##   neutral (town) building. A neutral building belongs to whoever is inside
##   and turns neutral again when empty.
## - Units inside sit at the structure's center: they see and fire from there
##   (RANGE_BONUS extra reach, CombatSystem) but can't be targeted. Splash
##   doesn't reach them, except thermobaric damage (CLEAR_PERCENT of it), which
##   also hits everyone inside when it hits the building: that clears it.
## - UNLOAD lets everyone out next to the building. If the building is
##   destroyed, the units inside come out hurt (EJECT_DAMAGE_PERCENT of their
##   max hp).

const ENTER_RANGE: int = 3 * Fx.ONE
const RANGE_BONUS: int = 5 * Fx.ONE
const CLEAR_PERCENT: int = 50
const EJECT_DAMAGE_PERCENT: int = 25


## True if `e` may go into `s` now.
static func can_enter(e: SimEntity, s: SimEntity) -> bool:
	return e != null and s != null and not e.dead and not s.dead and e.inside_id == 0 \
		and e.armor_class == "infantry" and e.mover != null \
		and s.garrison != null and s.building != null and s.building.built and s.garrison.has_room() \
		and (s.player_id == e.player_id or s.player_id == 0)


static func apply_command(world: SimWorld, c: SimCommand) -> void:
	match c.type:
		SimCommand.Type.GARRISON:
			var s: SimEntity = world.get_entity(c.target_entity)
			for e: SimEntity in WorldCommands.owned_movers(world, c):
				if e.armor_class != "infantry" or s == null or s.garrison == null:
					continue
				if s.player_id != 0 and s.player_id != c.player_id:
					continue
				e.order = SimEntity.Order.GARRISON
				e.order_target_id = s.id
				var p: Vector2i = world.approach_point(s, e.x, e.y)
				e.mover.order_move(p.x, p.y)
				e.mover.follow_leader = 0
		SimCommand.Type.UNLOAD:
			var s: SimEntity = world.get_entity(c.target_entity)
			if s != null and s.garrison != null and s.player_id == c.player_id:
				unload(world, s)


static func step(world: SimWorld) -> void:
	# Units whose building is gone come out first (it was destroyed last tick).
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.inside_id != 0 and not e.dead:
			var s: SimEntity = world.get_entity(e.inside_id)
			if s == null or s.dead:
				_leave(world, e, null)
				e.hp = maxi(1, e.hp - (e.max_hp * EJECT_DAMAGE_PERCENT) / 100)
	# Units walking in.
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.order != SimEntity.Order.GARRISON or e.dead:
			continue
		var s: SimEntity = world.get_entity(e.order_target_id)
		var mover: SimMover = e.mover
		if s == null or s.dead or s.garrison == null or (s.player_id != 0 and s.player_id != e.player_id) \
				or not s.garrison.has_room():
			e.order = SimEntity.Order.IDLE
			e.order_target_id = 0
			continue
		if world.distance_to_body(e.x, e.y, s) <= ENTER_RANGE:
			if can_enter(e, s):
				_enter(world, e, s)
		elif not mover.has_target and not mover.needs_path:
			var p: Vector2i = world.approach_point(s, e.x, e.y)
			mover.order_move(p.x, p.y)
	# Occupants stay at their building; empty town buildings turn neutral.
	for id: int in world.entity_ids:
		var s: SimEntity = world.entities[id]
		if s.garrison == null or s.dead:
			continue
		var kept: Array[int] = []
		for oid: int in s.garrison.occupants:
			var o: SimEntity = world.get_entity(oid)
			if o == null or o.dead or o.inside_id != s.id:
				continue
			kept.append(oid)
			o.x = s.x
			o.y = s.y
		s.garrison.occupants = kept
		if kept.is_empty() and s.garrison.neutral:
			s.player_id = 0


## Everyone inside `s` comes out next to it.
static func unload(world: SimWorld, s: SimEntity) -> void:
	for oid: int in s.garrison.occupants:
		var o: SimEntity = world.get_entity(oid)
		if o != null and not o.dead:
			_leave(world, o, s)
	s.garrison.occupants.clear()
	if s.garrison.neutral:
		s.player_id = 0


static func _enter(world: SimWorld, e: SimEntity, s: SimEntity) -> void:
	e.inside_id = s.id
	s.garrison.occupants.append(e.id)
	if s.player_id == 0:
		s.player_id = e.player_id
	e.mover.stop()
	e.order = SimEntity.Order.IDLE
	e.order_target_id = 0
	for w: SimWeapon in e.weapons:
		w.target_id = 0
	e.x = s.x
	e.y = s.y
	world.events.append({"type": "garrisoned", "id": e.id, "building": s.id, "player": e.player_id})


## Puts `e` outside: next to `s` (its door side), or where it is if `s` is gone.
static func _leave(world: SimWorld, e: SimEntity, s: SimEntity) -> void:
	e.inside_id = 0
	if s != null:
		var p: Vector2i = world.approach_point(s, s.x, s.y + Fx.from_int(100))
		e.x = p.x
		e.y = p.y
	e.order = SimEntity.Order.IDLE
	world.events.append({"type": "ungarrisoned", "id": e.id})
