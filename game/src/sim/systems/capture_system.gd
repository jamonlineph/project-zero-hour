class_name CaptureSystem
extends RefCounted
## Capturing neutral buildings (P3-08a), right after GarrisonSystem.
##
## - Infantry given a CAPTURE order walk to a capturable building (oil field,
##   solar farm, field hospital, data center...) that isn't already their
##   side's. Once within ENTER_RANGE of its walls they stop and capture.
## - A building being captured gains a tick of progress for every tick a
##   capturer stands by it; at its capture_ticks it changes hands and its
##   capturers go idle. Capturers of two sides at once contest it: nobody
##   gains progress until one side is gone (before, the lowest entity id won
##   the tie, which favored player 1). A capture by someone else, or a tick
##   with nobody capturing, starts it over. Enemies take it back the same way.
## - Captured buildings work for their owner (income, power, healing,
##   sight) but don't keep a player alive (VictorySystem).

const ENTER_RANGE: int = 3 * Fx.ONE


## True if `s` is a building that infantry of `player_id` could capture now.
static func capturable_by(world: SimWorld, s: SimEntity, player_id: int) -> bool:
	return s != null and not s.dead and s.building != null and s.building.capture_ticks > 0 \
		and (s.player_id == 0 or world.are_enemies(player_id, s.player_id))


static func apply_command(world: SimWorld, c: SimCommand) -> void:
	var s: SimEntity = world.get_entity(c.target_entity)
	if not capturable_by(world, s, c.player_id):
		return
	for e: SimEntity in WorldCommands.owned_movers(world, c):
		if e.armor_class != "infantry" or e.inside_id != 0:
			continue
		e.order = SimEntity.Order.CAPTURE
		e.order_target_id = s.id
		e.mover.order_move(s.x, s.y)


static func step(world: SimWorld) -> void:
	var capturer: Dictionary[int, int] = {}   # building id -> player capturing it this tick
	var contested: Dictionary[int, bool] = {}   # building id -> capturers of two sides
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.order != SimEntity.Order.CAPTURE:
			continue
		var s: SimEntity = world.get_entity(e.order_target_id)
		if not capturable_by(world, s, e.player_id):
			e.order = SimEntity.Order.IDLE
			e.order_target_id = 0
			if e.mover != null:
				e.mover.stop()
			continue
		var reach: int = ENTER_RANGE + maxi(s.building.w, s.building.h) * SimMap.CELL / 2
		if Fx.length(s.x - e.x, s.y - e.y) > reach:
			if e.mover != null and not e.mover.has_target:
				e.mover.order_move(s.x, s.y)
			continue
		if e.mover != null and e.mover.has_target:
			e.mover.stop()
		if not capturer.has(s.id):
			capturer[s.id] = e.player_id
		elif capturer[s.id] != e.player_id:
			contested[s.id] = true
	for id: int in world.entity_ids:
		var s: SimEntity = world.entities[id]
		if s.building == null or s.building.capture_ticks <= 0 or s.dead:
			continue
		var b: SimBuilding = s.building
		if contested.has(s.id):
			continue   # held where it was until one side is gone
		var who: int = capturer.get(s.id, 0)
		if who == 0:
			b.capture_player = 0
			b.capture_progress = 0
			continue
		if who != b.capture_player:
			b.capture_player = who
			b.capture_progress = 0
		b.capture_progress += 1
		if b.capture_progress >= b.capture_ticks:
			s.player_id = who
			b.capture_player = 0
			b.capture_progress = 0
			world.events.append({"type": "captured", "id": s.id, "def_id": s.def_id, "player": who})
			for uid: int in world.entity_ids:
				var u: SimEntity = world.entities[uid]
				if u.order == SimEntity.Order.CAPTURE and u.order_target_id == s.id:
					u.order = SimEntity.Order.IDLE
					u.order_target_id = 0
