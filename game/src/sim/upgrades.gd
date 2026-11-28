class_name Upgrades
extends RefCounted
## Upgrades (P2-05): the RESEARCH and UPGRADE_UNIT commands, research
## progress, and applying effects to units. Ints only.


static func apply_command(world: SimWorld, c: SimCommand) -> void:
	if world.content == null:
		return
	var def: UpgradeDef = world.content.get_upgrade(c.def_id)
	if def == null:
		return
	var player: SimPlayer = world.get_player(c.player_id)
	if def.faction != player.faction and player.faction != "":
		return
	if player.rank < def.requires_rank or not world.has_requirements(c.player_id, def.requires):
		return
	match c.type:
		SimCommand.Type.RESEARCH:
			_research(world, c, def, player)
		SimCommand.Type.UPGRADE_UNIT:
			_upgrade_units(world, c, def, player)


static func _research(world: SimWorld, c: SimCommand, def: UpgradeDef, player: SimPlayer) -> void:
	if def.scope != "global" or player.upgrades.has(def.id) or researching(world, c.player_id, def.id):
		return
	var b: SimEntity = world.get_entity(c.target_entity)
	if b == null or b.dead or b.building == null or b.player_id != c.player_id or not b.building.built:
		return
	if b.def_id != def.researched_at or b.building.research_id != "" or player.credits < def.cost:
		return
	player.credits -= def.cost
	b.building.research_id = def.id
	b.building.research_progress = 0


static func _upgrade_units(world: SimWorld, c: SimCommand, def: UpgradeDef, player: SimPlayer) -> void:
	if def.scope != "unit":
		return
	for e: SimEntity in WorldCommands.owned(world, c):
		if not def.applies(e.def_id) or e.upgrades.has(def.id) or player.credits < def.cost:
			continue
		player.credits -= def.cost
		e.upgrades.append(def.id)
		apply_effects(e, def)
		world.events.append({"type": "upgraded", "id": e.id, "upgrade": def.id, "player": e.player_id})


## True if one of the player's buildings is researching this upgrade.
static func researching(world: SimWorld, player_id: int, upgrade_id: String) -> bool:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == player_id and e.building != null and e.building.research_id == upgrade_id:
			return true
	return false


## Research progress, after production. Low power halves the speed.
static func step(world: SimWorld) -> void:
	if world.content == null:
		return
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var b: SimBuilding = e.building
		if b == null or e.dead or not b.built or b.research_id == "" or b.is_disabled(world.tick):
			continue
		var player: SimPlayer = world.get_player(e.player_id)
		if player.low_power() and world.tick % 2 == 1:
			continue
		var def: UpgradeDef = world.content.get_upgrade(b.research_id)
		b.research_progress += 1
		if def != null and b.research_progress < def.research_ticks:
			continue
		b.research_id = ""
		b.research_progress = 0
		if def == null:
			continue
		grant(world, e.player_id, def.id)
		world.events.append({"type": "researched", "upgrade": def.id, "player": e.player_id, "building": e.id})


## Gives a player a global upgrade now (research done, or a doctrine's bonus,
## P3-12b): it applies to their units and to every later one.
static func grant(world: SimWorld, player_id: int, upgrade_id: String) -> void:
	var def: UpgradeDef = world.content.get_upgrade(upgrade_id) if world.content != null else null
	var player: SimPlayer = world.get_player(player_id)
	if def == null or player.upgrades.has(upgrade_id):
		return
	player.upgrades.append(def.id)
	for uid: int in world.entity_ids:
		var u: SimEntity = world.entities[uid]
		if u.player_id == player_id and not u.dead and def.applies(u.def_id):
			apply_effects(u, def)


## A new unit gets every global upgrade its player has researched.
static func apply_global(world: SimWorld, e: SimEntity) -> void:
	if world.content == null or e.player_id == 0:
		return
	for up_id: String in world.get_player(e.player_id).upgrades:
		var def: UpgradeDef = world.content.get_upgrade(up_id)
		if def != null and def.applies(e.def_id):
			apply_effects(e, def)


static func apply_effects(e: SimEntity, def: UpgradeDef) -> void:
	var fx: Dictionary[String, int] = def.effects
	if fx.has("speed_percent") and e.mover != null:
		e.mover.speed = (e.mover.speed * (100 + fx["speed_percent"])) / 100
	if fx.has("max_hp_percent"):
		var extra: int = (e.max_hp * fx["max_hp_percent"]) / 100
		e.max_hp += extra
		e.hp += extra
	if fx.has("vision_percent"):
		e.vision = (e.vision * (100 + fx["vision_percent"])) / 100
	for w: SimWeapon in e.weapons:
		if fx.has("damage_percent"):
			w.damage = (w.damage * (100 + fx["damage_percent"])) / 100
		if fx.has("range_percent"):
			w.max_range = (w.max_range * (100 + fx["range_percent"])) / 100
	if fx.has("aps_charges"):
		e.aps_max += fx["aps_charges"]
		e.aps_charges += fx["aps_charges"]
	if fx.has("cage_hits"):
		e.cage_hits += fx["cage_hits"]


## Whether `e` owns an upgrade (bought for it, or researched by its player).
static func has_upgrade(world: SimWorld, e: SimEntity, upgrade_id: String) -> bool:
	return e.upgrades.has(upgrade_id) or world.get_player(e.player_id).upgrades.has(upgrade_id)
