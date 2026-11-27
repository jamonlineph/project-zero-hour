class_name SelectionText
extends RefCounted
## The selection panel's text (split out of Hud on 2026-11-27): one entity's name,
## health, rank, queue and garrison, or a count per type for a group.


static func describe(world: SimWorld, selected: Array[int]) -> String:
	if selected.is_empty():
		return ""
	if selected.size() == 1:
		var e: SimEntity = world.get_entity(selected[0])
		if e == null:
			return ""
		var text: String = "%s   %d / %d hp" % [name_of(world, e.def_id), e.hp, e.max_hp]
		if e.vet_rank > 0:
			text += "   veteran " + "*".repeat(e.vet_rank)
		if e.building != null:
			if not e.building.built:
				text += "   building %d%%" % ((100 * e.building.progress) / maxi(1, e.building.total))
			elif not e.building.queue.is_empty():
				var def: UnitDef = world.content.get_unit(e.building.queue[0])
				var pct: int = (100 * e.building.queue_progress) / maxi(1, def.build_ticks if def != null else 1)
				text += "\nQueue: %s (%d%%)%s" % [name_of(world, e.building.queue[0]), pct,
					" + %d more" % (e.building.queue.size() - 1) if e.building.queue.size() > 1 else ""]
		if e.gatherer != null and e.gatherer.carried > 0:
			text += "   carrying %d" % e.gatherer.carried
		if e.supply != null:
			text = "Supply site   %d credits left" % e.supply.remaining
		if e.garrison != null:
			text += "\nInside: %d / %d" % [e.garrison.occupants.size(), e.garrison.capacity]
		return text
	var counts: Dictionary[String, int] = {}
	for id: int in selected:
		var e: SimEntity = world.get_entity(id)
		if e != null:
			counts[e.def_id] = counts.get(e.def_id, 0) + 1
	var parts: PackedStringArray = []
	for def_id: String in counts:
		parts.append("%dx %s" % [counts[def_id], name_of(world, def_id)])
	return "%d selected: %s" % [selected.size(), ", ".join(parts)]


static func name_of(world: SimWorld, def_id: String) -> String:
	if world.content == null:
		return def_id
	var u: UnitDef = world.content.get_unit(def_id)
	if u != null:
		return u.name
	var b: BuildingDef = world.content.get_building(def_id)
	return b.name if b != null else def_id
