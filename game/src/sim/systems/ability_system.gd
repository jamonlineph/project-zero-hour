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
## - "superweapon" (P3-03, on buildings): `count` strikes anywhere on the
##   map. Its cooldown is the charge, which starts when the building is
##   finished (start_charge) and again after each launch; everyone can see
##   it count down. A disabled or unfinished building can't fire.


static func apply_command(world: SimWorld, c: SimCommand) -> void:
	if world.content == null:
		return
	var users: Array[SimEntity] = WorldCommands.owned(world, c)
	users.sort_custom(func(a: SimEntity, b: SimEntity) -> bool: return a.id < b.id)
	for e: SimEntity in users:
		var ability: AbilityDef = find(world, e, c.def_id)
		if ability == null or e.inside_id != 0 or world.tick < int(e.ability_ready.get(ability.id, 0)):
			continue
		if e.building != null and (not e.building.built or e.building.is_disabled(world.tick)):
			continue
		if _use(world, e, ability, c):
			e.ability_ready[ability.id] = world.tick + ability.cooldown_ticks
			world.events.append({"type": "ability_used", "id": e.id, "player": e.player_id, "ability": ability.id,
					"x": c.target_x, "y": c.target_y, "target": c.target_entity})
			return


## The ability with this id on the entity's unit or building type, or null.
static func find(world: SimWorld, e: SimEntity, ability_id: String) -> AbilityDef:
	for a: AbilityDef in abilities_of(world, e):
		if a.id == ability_id:
			return a
	return null


## The abilities of the entity's unit or building type.
static func abilities_of(world: SimWorld, e: SimEntity) -> Array[AbilityDef]:
	if world.content == null:
		return []
	if e.building != null:
		var bd: BuildingDef = world.content.get_building(e.def_id)
		return bd.abilities if bd != null else []
	var ud: UnitDef = world.content.get_unit(e.def_id)
	return ud.abilities if ud != null else []


## Starts the charge of a finished building's superweapon (P3-03).
static func start_charge(world: SimWorld, e: SimEntity) -> void:
	for a: AbilityDef in abilities_of(world, e):
		if a.kind == "superweapon":
			e.ability_ready[a.id] = world.tick + a.cooldown_ticks


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
		"superweapon":
			var sw: StrikeDef = world.content.get_strike(a.strike_id)
			if sw == null:
				return false
			for i: int in a.count:
				StrikeSystem.launch(world, sw, e.player_id, c.target_x, c.target_y)
			world.events.append({"type": "superweapon_fired", "player": e.player_id, "def_id": e.def_id,
					"x": c.target_x, "y": c.target_y})
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
