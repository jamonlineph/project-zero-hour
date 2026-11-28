class_name StealthSystem
extends RefCounted
## Stealth and detection (P3-09), after the spatial index rebuild and before
## combat.
##
## - A stealthy unit ("stealth": true, such as North Korea's infiltrators)
##   can't be seen or targeted by a team unless one of that team's detectors
##   ("detection_cm": snipers, recon drones) has it in range, any of that
##   team's units is within PROXIMITY, or it fired in the last REVEAL_TICKS.
## - Rebuilt every tick into world.stealth_seen (entity id -> teams that see
##   it), derived from hashed state, so it isn't hashed itself.

const PROXIMITY: int = 6 * Fx.ONE
const REVEAL_TICKS: int = 3 * SimWorld.TICK_RATE
const MAX_DETECTION: int = 60 * Fx.ONE   ## search radius; no detector reaches further


static func step(world: SimWorld) -> void:
	world.stealth_seen.clear()
	for id: int in world.entity_ids:
		var t: SimEntity = world.entities[id]
		if not t.stealth or t.dead:
			continue
		var teams: Dictionary[int, bool] = {}
		if world.tick < t.revealed_until:
			for pid: int in world.players:
				teams[world.team_of(pid)] = true
		else:
			for d: SimEntity in world.query_enemies(t.player_id, t.x, t.y, MAX_DETECTION):
				if d.dead or d.inside_id != 0 or d.player_id == 0:
					continue
				var dist: int = Fx.length(d.x - t.x, d.y - t.y)
				if dist <= PROXIMITY or (d.detection > 0 and dist <= d.detection):
					teams[world.team_of(d.player_id)] = true
		world.stealth_seen[t.id] = teams


## Firing gives a stealthy unit away for a moment.
static func reveal(world: SimWorld, e: SimEntity) -> void:
	if e.stealth:
		e.revealed_until = world.tick + REVEAL_TICKS
