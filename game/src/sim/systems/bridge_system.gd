class_name BridgeSystem
extends RefCounted
## Bridges (P3-11, docs/design/mechanics.md). Each deck in a map's
## `bridges_m` is a neutral, walkable `bridge` building (MatchSetup). Only an
## explicit ATTACK order targets one (splash and auto-targeting never do).
## At 0 hp it doesn't die: it collapses. Ground units on the deck fall into
## the river, and the deck's passable cells are claimed like a footprint, so
## nothing can cross. Any side's builders repair it for free (REPAIR, 1% a
## second each, ConstructionSystem); at REOPEN_PERCENT health the deck opens
## again.

const REOPEN_PERCENT: int = 50


## True for a bridge that is up: the one neutral thing units may attack.
static func standing(t: SimEntity) -> bool:
	return t.building != null and t.building.bridge and not t.building.collapsed and not t.dead


## True if `e` may fire at bridge `t`: only on an explicit attack order.
static func attackable(e: SimEntity, t: SimEntity) -> bool:
	return standing(t) and e.order == SimEntity.Order.ATTACK and e.order_target_id == t.id


## Called by WorldDamage when a bridge reaches 0 hp.
static func collapse(world: SimWorld, e: SimEntity) -> void:
	var b: SimBuilding = e.building
	b.collapsed = true
	e.hp = 0
	for id: int in world.entity_ids:
		var u: SimEntity = world.entities[id]
		if u.dead or u.building != null or u.mover == null or u.mover.flying or u.inside_id != 0:
			continue
		var cx: int = SimMap.cell_coord(u.x)
		var cy: int = SimMap.cell_coord(u.y)
		if cx >= b.cell_x and cx < b.cell_x + b.w and cy >= b.cell_y and cy < b.cell_y + b.h:
			u.hp = 0
			u.dead = true
			world.events.append({"type": "died", "id": u.id, "def_id": u.def_id,
					"player": u.player_id, "x": u.x, "y": u.y, "killer": 0})
	world.map.claim_passable(b.cell_x, b.cell_y, b.w, b.h, e.id)
	world.events.append({"type": "bridge_collapsed", "id": e.id, "x": e.x, "y": e.y})


## Called after a repair adds health: the deck opens again at REOPEN_PERCENT.
static func repaired(world: SimWorld, e: SimEntity) -> void:
	if e.building.collapsed and e.hp * 100 >= e.max_hp * REOPEN_PERCENT:
		e.building.collapsed = false
		world.map.clear_footprint(e.id)
		world.events.append({"type": "bridge_reopened", "id": e.id, "x": e.x, "y": e.y})
