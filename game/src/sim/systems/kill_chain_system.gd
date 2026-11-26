class_name KillChainSystem
extends RefCounted
## Kill chain (P2-04), after JammingSystem.
##
## Weapons with needs_spotter may fire beyond their owner's own sight range
## only at targets a friendly spotter (recon drone; later sniper and recon
## teams, satellite passes) currently sees. Jammed drones don't spot. A guided
## kill-chain shot whose target is no longer spotted (and not in its shooter's
## own sight) loses guidance in flight and flies to the last known point.
## This system rebuilds SimWorld.active_spotters for the tick.


static func step(world: SimWorld) -> void:
	world.active_spotters.clear()
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or not e.spotter:
			continue
		if e.drone != null and (e.drone.jammed or e.drone.spoofed_ticks > 0):
			continue
		world.active_spotters.append(e)


## True if `w` (on `e`) may engage `t` under the kill-chain rule.
static func may_engage(world: SimWorld, e: SimEntity, w: SimWeapon, t: SimEntity) -> bool:
	if not w.needs_spotter:
		return true
	return own_sight(e, t.x, t.y) or world.is_spotted(e.player_id, t.x, t.y)


static func own_sight(e: SimEntity, x: int, y: int) -> bool:
	var dx: int = x - e.x
	var dy: int = y - e.y
	return dx * dx + dy * dy <= e.vision * e.vision


## Called by CombatSystem for kill-chain projectiles each tick.
static func check_guidance(world: SimWorld, p: SimProjectile) -> void:
	if not p.guided or not p.needs_spotter:
		return
	var t: SimEntity = world.get_entity(p.target_id)
	if t == null or t.dead:
		return
	if world.is_spotted(p.player_id, t.x, t.y):
		return
	var shooter: SimEntity = world.get_entity(p.attacker_id)
	if shooter != null and not shooter.dead and own_sight(shooter, t.x, t.y):
		return
	p.guided = false   # keeps flying to the last point it knew
	p.target_id = 0
	world.events.append({"type": "lost_guidance", "x": p.x, "y": p.y})
