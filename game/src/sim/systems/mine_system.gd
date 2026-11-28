class_name MineSystem
extends RefCounted
## Minefields (P3-10a), after stealth detection and before combat.
##
## A finished building with a "mine" (BuildingDef.mine_damage > 0) waits
## hidden (it is stealthy, StealthSystem) on ground units can cross
## (walkable: it doesn't block). When an enemy ground unit comes within its
## trigger range it goes off once: `mine_damage` of `mine_damage_type` with
## `mine_splash` around it (CombatSystem.impact), and is gone. Detected
## mines can be shot like any building.


static func step(world: SimWorld) -> void:
	if world.content == null:
		return
	var blown: Array[SimEntity] = []
	for id: int in world.entity_ids:
		var m: SimEntity = world.entities[id]
		if m.dead or m.building == null or not m.building.built or m.player_id == 0:
			continue
		var def: BuildingDef = world.content.get_building(m.def_id)
		if def == null or def.mine_damage <= 0:
			continue
		for t: SimEntity in world.query_enemies(m.player_id, m.x, m.y, def.mine_trigger + SimWorld.MAX_UNIT_RADIUS):
			if t.dead or t.mover == null or t.mover.flying or t.inside_id != 0:
				continue
			if Fx.length(t.x - m.x, t.y - m.y) <= def.mine_trigger + t.radius:
				blown.append(m)
				break
	for m: SimEntity in blown:
		var def: BuildingDef = world.content.get_building(m.def_id)
		CombatSystem.impact(world, m.player_id, m.id, 0, m.x, m.y, def.mine_damage, def.mine_damage_type,
				def.mine_splash, 50, PackedStringArray(["ground"]))
		m.dead = true
		world.events.append({"type": "mine", "id": m.id, "player": m.player_id, "x": m.x, "y": m.y})
