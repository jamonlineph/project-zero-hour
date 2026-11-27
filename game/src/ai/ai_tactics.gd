class_name AiTactics
extends RefCounted
## Small unit tactics for the skirmish AI (split out of AiPlayer): spotters as
## forward observers (P2-11e) and holding town houses (P3-05).

## How far ahead of the army spotters fly while it attacks (meters).
const SPOTTER_LEAD_M: int = 30
## Infantry squads the AI keeps in town houses on its half of the map (P3-05).
const TOWN_SQUADS: int = 2


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
