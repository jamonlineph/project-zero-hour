class_name InteropSystem
extends RefCounted
## EU interoperability (P3-12c, docs/design/factions.md): groups that mix
## unit types fight better together. Once a second, each armed ground or air
## unit of rules.interop_faction checks its own side's armed units within
## rules.interop_radius: with rules.interop_min_types different types or more
## (itself included) it gets `interop`, and CombatSystem reloads its weapons
## rules.interop_reload_percent faster (twice that with rules.interop_doubler).
## Units in entity_ids order; the result only depends on positions.

const INTERVAL: int = SimWorld.TICK_RATE


static func step(world: SimWorld) -> void:
	var r: SimRules = world.rules
	if r.interop_faction == "" or r.interop_reload_percent <= 0 or world.tick % INTERVAL != 0:
		return
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		e.interop = _counts(world, e) and _mixed(world, e)


## True for units the bonus can apply to: armed, not a building, not a
## passenger, of the interop faction.
static func _counts(world: SimWorld, e: SimEntity) -> bool:
	return not e.dead and e.building == null and not e.weapons.is_empty() and e.inside_id == 0 \
		and world.get_player(e.player_id).faction == world.rules.interop_faction


static func _mixed(world: SimWorld, e: SimEntity) -> bool:
	var types: Dictionary[String, bool] = {e.def_id: true}
	for o: SimEntity in world.query_radius(e.x, e.y, world.rules.interop_radius):
		if o.player_id == e.player_id and o.id != e.id and _counts(world, o):
			types[o.def_id] = true
			if types.size() >= world.rules.interop_min_types:
				return true
	return false


## Reload time for a weapon of this unit, with the bonus.
static func reload_ticks(world: SimWorld, e: SimEntity, w: SimWeapon) -> int:
	if not e.interop:
		return w.reload_ticks
	var pct: int = world.rules.interop_reload_percent
	if world.rules.interop_doubler != "" and world.get_player(e.player_id).powers.has(world.rules.interop_doubler):
		pct *= 2
	return maxi(1, (w.reload_ticks * (100 - pct)) / 100)
