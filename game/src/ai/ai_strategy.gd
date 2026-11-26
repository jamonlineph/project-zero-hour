class_name AiStrategy
extends RefCounted
## Skirmish AI v1 additions (P2-11): counter-building, commander powers and
## research. Same rules as AiPlayer: commands only, decisions only from the
## sim state and the preset, ints only.


## Extra mix weight per unit id, from the enemy units this AI can see.
## Preset "counters": {"armor_class": ["unit_id", ...]}; every 3 visible
## enemies of a class add 1 weight to each listed counter (at most +6).
static func counter_bonus(world: SimWorld, ai: AiPlayer) -> Dictionary[String, int]:
	var seen: Dictionary[String, int] = {}
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.building != null or e.strike != null or e.sensor or e.decoy_of != "":
			continue
		if not world.are_enemies(ai.player_id, e.player_id) or not world.can_see(ai.player_id, e.x, e.y):
			continue
		seen[e.armor_class] = seen.get(e.armor_class, 0) + 1
	var bonus: Dictionary[String, int] = {}
	for cls: String in ai.counters:
		var n: int = mini(6, seen.get(cls, 0) / 3)
		if n <= 0:
			continue
		for unit_id: String in ai.counters[cls]:
			bonus[unit_id] = bonus.get(unit_id, 0) + n
	return bonus


## Spends commander points in preset order, then uses ready powers.
static func powers(world: SimWorld, ai: AiPlayer, hq: SimEntity, army: Array[SimEntity], cmds: Array[SimCommand]) -> void:
	var player: SimPlayer = world.get_player(ai.player_id)
	if CommanderPowers.points(player) > 0:
		for id: String in ai.power_priority:
			var def: PowerDef = world.content.get_power(id)
			if def != null and not player.powers.has(id) and player.rank >= def.tier:
				cmds.append(SimCommand.make_choose_power(id))
				break
	for id: String in player.powers:
		var def: PowerDef = world.content.get_power(id)
		if def == null or def.kind == "unlock" or world.tick < int(player.power_ready.get(id, 0)):
			continue
		var at: Variant = _aim(world, ai, def, hq, army)
		if at == null:
			continue
		var p: Vector2i = at
		cmds.append(SimCommand.make_use_power(id, p.x, p.y))
		return   # one power per think, so they don't all go at once


## Where to use a power, or null to wait.
static func _aim(world: SimWorld, ai: AiPlayer, def: PowerDef, hq: SimEntity, army: Array[SimEntity]) -> Variant:
	match def.kind:
		"reinforce", "cyber":
			return Vector2i.ZERO if not army.is_empty() or def.kind == "reinforce" else null
		"reveal", "drone_sweep":
			var b: SimEntity = _enemy_base(world, ai, hq)
			return Vector2i(b.x, b.y) if b != null else null
		"strike":
			var c: Variant = _enemy_cluster(world, ai)
			if c == null:
				return null
			if def.needs_spotted and not world.is_spotted(ai.player_id, (c as Vector2i).x, (c as Vector2i).y):
				return null
			return c
		"jam_area", "wingmen":
			return _enemy_cluster(world, ai)
		"decoys":
			if hq == null:
				return null
			var b: SimEntity = _enemy_base(world, ai, hq)
			if b == null:
				return null
			return Vector2i(hq.x + (b.x - hq.x) / 4, hq.y + (b.y - hq.y) / 4)
	return null


## The visible enemy unit with the most visible enemy units within 20 m
## (ties: lower id), or null.
static func _enemy_cluster(world: SimWorld, ai: AiPlayer) -> Variant:
	var best: SimEntity = null
	var best_n: int = 0
	var reach: int = 20 * Fx.ONE
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.mover == null or e.strike != null or e.sensor:
			continue
		if not world.are_enemies(ai.player_id, e.player_id) or not world.can_see(ai.player_id, e.x, e.y):
			continue
		var n: int = 0
		for t: SimEntity in world.query_radius(e.x, e.y, reach):
			if not t.dead and t.player_id == e.player_id and t.mover != null:
				n += 1
		if best == null or n > best_n:
			best = e
			best_n = n
	if best == null or best_n < 3:
		return null
	return Vector2i(best.x, best.y)


## The enemy building nearest our HQ (start positions are public in skirmish).
static func _enemy_base(world: SimWorld, ai: AiPlayer, hq: SimEntity) -> SimEntity:
	if hq == null:
		return null
	var best: SimEntity = null
	var best_d: int = 0
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.building == null or not world.are_enemies(ai.player_id, e.player_id):
			continue
		var d: int = Fx.length_sq(e.x - hq.x, e.y - hq.y)
		if best == null or d < best_d:
			best = e
			best_d = d
	return best


## Researches the preset's upgrades in order when affordable.
static func research(world: SimWorld, ai: AiPlayer, buildings: Array[SimEntity], reserve: int, cmds: Array[SimCommand]) -> void:
	var player: SimPlayer = world.get_player(ai.player_id)
	for up_id: String in ai.research:
		if player.upgrades.has(up_id) or Upgrades.researching(world, ai.player_id, up_id):
			continue
		var def: UpgradeDef = world.content.get_upgrade(up_id)
		if def == null or player.credits - reserve < def.cost or player.rank < def.requires_rank:
			return
		for b: SimEntity in buildings:
			if b.def_id == def.researched_at and b.building.built and b.building.research_id == "":
				cmds.append(SimCommand.make_research(b.id, up_id))
				return
		return
