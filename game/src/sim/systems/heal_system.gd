class_name HealSystem
extends RefCounted
## Healing auras (P3-12a): a unit or building with "heal_aura": {radius_cm,
## percent_per_s, classes} heals friendly units of those armor classes within
## the radius by that percent of their max hp, once a second (the EU's combat
## medics heal infantry; its logistics trucks repair vehicles; a captured
## field hospital heals its owner's infantry, P3-08a). Auras don't stack:
## each unit is healed at most once a second. Healers in id order; neutral
## buildings heal no one.


static func step(world: SimWorld) -> void:
	if world.content == null or world.tick == 0 or world.tick % SimWorld.TICK_RATE != 0:
		return
	var healed: Dictionary[int, bool] = {}
	for id: int in world.entity_ids:
		var h: SimEntity = world.entities[id]
		if h.dead or h.inside_id != 0 or h.player_id == 0 or (h.mover == null and h.building == null):
			continue
		var radius: int = 0
		var percent: int = 0
		var classes: PackedStringArray = []
		if h.building != null:
			var bd: BuildingDef = world.content.get_building(h.def_id)
			if bd == null or not h.building.built:
				continue
			radius = bd.heal_radius
			percent = bd.heal_percent_per_s
			classes = bd.heal_classes
		else:
			var ud: UnitDef = world.content.get_unit(h.def_id)
			if ud == null:
				continue
			radius = ud.heal_radius
			percent = ud.heal_percent_per_s
			classes = ud.heal_classes
		if radius <= 0:
			continue
		var team: int = world.team_of(h.player_id)
		var friends: Array[SimEntity] = world.query_radius(h.x, h.y, radius)
		friends.sort_custom(func(a: SimEntity, b: SimEntity) -> bool: return a.id < b.id)
		for t: SimEntity in friends:
			if t.dead or t.inside_id != 0 or t.building != null or t.hp >= t.max_hp or healed.has(t.id):
				continue
			if world.team_of(t.player_id) != team or not classes.has(t.armor_class):
				continue
			t.hp = mini(t.max_hp, t.hp + maxi(1, (t.max_hp * percent) / 100))
			healed[t.id] = true
