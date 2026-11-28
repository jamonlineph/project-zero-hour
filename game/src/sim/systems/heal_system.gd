class_name HealSystem
extends RefCounted
## Healing auras (P3-12a): a unit with "heal_aura": {radius_cm, percent_per_s,
## classes} heals friendly units of those armor classes within the radius by
## that percent of their max hp, once a second (the EU's combat medics heal
## infantry; its logistics trucks repair vehicles). Auras don't stack: each
## unit is healed at most once a second. Healers in id order.


static func step(world: SimWorld) -> void:
	if world.content == null or world.tick == 0 or world.tick % SimWorld.TICK_RATE != 0:
		return
	var healed: Dictionary[int, bool] = {}
	for id: int in world.entity_ids:
		var h: SimEntity = world.entities[id]
		if h.dead or h.inside_id != 0 or h.mover == null:
			continue
		var def: UnitDef = world.content.get_unit(h.def_id)
		if def == null or def.heal_radius <= 0:
			continue
		var team: int = world.team_of(h.player_id)
		var friends: Array[SimEntity] = world.query_radius(h.x, h.y, def.heal_radius)
		friends.sort_custom(func(a: SimEntity, b: SimEntity) -> bool: return a.id < b.id)
		for t: SimEntity in friends:
			if t.dead or t.inside_id != 0 or t.building != null or t.hp >= t.max_hp or healed.has(t.id):
				continue
			if world.team_of(t.player_id) != team or not def.heal_classes.has(t.armor_class):
				continue
			t.hp = mini(t.max_hp, t.hp + maxi(1, (t.max_hp * def.heal_percent_per_s) / 100))
			healed[t.id] = true
