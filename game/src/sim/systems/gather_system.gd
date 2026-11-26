class_name GatherSystem
extends RefCounted
## Logistics trucks gather supply (P1-15).
##
## IDLE -> TO_SITE -> LOADING -> TO_DROPOFF -> UNLOADING -> TO_SITE ...
## - Idle gatherers with `auto` pick the nearest site that still has supply.
## - They unload at their player's nearest finished drop-off building.
## - A player's direct move order turns `auto` off until a GATHER order.

const REACH: int = 2 * Fx.ONE


static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var g: SimGatherer = e.gatherer
		if g == null or e.dead or e.mover == null:
			continue
		match g.state:
			SimGatherer.State.IDLE:
				if g.carried > 0:
					g.state = SimGatherer.State.TO_DROPOFF
				elif g.auto:
					var site: SimEntity = _valid_site(world, g.site_id)
					if site == null:
						site = _nearest_site(world, e)
					if site != null:
						g.site_id = site.id
						g.state = SimGatherer.State.TO_SITE
			SimGatherer.State.TO_SITE:
				var site: SimEntity = _valid_site(world, g.site_id)
				if site == null:
					g.site_id = 0
					g.state = SimGatherer.State.IDLE
				elif world.distance_to_body(e.x, e.y, site) <= e.radius + REACH:
					e.mover.stop()
					g.timer = g.load_ticks
					g.state = SimGatherer.State.LOADING
				elif not e.mover.has_target:
					var spot: Vector2i = world.approach_point(site, e.x, e.y)
					e.mover.order_move(spot.x, spot.y)
			SimGatherer.State.LOADING:
				g.timer -= 1
				if g.timer > 0:
					continue
				var site: SimEntity = _valid_site(world, g.site_id)
				if site == null:
					g.state = SimGatherer.State.IDLE
					continue
				var amount: int = mini(g.capacity, site.supply.remaining)
				site.supply.remaining -= amount
				g.carried = amount
				if site.supply.remaining <= 0:
					world.events.append({"type": "depleted", "id": site.id, "x": site.x, "y": site.y})
				g.state = SimGatherer.State.TO_DROPOFF
			SimGatherer.State.TO_DROPOFF:
				var drop: SimEntity = _valid_dropoff(world, e, g.dropoff_id)
				if drop == null:
					drop = _nearest_dropoff(world, e)
				if drop == null:
					continue   # nowhere to unload yet: wait
				g.dropoff_id = drop.id
				if world.distance_to_body(e.x, e.y, drop) <= e.radius + REACH:
					e.mover.stop()
					g.timer = g.unload_ticks
					g.state = SimGatherer.State.UNLOADING
				elif not e.mover.has_target:
					var spot: Vector2i = world.approach_point(drop, e.x, e.y)
					e.mover.order_move(spot.x, spot.y)
			SimGatherer.State.UNLOADING:
				g.timer -= 1
				if g.timer > 0:
					continue
				world.get_player(e.player_id).credits += g.carried
				world.events.append({"type": "income", "player": e.player_id, "amount": g.carried})
				g.carried = 0
				g.state = SimGatherer.State.TO_SITE if _valid_site(world, g.site_id) != null else SimGatherer.State.IDLE


static func _valid_site(world: SimWorld, site_id: int) -> SimEntity:
	var s: SimEntity = world.get_entity(site_id)
	if s == null or s.supply == null or s.supply.remaining <= 0:
		return null
	return s


static func _valid_dropoff(world: SimWorld, e: SimEntity, drop_id: int) -> SimEntity:
	var d: SimEntity = world.get_entity(drop_id)
	if d == null or d.dead or d.player_id != e.player_id or d.building == null or not d.building.built or not d.building.dropoff:
		return null
	return d


static func _nearest_site(world: SimWorld, e: SimEntity) -> SimEntity:
	var best: SimEntity = null
	var best_d: int = 0
	for id: int in world.entity_ids:
		var s: SimEntity = world.entities[id]
		if s.supply == null or s.supply.remaining <= 0:
			continue
		var d: int = Fx.length_sq(s.x - e.x, s.y - e.y) >> 16
		if best == null or d < best_d:
			best = s
			best_d = d
	return best


static func _nearest_dropoff(world: SimWorld, e: SimEntity) -> SimEntity:
	var best: SimEntity = null
	var best_d: int = 0
	for id: int in world.entity_ids:
		var d_ent: SimEntity = _valid_dropoff(world, e, id)
		if d_ent == null:
			continue
		var d: int = Fx.length_sq(d_ent.x - e.x, d_ent.y - e.y) >> 16
		if best == null or d < best_d:
			best = d_ent
			best_d = d
	return best
