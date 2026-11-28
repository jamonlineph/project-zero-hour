class_name AbilitySystem
extends RefCounted
## Unit abilities (P3-02f), used with USE_ABILITY commands. The first unit
## in the command (lowest id) whose ability is ready and in range uses it, so
## a selection of three special-forces teams calls one strike, not three.
##
## - "strike": calls `count` strikes of `strike_id` (interceptable, like the
##   commander's) on a point the player can see within `range`.
## - "disable": shuts an enemy building down for `duration_ticks`: no
##   production, research, power or fire (SimBuilding.disabled_until). The
##   unit must be within `range` of the building's edge.


static func apply_command(world: SimWorld, c: SimCommand) -> void:
	if world.content == null:
		return
	var users: Array[SimEntity] = WorldCommands.owned(world, c)
	users.sort_custom(func(a: SimEntity, b: SimEntity) -> bool: return a.id < b.id)
	for e: SimEntity in users:
		var ability: AbilityDef = find(world, e, c.def_id)
		if ability == null or e.inside_id != 0 or world.tick < int(e.ability_ready.get(ability.id, 0)):
			continue
		if _use(world, e, ability, c):
			e.ability_ready[ability.id] = world.tick + ability.cooldown_ticks
			world.events.append({"type": "ability_used", "id": e.id, "player": e.player_id, "ability": ability.id,
					"x": c.target_x, "y": c.target_y, "target": c.target_entity})
			return


## The ability with this id on the entity's unit type, or null.
static func find(world: SimWorld, e: SimEntity, ability_id: String) -> AbilityDef:
	var def: UnitDef = world.content.get_unit(e.def_id)
	if def == null:
		return null
	for a: AbilityDef in def.abilities:
		if a.id == ability_id:
			return a
	return null


static func _use(world: SimWorld, e: SimEntity, a: AbilityDef, c: SimCommand) -> bool:
	match a.kind:
		"strike":
			if Fx.length(c.target_x - e.x, c.target_y - e.y) > a.range or not world.can_see(e.player_id, c.target_x, c.target_y):
				return false
			var strike: StrikeDef = world.content.get_strike(a.strike_id)
			if strike == null:
				return false
			for i: int in a.count:
				StrikeSystem.launch(world, strike, e.player_id, c.target_x, c.target_y)
			return true
		"disable":
			var t: SimEntity = world.get_entity(c.target_entity)
			if t == null or t.dead or t.building == null or not world.are_enemies(e.player_id, t.player_id):
				return false
			var reach: int = a.range + maxi(t.building.w, t.building.h) * SimMap.CELL / 2
			if Fx.length(t.x - e.x, t.y - e.y) > reach:
				return false
			t.building.disabled_until = maxi(t.building.disabled_until, world.tick + a.duration_ticks)
			world.events.append({"type": "disabled", "id": t.id, "until": t.building.disabled_until})
			return true
	return false
