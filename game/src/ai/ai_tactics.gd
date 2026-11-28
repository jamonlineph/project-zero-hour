class_name AiTactics
extends RefCounted
## Small unit tactics for the skirmish AI (split out of AiPlayer): spotters as
## forward observers (P2-11e), holding town houses (P3-05), abilities
## (P3-02f), superweapons (P3-03) and capturing buildings (P3-08a).

## How far ahead of the army spotters fly while it attacks (meters).
const SPOTTER_LEAD_M: int = 30
## Infantry squads the AI keeps in town houses on its half of the map (P3-05).
const TOWN_SQUADS: int = 2
## How far from its HQ the AI goes to capture buildings, and how many
## captures it runs at once (P3-08a).
const CAPTURE_REACH_M: int = 120
const CAPTURES_AT_ONCE: int = 1


## Keeps spotters over the army: at its center, or while attacking
## SPOTTER_LEAD_M ahead of it toward the target, as forward observers for
## kill-chain weapons (P2-11e). Sends those that drifted more than 12 m from
## that point back to it. Drones heading home to recharge are left alone.
static func escort(target: SimEntity, spotters: Array[SimEntity], fighters: Array[SimEntity], cmds: Array[SimCommand]) -> void:
	if spotters.is_empty() or fighters.is_empty():
		return
	var cx: int = 0
	var cy: int = 0
	for f: SimEntity in fighters:
		cx += f.x
		cy += f.y
	cx /= fighters.size()
	cy /= fighters.size()
	if target != null and not target.dead:
		var dist: int = Fx.length(target.x - cx, target.y - cy)
		var lead: int = mini(SPOTTER_LEAD_M * Fx.ONE, dist)
		if dist > 0:
			cx += ((target.x - cx) * lead) / dist
			cy += ((target.y - cy) * lead) / dist
	var reach: int = 12 * Fx.ONE
	var ids: Array[int] = []
	for e: SimEntity in spotters:
		if e.drone != null and e.drone.returning:
			continue
		if Fx.length_sq(e.x - cx, e.y - cy) > Fx.length_sq(reach, 0):
			ids.append(e.id)
	if not ids.is_empty():
		cmds.append(SimCommand.make_move(ids, cx, cy))


## Sends an idle infantry squad into the nearest empty town house on our half
## of the map, keeping up to TOWN_SQUADS there (P3-05).
static func occupy_town(world: SimWorld, hq: SimEntity, army: Array[SimEntity], garrisoned: int, cmds: Array[SimCommand]) -> void:
	var heading_in: int = 0
	for e: SimEntity in army:
		if e.order == SimEntity.Order.GARRISON:
			heading_in += 1
	if hq == null or garrisoned + heading_in >= TOWN_SQUADS:
		return
	var west: bool = hq.x < world.map_width / 2
	var best: SimEntity = null
	var best_d: int = 0
	for id: int in world.entity_ids:
		var s: SimEntity = world.entities[id]
		if s.dead or s.garrison == null or not s.garrison.neutral or s.player_id != 0:
			continue
		if (s.x < world.map_width / 2) != west:
			continue
		var d: int = Fx.length(s.x - hq.x, s.y - hq.y)
		if best == null or d < best_d:
			best = s
			best_d = d
	if best == null:
		return
	for e: SimEntity in army:
		if e.armor_class == "infantry" and e.order == SimEntity.Order.IDLE:
			cmds.append(SimCommand.make_garrison([e.id], best.id))
			return


## Units with ready abilities use them (P3-02f): a strike on the nearest
## enemy building, else unit, they can see in range; a disable on an enemy
## building they stand next to. One ability per unit per think.
static func use_abilities(world: SimWorld, units: Array[SimEntity], cmds: Array[SimCommand]) -> void:
	if world.content == null:
		return
	for e: SimEntity in units:
		var def: UnitDef = world.content.get_unit(e.def_id)
		if def == null or def.abilities.is_empty() or e.inside_id != 0:
			continue
		for a: AbilityDef in def.abilities:
			if world.tick < int(e.ability_ready.get(a.id, 0)):
				continue
			var reach: int = a.range + (SimWorld.MAX_UNIT_RADIUS if a.kind == "disable" else 0)
			var target: SimEntity = _ability_target(world, e, a, reach)
			if target != null:
				cmds.append(SimCommand.make_use_ability([e.id], a.id, target.x, target.y, target.id))
				break


static func _ability_target(world: SimWorld, e: SimEntity, a: AbilityDef, reach: int) -> SimEntity:
	var best: SimEntity = null
	var best_score: int = 0
	for t: SimEntity in world.query_enemies(e.player_id, e.x, e.y, reach):
		if t.dead or t.inside_id != 0 or (t.mover != null and t.mover.flying):
			continue
		if a.kind == "disable" and (t.building == null or t.building.is_disabled(world.tick)):
			continue
		if not world.can_see(e.player_id, t.x, t.y):
			continue
		# Buildings first, then the nearest; ids break ties.
		var score: int = Fx.length(t.x - e.x, t.y - e.y) - (1000 * Fx.ONE if t.building != null else 0)
		if best == null or score < best_score or (score == best_score and t.id < best.id):
			best = t
			best_score = score
	return best


## True if one of our superweapons is charged (P3-03).
static func superweapon_ready(world: SimWorld, buildings: Array[SimEntity]) -> bool:
	for b: SimEntity in buildings:
		if b.ability_ready.is_empty() or not b.building.built:
			continue
		for a: AbilityDef in AbilitySystem.abilities_of(world, b):
			if a.kind == "superweapon" and world.tick >= int(b.ability_ready.get(a.id, 0)):
				return true
	return false


## Fires every charged superweapon we own at `target` (P3-03).
static func fire_superweapons(world: SimWorld, buildings: Array[SimEntity], target: SimEntity, cmds: Array[SimCommand]) -> void:
	if target == null or world.content == null:
		return
	for b: SimEntity in buildings:
		if not b.building.built or b.building.is_disabled(world.tick):
			continue
		for a: AbilityDef in AbilitySystem.abilities_of(world, b):
			if a.kind == "superweapon" and world.tick >= int(b.ability_ready.get(a.id, 0)):
				cmds.append(SimCommand.make_use_ability([b.id], a.id, target.x, target.y))


## Sends an idle infantry squad to capture the nearest capturable building
## that isn't ours within CAPTURE_REACH_M of the HQ (P3-08a), at most
## CAPTURES_AT_ONCE at a time (ties: lower id).
static func capture(world: SimWorld, player_id: int, hq: SimEntity, army: Array[SimEntity], cmds: Array[SimCommand]) -> void:
	if hq == null:
		return
	var busy: int = 0
	var squad: SimEntity = null
	for e: SimEntity in army:
		if e.order == SimEntity.Order.CAPTURE:
			busy += 1
		elif squad == null and e.armor_class == "infantry" and e.inside_id == 0 and e.order == SimEntity.Order.IDLE \
				and not e.weapons.is_empty():
			squad = e
	if busy >= CAPTURES_AT_ONCE or squad == null:
		return
	var best: SimEntity = null
	var best_d: int = 0
	for id: int in world.entity_ids:
		var s: SimEntity = world.entities[id]
		if not CaptureSystem.capturable_by(world, s, player_id):
			continue
		var d: int = Fx.length(s.x - hq.x, s.y - hq.y)
		if d > CAPTURE_REACH_M * Fx.ONE:
			continue
		if best == null or d < best_d:
			best = s
			best_d = d
	if best != null:
		cmds.append(SimCommand.make_capture([squad.id], best.id))

